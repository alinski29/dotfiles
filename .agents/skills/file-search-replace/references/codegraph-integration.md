# Codegraph Integration

How codegraph fits into the file-search workflow, with availability checks,
CLI fallback, and soundness rules.

---

## Availability Check Flow

Before using codegraph, verify it's available:

```
1. Is .codegraph/ directory present in project root?
   |
   |-- No → SKIP codegraph entirely. Use grep/ast-grep.
   |        (Do not attempt to initialize — user must do this manually.)
   |
   |-- Yes → Continue to step 2
   |
2. Are codegraph_* Pi tools available? (try codegraph_status)
   |
   |-- Yes → Use Pi tools (preferred)
   |
   |-- No → Use CLI fallback via bash
```

**Key rule:** If `.codegraph/` doesn't exist, do NOT use codegraph.
The user must initialize it manually with `codegraph init`.

---

## CLI Fallback (When Pi Tools Not Available)

Use these commands when `codegraph_*` tools are not wired:

| Pi Tool | CLI Command |
|---------|-------------|
| `codegraph_search` | `codegraph query <name> --json` |
| `codegraph_callers` | `codegraph callers <name> --json` |
| `codegraph_callees` | `codegraph callees <name> --json` |
| `codegraph_impact` | `codegraph impact <name> [--depth N] --json` |
| `codegraph_node` | `codegraph query <name>` (for symbol location) |
| `codegraph_files` | `codegraph files --json` |
| `codegraph_status` | `codegraph status` |
| `codegraph_explore` | `codegraph explore "<query>" --json` |

**Example workflow with CLI:**

```bash
# Check if codegraph is available
codegraph status 2>/dev/null && echo "Available" || echo "Not initialized"

# Find callers via CLI
codegraph callers MyFunction --json

# Confirm with grep (completeness)
rg 'MyFunction' -t go
```

---

## Soundness & Limits — Critical

Codegraph is built on tree-sitter, not the compiler. Its call/reference
edges are an **approximation** with false negatives.

> **Grep is the source of truth for *completeness*. Codegraph is the
> accelerator for *orientation and traversal*. Never invert these.**

### Three Confirmed Failure Modes

1. **Unsound edges → false negatives.** `callers`/`callees`/`impact` miss
   real call sites when the receiver type can't be resolved from syntax alone
   (calls on locals, generics, trait objects). A method with **8** real callers
   returned **2** — the 5 dropped were `local.method()` and generic-dispatch
   sites, with **no warning**.

2. **Name resolution is fuzzy and overload-blind.** Bare-name queries
   prefix-match (`useWorkspace` answered for `useWorkspacesQuery` — a
   *different symbol*) and conflate overloads (`execute`, with 19 definitions,
   returned `sqlx`'s `.execute()` DB calls, not the trait method).

3. **The index lags the disk.** CLI sees nothing until `codegraph sync`
   (~0.3s); the MCP file-watcher closes the gap to ~1–2s. Right after an
   edit, the index is wrong — grep/Read is ground truth until it catches up.

### When to Confirm with grep

| Scenario | Use codegraph | Confirm with grep |
|----------|---------------|-------------------|
| Orient / "explain subsystem" | ✓ (explore) | No |
| Find callers of uniquely-named function | ✓ (callers) | No (exact on unique names) |
| **ALL callers before rename/signature change** | Pre-rank only | **Yes (authoritative)** |
| Overloaded name (`execute`, `lookup`, `run`) | Skip | **Yes** |
| Impact of core type | Pre-rank (`--depth 1`) | **Yes** |
| Just-edited code | Skip (stale index) | **Yes** |
| Trait-dispatch / generic call sites | Skip | **Yes** |

---

## Heavy vs Light Tools

| Tool | Weight | Main Session | Subagent |
|------|--------|--------------|----------|
| `codegraph_search` | Light | ✓ | ✓ |
| `codegraph_callers` | Light | ✓ | ✓ |
| `codegraph_callees` | Light | ✓ | ✓ |
| `codegraph_impact` | Light | ✓ | ✓ |
| `codegraph_node` | Light–Med | ✓ | ✓ |
| `codegraph_files` | Light | ✓ | ✓ |
| `codegraph_status` | Light | ✓ | ✓ |
| `codegraph_explore` | Medium | ✓ | ✓ |

**Rule:** Use light tools in main session. Avoid heavy context gathering
directly — delegate to subagents for exploration tasks.

---

## Project Init Requirement

Codegraph requires a pre-built index. The `.codegraph/` directory contains:

- `codegraph.db` — SQLite knowledge graph
- `.gitignore` — excludes `*.db`, `*.db-wal`, `*.db-shm`

**User must initialize manually:**

```bash
npm install -g @colbymchenry/codegraph  # One-time install
cd <project-root>
codegraph init -i                        # Interactive; also indexes
```

**Do NOT attempt to initialize codegraph for the user** unless explicitly
asked. The init process may prompt for configuration choices.

---

## Decision Matrix: codegraph vs grep vs ast-grep

| Task | Tool | Why |
|------|------|-----|
| Orient / "explain subsystem X" | **codegraph `explore`** | One call, ranked, verbatim source |
| Callers of **uniquely-named** free function | **codegraph `callers`** | Exact on unique names + direct calls |
| Find **ALL** callers before rename | **grep** (codegraph only to pre-rank) | Codegraph is unsound — completeness can't depend on it |
| Overloaded name (`execute`, `lookup`) | **grep**, or codegraph `node` on specific id | Bare-name codegraph conflates / under-resolves |
| Impact of a core type | **codegraph `impact --depth 1`** to pre-rank, then grep to confirm | Default depth-2 inflates and isn't depth-ranked |
| Just-edited code | **grep** (or `codegraph sync` first) | Index is stale until reindex |
| Trait-dispatch / generic call sites | **grep + reading** | Both weak; codegraph silently drops them |
| String literals, log messages | **grep** | Text search, not relationships |
| Code structure patterns | **ast-grep** | Structural search, not relationships |
| Files by name/path | **find/fd** | File discovery, not content |

---

## Workflow Summary

1. **Orient first** — Use `codegraph explore` (or `codegraph query`) to map the terrain
2. **Pre-rank with codegraph** — Use `callers`/`callees`/`impact` for direction
3. **Confirm with grep** — When completeness matters (renames, signature changes)
4. **Treat delta as "codegraph missed it"** — Not "grep over-matched"

---

## Related Files

- [tool-comparison.md](tool-comparison.md) — Full feature comparison tables
- [search-strategies.md](search-strategies.md) — Scoping and refinement techniques
- Upstream codegraph skill: `~/.agents/skills/codegraph/SKILL.md`
