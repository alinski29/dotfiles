/**
 * Tool Presets Extension
 *
 * One owner of the active tool set and of the advertised skill list. A preset
 * is a named restriction read from `presets.json`, selectable with
 * `--preset <name>`, `/preset`, or Ctrl+Shift+U. Per-tool toggles (`/tools`,
 * `enable_tool`) are session overrides that outrank the active preset.
 *
 * Config (project wins by preset name):
 * - ~/.pi/agent/presets.json
 * - <cwd>/.pi/presets.json
 *
 *   {
 *     "default": { "tools": { "disable": ["ast_*"], "hidden": ["ast_*"] } },
 *     "plan": {
 *       "tools": { "enable": ["read", "grep", "subagent"] },
 *       "skills": { "enable": ["to-spec", "grilling"] }
 *     }
 *   }
 *
 * Tool layers, highest precedence last:
 *   baseline    resolved startup set (core flags, defaultTools)
 *   preset      enable filters the registered set, disable subtracts from baseline
 *   overrides   session-local delta
 *
 * Skills have one axis and no state: the preset decides what the prompt
 * advertises, and `disable-model-invocation` is a floor no preset may override.
 * A gated skill is still reachable by typing `/skill:<name>`.
 *
 * A preset with an unknown key is a validation error: warn and skip it. The
 * flat revision 3 schema (`enable`/`disable`/`hidden`/`shown` at preset top
 * level) is hard-cut: those presets are skipped with a warning naming the key.
 *
 * Core hard-filter flags (`--tools` plain list, `--exclude-tools`, `--no-tools`)
 * conflict with this extension and refuse startup: they create tools no preset
 * or override can re-activate. Express the restriction in presets.json instead.
 */

import type {
	ExtensionAPI,
	ExtensionContext,
	Skill,
	SlashCommandInfo,
	Theme,
	ToolInfo,
} from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { Key, type SelectItem } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import * as os from "node:os";
import * as path from "node:path";
import {
	DEFAULT_PRESET,
	PRESETS_BASELINE_TYPE,
	PRESETS_STATE_TYPE,
	type Overrides,
	type Preset,
	type PresetState,
	dotfilesSkillNames,
	findHardFilterConflict,
	hardFilterMessage,
	loadPresets,
	normalizeOverrides,
	readJsonFile,
	readSkillFlags,
} from "./config.ts";
import {
	advertisedSkills,
	buildDisabledToolsBlock,
	computeActiveTools,
	describePreset,
	isGatedSkill,
	skillWarnings,
} from "./resolve.ts";
import { hiddenSkillMarker, showDetailOverlay, showPresetSelector, showToolsOverlay, type DetailSection } from "./ui.ts";

const SKILL_COMMAND_PREFIX = "skill:";
/** Prefix core gives a built-in tool's synthetic `sourceInfo.path`. */
const BUILTIN_PATH_PREFIX = "builtin:";

export default function toolPresetsExtension(pi: ExtensionAPI) {
	const conflict = findHardFilterConflict(process.argv);
	if (conflict) {
		console.error(hardFilterMessage(conflict));
		process.exit(1);
	}

	let presets = new Map<string, Preset>();
	let activePresetName = DEFAULT_PRESET;
	let overrides: Overrides = { enabled: [], disabled: [] };
	/** Resolved startup set, captured once before the first apply. */
	let baseline: string[] | undefined;
	let persistedSnapshot: string | undefined;
	let disabledToolsNotified = false;
	/** Loaded skills, observed from the first `before_agent_start` of a read. */
	let cachedSkills: Skill[] | undefined;
	let skillsValidated = false;
	/** `disable-model-invocation` per skill file, read once per session. */
	const skillFlagCache = new Map<string, boolean>();

	// --- state helpers ---

	function registeredToolNames(): string[] {
		return pi.getAllTools().map((tool) => tool.name);
	}

	function stateSnapshot(): string {
		return JSON.stringify({
			preset: activePresetName,
			enabled: [...overrides.enabled].sort(),
			disabled: [...overrides.disabled].sort(),
		});
	}

	/** Write a `preset-state` entry only when the state actually changed. */
	function persistIfChanged(): void {
		const snapshot = stateSnapshot();
		if (snapshot === persistedSnapshot) return;
		pi.appendEntry<PresetState>(PRESETS_STATE_TYPE, {
			preset: activePresetName,
			overrides: {
				enabled: [...overrides.enabled],
				disabled: [...overrides.disabled],
			},
		});
		persistedSnapshot = snapshot;
	}

	function readRestoredState(ctx: ExtensionContext): PresetState | undefined {
		let restored: PresetState | undefined;
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "custom" || entry.customType !== PRESETS_STATE_TYPE) continue;
			const data = entry.data as Partial<PresetState> | undefined;
			if (data && typeof data.preset === "string") {
				restored = { preset: data.preset, overrides: normalizeOverrides(data.overrides) };
			}
		}
		return restored;
	}

	/**
	 * Baseline captured at `session_start`, before any preset can be applied, and
	 * persisted so `/reload` (which rebuilds the loadout from the currently active,
	 * preset-applied tools) recovers the real baseline from the branch.
	 */
	function readRestoredBaseline(ctx: ExtensionContext): string[] | undefined {
		let restored: string[] | undefined;
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "custom" || entry.customType !== PRESETS_BASELINE_TYPE) continue;
			const data = entry.data as { baseline?: unknown } | undefined;
			if (Array.isArray(data?.baseline) && data.baseline.every((name) => typeof name === "string")) {
				restored = data.baseline as string[];
			}
		}
		return restored;
	}

	// --- warnings ---

	function warn(ctx: ExtensionContext, message: string): void {
		if (ctx.hasUI) ctx.ui.notify(message, "warning");
		else console.error(message);
	}

	// --- layer resolution ---

	function activePreset(): Preset {
		return presets.get(activePresetName) ?? {};
	}

	function sameSet(a: readonly string[], b: readonly string[]): boolean {
		if (a.length !== b.length) return false;
		const set = new Set(b);
		return a.every((name) => set.has(name));
	}

	/**
	 * Strict recompute: the active set is a pure function of baseline, the active
	 * preset, and the recorded overrides. A tool activated outside these layers is
	 * absent from the computed list and removed. Comparing against the live set
	 * (not a stored copy) is what enforces that.
	 */
	function recomputeAndApply(): void {
		const computed = computeActiveTools({
			registered: registeredToolNames(),
			base: baseline ?? pi.getActiveTools(),
			preset: activePreset(),
			overrides,
		});
		if (sameSet(computed, pi.getActiveTools())) return;
		pi.setActiveTools(computed);
	}

	function presetNames(): string[] {
		return [...presets.keys()].sort();
	}

	function deltaSuffix(): string {
		const added = overrides.enabled.length > 0 ? ` +${overrides.enabled.length}` : "";
		const removed = overrides.disabled.length > 0 ? ` -${overrides.disabled.length}` : "";
		return `${added}${removed}`;
	}

	function updateStatus(ctx: ExtensionContext): void {
		if (ctx.mode !== "tui") return;
		ctx.ui.setStatus("preset", ctx.ui.theme.fg("accent", `preset:${activePresetName}${deltaSuffix()}`));
	}

	/** Apply a preset by name. A switch clears overrides; re-selecting keeps them. */
	function selectPreset(name: string, ctx: ExtensionContext): void {
		if (name !== activePresetName) {
			activePresetName = name;
			overrides = { enabled: [], disabled: [] };
		}
		persistIfChanged();
		recomputeAndApply();
		updateStatus(ctx);
	}

	function restoreFromBranch(ctx: ExtensionContext): void {
		const restored = readRestoredState(ctx);
		activePresetName = DEFAULT_PRESET;
		overrides = { enabled: [], disabled: [] };

		if (restored) {
			if (presets.has(restored.preset)) {
				activePresetName = restored.preset;
			} else {
				warn(ctx, `Preset "${restored.preset}" no longer exists; falling back to "default".`);
			}
			overrides = normalizeOverrides(restored.overrides);
		}

		const restoredBaseline = readRestoredBaseline(ctx);
		if (restoredBaseline) baseline = restoredBaseline;
		// Sessions written before no-op overrides were pruned can still carry one.
		overrides = pruneOverrides(overrides);

		persistedSnapshot = stateSnapshot();
	}

	// --- skills ---

	/**
	 * Skills Pi resolved for this session. `cachedSkills` first, because those are
	 * the exact objects the prompt filter saw; before the first request they are
	 * recovered from `pi.getCommands()`, which core builds from the same
	 * `resourceLoader.getSkills()` list, so no directory or settings logic is
	 * repeated here.
	 */
	function skillSnapshot(): Skill[] {
		if (cachedSkills) return cachedSkills;

		const skills: Skill[] = [];
		// Bound for extensions since 1.1.0. An older core degrades to the catalogue
		// fallback in `validateSkillNames` instead of failing `session_start`.
		const commands: SlashCommandInfo[] = typeof pi.getCommands === "function" ? pi.getCommands() : [];
		for (const command of commands) {
			const source = command.sourceInfo;
			if (command.source !== "skill" || !command.name.startsWith(SKILL_COMMAND_PREFIX) || !source) continue;
			skills.push({
				name: command.name.slice(SKILL_COMMAND_PREFIX.length),
				description: command.description ?? "",
				filePath: source.path,
				baseDir: source.baseDir ?? path.dirname(source.path),
				sourceInfo: source,
				disableModelInvocation: commandOnlySkill(source.path),
			});
		}
		return skills;
	}

	/** Frontmatter peek for a skill known only through `getCommands()`. */
	function commandOnlySkill(filePath: string): boolean {
		const cached = skillFlagCache.get(filePath);
		if (cached !== undefined) return cached;
		const flag = readSkillFlags(filePath)?.disableModelInvocation === true;
		skillFlagCache.set(filePath, flag);
		return flag;
	}

	/** Names the active preset gates, for the autocomplete marker. */
	function gatedSkillNames(): ReadonlySet<string> {
		const gated = new Set<string>();
		const restriction = activePreset().skills;
		if (!restriction) return gated;
		for (const skill of skillSnapshot()) {
			if (isGatedSkill(restriction, skill)) gated.add(skill.name);
		}
		return gated;
	}

	/**
	 * Validation runs once per preset load. Discovery makes the skill list
	 * reachable at `session_start`, so a warning about a name that exists nowhere
	 * no longer waits for the first request. The dotfiles catalogue stays in the
	 * known set: it is only partially linked into the loaded skills, so a global
	 * preset may legitimately name a skill this project never loaded.
	 */
	function validateSkillNames(ctx: ExtensionContext): void {
		if (skillsValidated) return;
		const skills = skillSnapshot();
		const known = new Set(skills.map((skill) => skill.name));
		for (const name of dotfilesSkillNames()) known.add(name);
		for (const [name, preset] of presets) {
			for (const message of skillWarnings(name, preset, skills, known)) warn(ctx, message);
		}
		skillsValidated = true;
	}

	function reloadPresets(ctx: ExtensionContext): void {
		const loaded = loadPresets(ctx.cwd, new Set(registeredToolNames()));
		presets = loaded.presets;
		skillsValidated = false;
		for (const message of loaded.warnings) warn(ctx, message);
		validateSkillNames(ctx);
	}

	function checkRetiredDisabledTools(ctx: ExtensionContext): void {
		if (disabledToolsNotified) return;
		const { value: settings } = readJsonFile(path.join(getAgentDir(), "settings.json"));
		if (settings && typeof settings === "object" && "disabledTools" in (settings as Record<string, unknown>)) {
			warn(
				ctx,
				'tool-presets: settings.json "disabledTools" is retired; move its entries into the "default" preset in presets.json.',
			);
			disabledToolsNotified = true;
		}
	}

	// --- per-tool overrides ---

	/** Active set the preset alone produces, i.e. with all overrides ignored. */
	function presetActiveSet(): Set<string> {
		return new Set(
			computeActiveTools({
				registered: registeredToolNames(),
				base: baseline ?? pi.getActiveTools(),
				preset: activePreset(),
				overrides: { enabled: [], disabled: [] },
			}),
		);
	}

	/**
	 * An override only means something when it contradicts the preset: a toggle
	 * that lands on the preset's own answer is a no-op, so it is dropped and the
	 * row falls back to the preset layer instead of parading a fake "(override)".
	 */
	function pruneOverrides(candidate: Overrides): Overrides {
		const presetSet = presetActiveSet();
		return {
			enabled: candidate.enabled.filter((name) => !presetSet.has(name)),
			disabled: candidate.disabled.filter((name) => presetSet.has(name)),
		};
	}

	function setOverride(name: string, enabled: boolean): void {
		const enabledSet = new Set(overrides.enabled);
		const disabledSet = new Set(overrides.disabled);
		enabledSet.delete(name);
		disabledSet.delete(name);
		if (enabled) enabledSet.add(name);
		else disabledSet.add(name);
		overrides = pruneOverrides({ enabled: [...enabledSet], disabled: [...disabledSet] });
		persistIfChanged();
		recomputeAndApply();
	}

	function overrideSource(name: string): "override" | "preset" {
		if (overrides.enabled.includes(name) || overrides.disabled.includes(name)) return "override";
		return "preset";
	}

	// --- details ---

	/** `core (built-in)` for a core tool, otherwise the file that registered it. */
	function toolOrigin(tool: ToolInfo): string {
		if (tool.sourceInfo.path.startsWith(BUILTIN_PATH_PREFIX)) return "core (built-in)";
		return abbreviateHome(tool.sourceInfo.path);
	}

	function abbreviateHome(filePath: string): string {
		const home = os.homedir();
		if (!home) return filePath;
		if (filePath === home) return "~";
		return filePath.startsWith(`${home}${path.sep}`) ? `~${filePath.slice(home.length)}` : filePath;
	}

	function parameterSchema(tool: ToolInfo): {
		properties: Record<string, { description?: string }>;
		required: Set<string>;
	} {
		const schema = tool.parameters as
			| { properties?: Record<string, { description?: string }>; required?: unknown }
			| undefined;
		return {
			properties: schema?.properties ?? {},
			required: new Set(Array.isArray(schema?.required) ? (schema.required as string[]) : []),
		};
	}

	function toolSubtitle(tool: ToolInfo): string {
		const count = Object.keys(parameterSchema(tool).properties).length;
		return `${toolOrigin(tool)} · ${tool.exposure} · ${count} ${count === 1 ? "param" : "params"}`;
	}

	function toolDetailSections(tool: ToolInfo): DetailSection[] {
		const { properties, required } = parameterSchema(tool);
		const names = Object.keys(properties);
		const sections: DetailSection[] = [{ heading: "Description", lines: [tool.description || "(no description)"] }];

		const guidelines = tool.promptGuidelines ?? [];
		if (guidelines.length > 0) sections.push({ heading: "Use when", lines: guidelines.map((line) => `• ${line}`) });

		sections.push({
			heading: `Parameters (${names.length})`,
			lines:
				names.length === 0
					? ["(none)"]
					: names.map((name) => {
							const description = properties[name]?.description;
							const kind = required.has(name) ? "required" : "optional";
							return `${name} (${kind})${description ? `: ${description}` : ""}`;
						}),
		});
		return sections;
	}

	/**
	 * What the highlighted preset resolves to: current tools, discovered skills,
	 * and the session overrides, marked only while that preset is the active one
	 * (a switch clears them, so they say nothing about a preset that is not in use).
	 */
	function presetDetailSections(name: string, preset: Preset, theme: Theme): DetailSection[] {
		const live = name === activePresetName;
		const checkbox = (on: boolean) => theme.fg(on ? "success" : "dim", on ? "[x]" : "[ ]");
		const label = (on: boolean, text: string) => (on ? text : theme.fg("dim", text));

		const registered = pi.getAllTools().map((tool) => tool.name);
		const activeSet = new Set(
			computeActiveTools({
				registered,
				base: baseline ?? pi.getActiveTools(),
				preset,
				overrides: live ? overrides : { enabled: [], disabled: [] },
			}),
		);
		const toolLines = registered.map((toolName) => {
			const on = activeSet.has(toolName);
			const mark =
				live && overrideSource(toolName) === "override"
					? theme.fg("dim", ` (override ${on ? "on" : "off"})`)
					: "";
			return `${checkbox(on)} ${label(on, toolName)}${mark}`;
		});
		if (toolLines.length === 0) toolLines.push(theme.fg("dim", "(no tools registered)"));

		const skills = skillSnapshot();
		// Command-only skills never reach the prompt (core's own filter drops them), so
		// they are counted out of "advertised" and marked as their own bucket.
		const advertised = new Set(
			advertisedSkills(preset, skills)
				.filter((skill) => !skill.disableModelInvocation)
				.map((skill) => skill.name),
		);
		const skillLines = skills.map((skill) => {
			const on = advertised.has(skill.name);
			const mark = on
				? ""
				: skill.disableModelInvocation
					? theme.fg("dim", " (command-only)")
					: isGatedSkill(preset.skills, skill)
						? theme.fg("dim", " (hidden)")
						: "";
			const scope =
				skill.sourceInfo?.scope === "project"
					? " [project]"
					: skill.sourceInfo?.origin === "package"
						? " [package]"
						: "";
			return `${checkbox(on)} ${label(on, skill.name)}${mark}${scope ? theme.fg("dim", scope) : ""}`;
		});
		if (skillLines.length === 0) skillLines.push(theme.fg("dim", "(no skills discovered)"));

		return [
			{ heading: `Tools (${activeSet.size} of ${registered.length} active)`, lines: toolLines },
			{ heading: `Skills (${advertised.size} of ${skills.length} advertised)`, lines: skillLines },
		];
	}

	function showToolDetail(ctx: ExtensionContext, tool: ToolInfo): Promise<void> {
		return showDetailOverlay(ctx, {
			title: tool.name,
			subtitle: toolSubtitle(tool),
			sections: toolDetailSections(tool),
		});
	}

	function showPresetDetail(ctx: ExtensionContext, name: string): Promise<void> {
		const preset = presets.get(name) ?? {};
		const count = overrides.enabled.length + overrides.disabled.length;
		const note = name === activePresetName && count > 0 ? ` · ${count} session override${count === 1 ? "" : "s"}` : "";
		return showDetailOverlay(ctx, {
			title: name,
			subtitle: `${describePreset(preset)}${note}`,
			sections: presetDetailSections(name, preset, ctx.ui.theme),
		});
	}

	// --- UI ---

	async function showPresetPicker(ctx: ExtensionContext): Promise<void> {
		const active = activePresetName;
		const items: SelectItem[] = presetNames().map((name) => ({
			value: name,
			label:
				name === active
					? ctx.ui.theme.fg("success", `● ${name}`) + ctx.ui.theme.fg("dim", deltaSuffix())
					: `  ${name}`,
			description: describePreset(presets.get(name) ?? {}),
		}));

		const result = await showPresetSelector(ctx, items, active, (item) => {
			void showPresetDetail(ctx, item.value);
		});
		if (!result) return;
		selectPreset(result, ctx);
		ctx.ui.notify(`Preset "${result}" activated`, "info");
	}

	// --- registration ---

	pi.registerFlag("preset", {
		description: "Tool preset to start with (see presets.json)",
		type: "string",
	});

	pi.registerCommand("preset", {
		description: "Switch tool preset",
		handler: async (args, ctx) => {
			reloadPresets(ctx);

			const name = args.trim();
			if (name) {
				if (!presets.has(name)) {
					warn(ctx, `Unknown preset "${name}". Available: ${presetNames().join(", ")}`);
					return;
				}
				selectPreset(name, ctx);
				if (ctx.hasUI) ctx.ui.notify(`Preset "${name}" activated`, "info");
				return;
			}

			if (ctx.mode !== "tui") {
				warn(ctx, `Active preset: ${activePresetName}. Available: ${presetNames().join(", ")}`);
				return;
			}
			await showPresetPicker(ctx);
		},
	});

	pi.registerShortcut(Key.ctrlShift("u"), {
		description: "Cycle tool presets",
		handler: async (ctx) => {
			// Re-read presets.json like `/preset` does, so a hand edit applies on
			// the next tick instead of appearing to need `/reload`.
			reloadPresets(ctx);
			const names = presetNames();
			const index = names.indexOf(activePresetName);
			const next = names[(index + 1) % names.length] ?? names[0];
			if (!next) return;
			selectPreset(next, ctx);
			if (ctx.hasUI) ctx.ui.notify(`Preset "${next}" activated`, "info");
		},
	});

	pi.registerCommand("tools", {
		description: "Enable/disable tools as session overrides",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") {
				warn(ctx, "The /tools overlay is only available in interactive mode.");
				return;
			}
			const tools = pi.getAllTools();
			if (tools.length === 0) {
				warn(ctx, "No tools are registered.");
				return;
			}
			await showToolsOverlay(ctx, {
				tools,
				getActive: () => pi.getActiveTools(),
				overrideSource,
				onToggle: (name, enabled) => {
					setOverride(name, enabled);
					updateStatus(ctx);
				},
				onDetail: (tool) => {
					void showToolDetail(ctx, tool);
				},
			});
		},
	});

	pi.registerTool({
		name: "enable_tool",
		label: "Enable Tool",
		description:
			"Request permission to enable a disabled tool. Use when you need a capability that is currently disabled.",
		promptSnippet: "Request enabling a disabled tool",
		promptGuidelines: [
			"Use enable_tool when you need a tool listed in the Disabled Tools section of the system prompt.",
			"enable_tool will prompt the user for confirmation before enabling the tool.",
		],
		parameters: Type.Object({
			tool_name: Type.String({ description: "Name of the tool to enable" }),
			reason: Type.String({ description: "Why you need this tool and what you'll use it for" }),
		}),
		async execute(_id, params, _signal, _onUpdate, ctx) {
			const registered = new Set(registeredToolNames());
			if (!registered.has(params.tool_name)) {
				return {
					content: [{ type: "text", text: `Tool "${params.tool_name}" does not exist.` }],
					details: undefined,
				};
			}

			if (pi.getActiveTools().includes(params.tool_name)) {
				return {
					content: [{ type: "text", text: `Tool "${params.tool_name}" is already enabled.` }],
					details: undefined,
				};
			}

			const ok = await ctx.ui.confirm(
				"Enable Tool",
				`Enable "${params.tool_name}"?\n\nReason: ${params.reason}`,
			);

			if (!ok) {
				return {
					content: [{ type: "text", text: `User denied enabling "${params.tool_name}".` }],
					details: undefined,
				};
			}

			setOverride(params.tool_name, true);
			updateStatus(ctx);
			return {
				content: [
					{ type: "text", text: `Enabled "${params.tool_name}". It will be available in your next response.` },
				],
				details: undefined,
			};
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		baseline = undefined;
		cachedSkills = undefined;
		skillFlagCache.clear();
		checkRetiredDisabledTools(ctx);
		reloadPresets(ctx);
		restoreFromBranch(ctx);

		// Capture the resolved startup set here, before any preset can be applied.
		// Capturing lazily at `before_agent_start` instead would take a preset's
		// already-applied tools as the baseline when the user switches presets (or
		// runs `/reload`) before the first turn, which then makes `disable` presets
		// subtract from the wrong set. Persist it so `/reload` recovers the real
		// baseline from the branch instead of the rebuilt (preset-applied) loadout.
		if (baseline === undefined) {
			baseline = pi.getActiveTools();
			pi.appendEntry(PRESETS_BASELINE_TYPE, { baseline: [...baseline] });
		}

		const flag = pi.getFlag("preset");
		if (typeof flag === "string" && flag.length > 0) {
			if (presets.has(flag)) {
				activePresetName = flag;
			} else {
				warn(ctx, `Unknown preset "${flag}". Available: ${presetNames().join(", ")}`);
				activePresetName = DEFAULT_PRESET;
			}
			// An explicit selection means "exactly this preset".
			overrides = { enabled: [], disabled: [] };
		}

		ctx.ui.addAutocompleteProvider(hiddenSkillMarker(gatedSkillNames));
		persistIfChanged();
		updateStatus(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		restoreFromBranch(ctx);
		if (baseline !== undefined) recomputeAndApply();
		updateStatus(ctx);
	});

	pi.on("before_agent_start", async (event, ctx) => {
		if (baseline === undefined) {
			baseline = pi.getActiveTools();
			pi.appendEntry(PRESETS_BASELINE_TYPE, { baseline: [...baseline] });
		}
		recomputeAndApply();

		const skills = event.systemPromptOptions.skills ?? [];
		cachedSkills = skills;
		validateSkillNames(ctx);
		event.systemPromptOptions.skills = advertisedSkills(activePreset(), skills);

		const block = buildDisabledToolsBlock(pi.getAllTools(), new Set(pi.getActiveTools()), activePreset().tools);
		if (!block) return;
		return { systemPrompt: event.systemPrompt + block };
	});
}
