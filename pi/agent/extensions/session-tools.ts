import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { spawn } from "child_process";

interface SessionMeta {
  sessionId: string;
  startedAt: Date | null;
  cwd: string;
}

// --- Helpers ---

function extractTextFromContent(content: unknown): string {
  if (content === null || content === undefined) return "";
  if (typeof content === "string") return content.trim();
  if (Array.isArray(content)) {
    const parts: string[] = [];
    for (const item of content) {
      if (typeof item !== "object" || item === null) continue;
      const itemObj = item as Record<string, unknown>;
      if (itemObj.type !== "text") continue;
      const text = itemObj.text;
      if (typeof text === "string" && text.trim()) parts.push(text.trim());
    }
    return parts.join("\n").trim();
  }
  return "";
}

function parseIsoTimestamp(ts: unknown): Date | null {
  if (!ts || typeof ts !== "string") return null;
  try {
    let normalized = ts;
    if (ts.endsWith("Z")) normalized = ts.slice(0, -1) + "+00:00";
    const date = new Date(normalized);
    return isNaN(date.getTime()) ? null : date;
  } catch {
    return null;
  }
}

function slug(s: string): string {
  const out: string[] = [];
  let prevUnderscore = false;
  for (const ch of s) {
    const isAlphaNum = /[a-zA-Z0-9]/.test(ch);
    const isAllowed = isAlphaNum || ch === "-" || ch === "_";
    if (isAllowed) {
      out.push(ch);
      prevUnderscore = false;
    } else if (!prevUnderscore) {
      out.push("_");
      prevUnderscore = true;
    }
  }
  return out.join("").replace(/^_+|_+$/g, "") || "unknown";
}

function formatTimestamp(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return (
    `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}_` +
    `${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`
  );
}

// --- Conversation extraction ---

interface ExtractedMessage {
  role: string;
  text: string;
  hasToolCalls: boolean;
}

function extractConversationFromBranch(
  sessionManager: any
): { meta: SessionMeta; messages: ExtractedMessage[] } {
  const meta: SessionMeta = { sessionId: "", startedAt: null, cwd: "" };
  const messages: ExtractedMessage[] = [];

  const header =
    typeof sessionManager.getHeader === "function"
      ? sessionManager.getHeader()
      : null;
  if (header && typeof header === "object") {
    const h = header as Record<string, unknown>;
    meta.sessionId = typeof h.id === "string" ? h.id : "";
    meta.startedAt = parseIsoTimestamp(h.timestamp);
    if (typeof h.cwd === "string") meta.cwd = h.cwd;
  }
  if (!meta.cwd && typeof sessionManager.getCwd === "function") {
    meta.cwd = String(sessionManager.getCwd() || "");
  }

  const leafId =
    typeof sessionManager.getLeafId === "function"
      ? (sessionManager.getLeafId() as string | null)
      : null;
  const branchEntries: unknown[] =
    leafId && typeof sessionManager.getBranch === "function"
      ? (sessionManager.getBranch(leafId) as unknown[])
      : [];

  for (const entry of branchEntries) {
    if (typeof entry !== "object" || entry === null) continue;
    const rec = entry as Record<string, unknown>;
    if (rec.type !== "message") continue;

    const msg = rec.message;
    if (typeof msg !== "object" || msg === null || Array.isArray(msg)) continue;
    const msgObj = msg as Record<string, unknown>;
    const role = msgObj.role;

    // Skip tool results entirely
    if (role === "toolResult") continue;

    if (role === "user" || role === "assistant") {
      const content = msgObj.content;
      let text = "";
      let hasToolCalls = false;

      if (typeof content === "string") {
        text = content.trim();
      } else if (Array.isArray(content)) {
        const parts: string[] = [];
        for (const item of content) {
          if (typeof item !== "object" || item === null) continue;
          const itemObj = item as Record<string, unknown>;
          // Track tool calls for intermediate message detection
          if (itemObj.type === "toolCall") {
            hasToolCalls = true;
          }
          // Only include text blocks, skip thinking and toolCall
          if (
            itemObj.type === "text" &&
            typeof itemObj.text === "string" &&
            itemObj.text.trim()
          ) {
            parts.push(itemObj.text.trim());
          }
        }
        text = parts.join("\n").trim();
      }

      if (text) {
        messages.push({ role, text, hasToolCalls });
      }
    }
  }

  return { meta, messages };
}

// --- Output formatting ---

function sliceLastNTurns(
  messages: ExtractedMessage[],
  turns: number
): ExtractedMessage[] {
  if (turns <= 0) return messages;

  const userIndices: number[] = [];
  for (let i = 0; i < messages.length; i++) {
    if (messages[i].role === "user") userIndices.push(i);
  }

  if (userIndices.length === 0) return messages;
  const start =
    userIndices.length <= turns ? 0 : userIndices[userIndices.length - turns];
  return messages.slice(start);
}

function buildMarkdown(
  meta: SessionMeta,
  sessionFile: string,
  messages: ExtractedMessage[],
  lastTurns: number
): { content: string; filename: string } | null {
  if (messages.length === 0) return null;

  // Slice to last N turns
  const sliced = sliceLastNTurns(messages, lastTurns);
  if (sliced.length === 0) return null;

  // Assign turn numbers
  let turnNum = 0;
  const withTurns = sliced.map((m) => {
    if (m.role === "user") turnNum++;
    return { ...m, turn: turnNum };
  });

  // Build frontmatter
  const fmLines: string[] = ["---"];
  if (meta.sessionId) fmLines.push(`id: "${meta.sessionId}"`);
  if (meta.startedAt) fmLines.push(`started: "${meta.startedAt.toISOString()}"`);
  if (meta.cwd) fmLines.push(`cwd: "${meta.cwd}"`);
  fmLines.push(`source: "${sessionFile}"`);
  fmLines.push(`turns: "last ${lastTurns}"`);
  fmLines.push("---");

  // Build message blocks
  const blocks: string[] = [...fmLines, ""];
  for (const m of withTurns) {
    blocks.push(`<message role="${m.role}" turn="${m.turn}">`);
    blocks.push(m.text);
    blocks.push("</message>");
    blocks.push("");
  }

  // Generate filename
  const project = meta.cwd ? path.basename(meta.cwd) : "unknown";
  const projectSlug = slug(project);
  const started = meta.startedAt || new Date();
  const stamp = formatTimestamp(started);
  const sid = (meta.sessionId || "unknown").slice(0, 8);
  const filename = `${projectSlug}_pi_${stamp}_${sid}.md`;

  return { content: blocks.join("\n"), filename };
}

// --- Path resolution ---

function resolveOutputPath(outputPath: string | undefined, autoFilename: string): string {
  if (!outputPath) return path.join(process.cwd(), autoFilename);
  if (outputPath.endsWith("/")) return path.join(outputPath, autoFilename);
  return outputPath;
}

// --- Arg parsing helpers ---

function parseTurnCount(tokens: string[]): number | null {
  const turnsToken = tokens.find((t) => /^\d+$/.test(t));
  if (!turnsToken) return null;
  const n = parseInt(turnsToken, 10);
  if (!Number.isFinite(n) || n < 1) return null;
  return n;
}

function parseRoleFilter(tokens: string[]): string | undefined {
  const roleToken = tokens.find((t) => t.startsWith("--role="));
  if (!roleToken) return undefined;
  const role = roleToken.slice(7).toLowerCase();
  if (role !== "user" && role !== "assistant") return undefined;
  return role;
}

function hasArgs(tokens: string[]): boolean {
  return tokens.length > 0;
}

// --- Message filtering ---

/**
 * Filter to last assistant message only (default annotate behavior).
 * Excludes intermediate progress messages (assistant messages with tool calls).
 */
function filterToLastAssistantMessage(
  messages: ExtractedMessage[]
): ExtractedMessage[] {
  // Find the last assistant message without tool calls
  for (let i = messages.length - 1; i >= 0; i--) {
    const msg = messages[i];
    if (msg.role === "assistant" && !msg.hasToolCalls) {
      return [msg];
    }
  }
  // Fallback: return last assistant message regardless of tool calls
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role === "assistant") {
      return [messages[i]];
    }
  }
  return [];
}

// --- Command registration ---

// --- Editor command ---

async function openInEditor(
  ctx: { mode: string; sessionManager: any; ui: any },
  args: string
): Promise<void> {
  if (ctx.mode !== "tui") {
    ctx.ui.notify("/editor requires interactive mode", "error");
    return;
  }

  const sessionFile = ctx.sessionManager.getSessionFile();
  if (!sessionFile) {
    ctx.ui.notify("No session file (ephemeral session)", "error");
    return;
  }

  const editorCmd = process.env.VISUAL || process.env.EDITOR;
  if (!editorCmd) {
    ctx.ui.notify("No editor configured. Set $VISUAL or $EDITOR.", "error");
    return;
  }

  const tokens = args.trim() ? args.trim().split(/\s+/).filter(Boolean) : [];
  const isDefault = !hasArgs(tokens);
  const lastTurns = parseTurnCount(tokens) ?? 1;
  const roleFilter = parseRoleFilter(tokens);

  const { meta, messages } = extractConversationFromBranch(
    ctx.sessionManager
  );

  let filtered: ExtractedMessage[];
  if (isDefault) {
    // Default: last assistant message only, no intermediate progress
    filtered = filterToLastAssistantMessage(messages);
  } else {
    // Custom: apply role filter if provided, include intermediate progress
    filtered = roleFilter
      ? messages.filter((m: ExtractedMessage) => m.role === roleFilter)
      : messages;
  }

  const result = buildMarkdown(meta, sessionFile, filtered, lastTurns);
  if (!result) {
    ctx.ui.notify("No conversation found", "error");
    return;
  }

  // Use ui.custom() to properly manage TUI lifecycle during external editor
  // The factory receives the TUI instance - we stop it before spawning editor
  await ctx.ui.custom<boolean>((tui: any, _theme: any, _keybindings: any, done: (result: boolean) => void) => {
    // One folder in the system temp dir, one subdirectory per run. The pi nono
    // profile grants that folder r+w (nono/profiles/pi.json).
    const editorDir = path.join(os.tmpdir(), "pi-editor", String(Date.now()));
    fs.mkdirSync(editorDir, { recursive: true });
    const tmpFile = path.join(editorDir, "message.md");

    // const cleanup = () => {
    //   try {
    //     fs.unlinkSync(tmpFile);
    //   } catch {
    //     // Ignore cleanup errors
    //   }
    // };

    fs.writeFileSync(tmpFile, result.content, "utf-8");

    const [editor, ...editorArgs] = editorCmd.split(" ");
    process.stdout.write(
      `\nLaunching editor: ${editorCmd}\nPi will resume when the editor exits.\n`
    );

    // Stop TUI to release terminal for the external editor
    tui.stop();

    const child = spawn(editor, [...editorArgs, tmpFile], {
      stdio: "inherit",
      shell: process.platform === "win32",
    });

    child.on("error", () => {
      // cleanup();
      tui.start();
      tui.requestRender(true);
      done(false);
    });

    child.on("close", (code) => {
      // cleanup();
      tui.start();
      tui.requestRender(true);
      process.stdout.write(`\nEditor closed. File preserved: ${tmpFile}\n`);
      done(code === 0);
    });

    // Return a minimal component - editor takes over terminal via stdio: "inherit"
    // The component is a placeholder; actual rendering is handled by the editor
    return {
      render: () => "",
      onKey: () => true,
    };
  });
}

// --- Command registration ---

export default function (pi: ExtensionAPI) {
  pi.registerCommand("editor", {
    description:
      "Open messages in external editor. " +
      "Usage: /editor [turns] [--role=user|assistant] " +
      "Default (no args): last assistant message only. " +
      "Examples: /editor | /editor 3 | /editor --role=user | /editor 2 --role=assistant",
    handler: async (args, ctx) => {
      await openInEditor(ctx, args);
    },
  });

  pi.registerShortcut(Key.ctrlShift("g"), {
    description: "Open last assistant message in editor",
    handler: async (ctx) => {
      await openInEditor(ctx, "");
    },
  });

  pi.registerCommand("export-md", {
    description:
      "Export current session as markdown with YAML frontmatter and XML message tags. " +
      "Usage: /export-md [turns] [path] [--role=user|assistant] " +
      "Examples: /export-md | /export-md 2 | /export-md ./notes/ | /export-md 3 ./review.md | /export-md --role=assistant",
    handler: async (args, ctx) => {
      const sessionFile = ctx.sessionManager.getSessionFile();
      if (!sessionFile) {
        ctx.ui.notify("No session file (ephemeral session)", "error");
        return;
      }

      const tokens = args.trim() ? args.trim().split(/\s+/).filter(Boolean) : [];

      // Parse turn count (first numeric token)
      const turnsToken = tokens.find((t) => /^\d+$/.test(t));
      if (turnsToken) {
        const n = parseInt(turnsToken, 10);
        if (n < 1) {
          ctx.ui.notify("Turn count must be >= 1", "error");
          return;
        }
      }
      const lastTurns = turnsToken ? parseInt(turnsToken, 10) : 1;

      // Parse output path (token with / or .md extension)
      const pathToken = tokens.find((t) => t.includes("/") || t.endsWith(".md"));
      const outputPath = pathToken || undefined;

      // Parse --role= filter
      const roleFilter = parseRoleFilter(tokens);
      // Check for invalid role filter
      const roleToken = tokens.find((t) => t.startsWith("--role="));
      if (roleToken && !roleFilter) {
        ctx.ui.notify("--role must be 'user' or 'assistant'", "error");
        return;
      }

      try {
        const { meta, messages } = extractConversationFromBranch(
          ctx.sessionManager
        );

        // Apply role filter
        const filtered = roleFilter
          ? messages.filter((m) => m.role === roleFilter)
          : messages;

        const result = buildMarkdown(meta, sessionFile, filtered, lastTurns);

        if (!result) {
          ctx.ui.notify("No conversation found", "error");
          return;
        }

        const outputFile = resolveOutputPath(outputPath, result.filename);
        const outputDir = path.dirname(outputFile);
        fs.mkdirSync(outputDir, { recursive: true });
        fs.writeFileSync(outputFile, result.content, "utf-8");
        ctx.ui.notify(`Saved: ${outputFile}`, "success");
      } catch (err) {
        const errMsg = err instanceof Error ? err.message : String(err);
        ctx.ui.notify(`Export failed: ${errMsg}`, "error");
      }
    },
  });
}
