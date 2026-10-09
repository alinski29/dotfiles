---
name: file-search-replace
description: "Use when searching or replacing code in codebases (text, structural/AST, files by name, relationship navigation) or building context before a task."
license: "(MIT AND CC-BY-SA-4.0). See LICENSE-MIT and LICENSE-CC-BY-SA-4.0"
compatibility: "Requires ripgrep (rg) and fd. Optional: ast-grep (sg), codegraph (CLI or Pi extension)."
metadata:
  author: "Distilled from Netresearch DTT GmbH file-search-skill"
  version: "2.1.0"
allowed-tools: Bash(rg:*) Bash(fd:*) Bash(ast-grep:*) Bash(codegraph:*) Read Grep find
---

# File Search & Replace Skill

Efficient CLI search and structural replace tools for AI agents.

## Tool Selection Guide

**Prefer built-in tools when available.** Pi's `grep` tool uses ripgrep under the hood, and `find` uses `fd`. Use CLI tools via `bash` only for advanced features (structural search, replace, batch operations).

| Task | Preferred | Fallback |
|------|-----------|----------|
| Text search in files | `grep` tool | `bash` with `rg` |
| Find files by name/path | `find` tool | `bash` with `fd` |
| Structural code search | `bash` with `ast-grep` | — |
| Structural code replace | `bash` with `ast-grep --rewrite` | — |
| Find callers/callees of symbol | `codegraph_*` tools | `bash` with `codegraph` CLI |
| Impact/blast radius of change | `codegraph_impact` tool | `bash` with `codegraph impact` |
| Orient in unfamiliar codebase | `codegraph_explore` tool | `bash` with `codegraph query` |
| Find files by identifier (ranked) | `symbol_search` tool | `grep` tool to confirm |
| Explain a file cheaply (outline) | `module_report` tool | full-file `read` |
| Read one symbol's body | `read_symbol` tool | `read` with offset/limit |

**Decision flow:** text → `grep`/`rg` | structural → `ast-grep` | relationships → `codegraph` | filenames → `find`/`fd` | identifier-ish concept → `symbol_search` | literal strings → `grep` (index misses literals)

**Codegraph prerequisite:** Requires `.codegraph/` directory in project. If missing, skip codegraph and use grep. See [references/codegraph-integration.md](references/codegraph-integration.md).

## When to Use Each Tool

### Use `grep` tool or `rg` when:
- Searching for string literals, log messages, error codes
- Searching for simple patterns like function names, variable names
- Searching across all file types simultaneously
- You need maximum speed on large codebases
- The pattern is straightforward text or regex
- **Confirming codegraph results** for completeness (renames, signature changes)

### Use `find` tool or `fd` when:
- Finding files by name, extension, or path pattern
- Finding files by modification time or size
- Listing directory contents with filters

### Use `ast-grep` when:
- Matching code **structure** regardless of formatting/whitespace
- Finding function calls with specific argument patterns
- Matching patterns that span multiple lines unpredictably
- Refactoring patterns (find + replace structurally)
- When regex would be too fragile for the code pattern

### Use `codegraph_*` tools or `codegraph` CLI when:
- "Where is X used?" / "What calls Y?" / "What breaks if I change Z?"
- Tracing flow across multiple files
- Orienting in unfamiliar codebase (use `explore` for overview)
- Pre-ranking work before grep confirmation
- **NOT** for single-file edits or short sessions
- **NOT** when `.codegraph/` doesn't exist (skip entirely)

**Soundness warning:** Codegraph is unsound — it silently drops method dispatch, generics, and trait-dispatch edges. Use grep to confirm completeness before renames or signature changes. See [references/codegraph-integration.md](references/codegraph-integration.md).

### Use `symbol_search`, `module_report`, `read_symbol` when:
- You know the identifier-ish concept but not which file holds it ("where is the auth middleware", "how is pagination done")
- Orienting cheaply: `symbol_search` (ranked candidates) → `module_report` (file outline, who-uses-this) → `read_symbol` (exact body)
- Prefer this funnel over full-file `read` when you only need one symbol or a file overview
- Index-based and unsound: misses literals, generated names, and renames. Confirm with `grep` before renaming or when the index misses
- **NOT** for literal strings, log messages, or exact text - use `grep`

## Quick Examples

```bash
# Text search (prefer grep tool, fallback to rg)
rg 'def \w+\(' -t py src/
rg -c 'TODO' -t js | wc -l

# File finding (prefer find tool, fallback to fd)
fd -g '*.test.ts' --changed-within 1d
fd -g '*_test.go' -X rg 'func Test'

# Structural search and replace (always via bash)
ast-grep --pattern 'console.log($$$)' --lang js
ast-grep --pattern 'console.log($$$)' --rewrite 'logger.info($$$)' --lang js
```

## Best Practices

1. **Start narrow.** Specify types (`-t`, `--lang`, `-e`), scope dirs, count first (`rg -c`).
2. **Exclude noise** (`-g '!vendor/'`, `fd -E node_modules`).
3. **Batch independent queries.** Union patterns with `rg -e P1 -e P2 -e P3` (one walk, one process), or issue distinct queries as parallel tool calls in a single message — never sequential `&&` chains for independent searches.
4. **`--json`** for programmatic processing.
5. **rg ≠ fd types.** `rg -t ts` includes `.tsx`; `fd -e ts` does NOT. No `-t tsx` in rg.

See [references/search-strategies.md](references/search-strategies.md).

## Beyond Local Files

If local search finds nothing and context lives in issues/PRs/external
docs — hand off (`gh`, Jira, WebFetch). Issue keys in comments signal this.

`search_external_files` only searches directories added to the session via `add_directory`; it is a main-session capability. Subagents do not have `add_directory` and cannot rely on it - treat it as unavailable and use `gh`/`web_search`/explicit paths instead.

See [references/remote-handoff.md](references/remote-handoff.md).

## References

| Topic | File |
|-------|------|
| rg flags, patterns, recipes | [references/ripgrep-patterns.md](references/ripgrep-patterns.md) |
| ast-grep patterns by language | [references/ast-grep-patterns.md](references/ast-grep-patterns.md) |
| fd flags, usage, fd+rg combos | [references/fd-guide.md](references/fd-guide.md) |
| Search targeting strategies | [references/search-strategies.md](references/search-strategies.md) |
| Tool comparison and decision guide | [references/tool-comparison.md](references/tool-comparison.md) |
| Codegraph integration, CLI fallback, soundness | [references/codegraph-integration.md](references/codegraph-integration.md) |
| Remote context handoff guide | [references/remote-handoff.md](references/remote-handoff.md) |
