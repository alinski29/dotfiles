## General rules & guidelines

- <important>You have restrictions on what you can access! If you cannot achieve your task with the current permission set, **STOP** and specify what grant you need! **NEVER** try to bypass the permissions!</important>
- When working inside a repository worktree, treat that worktree as your project root. Prefer files and tools inside the worktree. Do not reach into the coordinator's checkout, parent workspace, home directory, or another repository unless repository instructions explicitly identify an external dependency or the task requires it. Do not copy coordinator-local absolute paths into code, tickets, manifests, or child prompts.
- Never use the em dash "—", use the plain dash "-" instead
- When writing commit messages, NEVER auto-add your agent name as the author
- Never modify any files that are marked as auto-generated
- Use `/tmp/pi-scratchpad/{unix-ts}_{id-or-slug}` for experiments, throwaway files, scratch scripts and cloned repos you do not intend to keep. Do not write scratch output into the project worktree.
- If you ask me questions, use the `ask_user_question` tool.

## Tool selection

For code search and navigation, refer to the `file-search-replace` skill for detailed guidance. Quick reference:

- **Identifier search (start here)** → `symbol_search` - ranked candidate files for a concept/identifier; index-based and unsound, confirm with grep
- **File outline (cheap)** → `module_report` - explains one file, who-uses-this
- **Read symbol body** → `read_symbol`
- **Context after grep hit** → `read_enclosing`
- **LSP ops** (definition, references, rename) → `lsp_navigation`
- **Diagnostics** → `lsp_diagnostics` + `lens_diagnostics`
- **Code relationships** (callers/callees/impact) → `codegraph_*` (when indexed, ONE call per turn)
- **Text search** → `grep` tool
- **Structural search** → `ast-grep` via bash

Discovery funnel for orientation: `symbol_search` (candidates) → `module_report` (outline) → `read_symbol` (body), then grep to confirm. Literal strings, log messages, and exact text go straight to `grep` - the index misses them.

**CRITICAL**: issue only ONE codegraph tool call per LLM turn - the daemon cannot handle concurrent requests. Never batch multiple codegraph calls together. If the codegraph tools hand / timeout, fallback to the CLI.

## Subagent delegation

<important>
When spawning subagents, always pass `timeoutMs: 900000` (15 minutes).

Prefer delegating to specialized subagents over doing everything yourself:

- **scout** — code exploration, architecture mapping, symbol lookup. Spawn proactively when the user asks "how does X work", "find where Y is used", or similar exploratory questions.
- **researcher** — web research, library documentation, external references. Spawn proactively when the user asks about external tools, APIs, or needs web research.
- **worker** — implementation tasks. Invoke on user request or when a clear implementation task is identified.
- **reviewer** — code review, quality checks. Invoke on user request, when clearly stated that a review is required, **NEVER** assume: this can burn a lot of tokens!

For exploratory work, prefer spawning a scout with a fresh context rather than doing sequential grep/read yourself. For web questions, spawn a researcher. Only do exploration yourself when you need inline context for an immediate edit.

You should provide the subagents with the apropiate artifacts in the default reads parameter: for worker, this is usually the implementation ticket or Github issue, if it exists. For the reviewer, it could be a ticket or multiple tickets, maybe a SPEC.md file.

</important>

### Cross-repo subagents

When the project spans multiple repos, or a subagent must explore/work in a different repo than the parent session CWD, pass the target directory explicitly via `cwd` in the subagent params. Do not assume the parent session CWD is the child repo.

```js
subagent({
  workflowScript: `return runs.run("main", {
    agent: "worker",
    task: "Implement the approved plan",
    cwd: "/path/to/other-repo"
  })`
})
```

- The child runs in that cwd and uses that project's config, agents, skills, and git state. Parent session cwd is unaffected.
- Include the exact repo, explicit `cwd`, authority boundary, and expected output path in the child task text.
- One writer per repo/worktree. For several repos, use one async workflowScript whose child calls each set their own `cwd`; keep publication/merge decisions serial per repo.
