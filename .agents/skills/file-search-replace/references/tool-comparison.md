# Tool Comparison and Decision Guide

Detailed comparison of the file search tools covered by this skill, with
guidance on when to use each one.

---

## Quick Decision Flowchart

```
What are you trying to do?
|
|-- Search for TEXT PATTERNS in files?
|   |
|   |-- In source code files?
|   |   --> Use grep tool or rg (ripgrep)
|   |
|   |-- Need to match CODE STRUCTURE (not just text)?
|       --> Use ast-grep (sg)
|
|-- Find FILES by name, path, or attributes?
|   --> Use find tool or fd
|
|-- Find RELATIONSHIPS (callers, callees, impact, flow)?
|   |
|   |-- Is .codegraph/ initialized?
|   |   |
|   |   |-- Yes --> Use codegraph_* tools or codegraph CLI
|   |   |         (confirm with grep before renames)
|   |   |
|   |   |-- No --> Use grep (ripgrep) + Read loops
|   |
|   |-- Need COMPLETE caller list? --> Use grep (codegraph is unsound)
```

---

## Feature Comparison: Text Search Tools

| Feature | grep tool (rg) | ast-grep (sg) |
|---------|---------------|---------------|
| **Primary use** | Text/regex search in files | Structural code search |
| **Search method** | Regex (PCRE2) | AST pattern matching |
| **Speed** | Extremely fast | Fast (per language) |
| **Respects .gitignore** | Yes (default) | Yes |
| **Multi-language** | Via file type filters | Per-language parsers |
| **Multiline** | With `-U` flag | Natural (AST-based) |
| **Replace support** | Preview only (`-r`) | Yes (structural rewrite) |
| **JSON output** | Yes (`--json`) | Yes (`--json`) |
| **Whitespace sensitive** | Yes | No (AST-based) |
| **Comment aware** | No | Yes (can skip comments) |

### When to Choose Which

**Choose grep/rg when:**
- Searching for string literals, log messages, error codes
- Searching for simple patterns like function names, variable names
- Searching across all file types simultaneously
- You need maximum speed on large codebases
- The pattern is straightforward text or regex

**Choose ast-grep when:**
- Matching function calls with specific argument patterns
- Finding code structures regardless of formatting
- Matching patterns that span multiple lines unpredictably
- Finding anti-patterns or code smells structurally
- You need to ignore comments and whitespace in matches
- Regex would be too fragile for the code pattern

For inline patterns and recipes, see
[references/ast-grep-patterns.md](ast-grep-patterns.md).

---

## Feature Comparison: Structural Navigation (codegraph)

| Feature | codegraph_* tools | codegraph CLI | grep/rg (fallback)
|---------|-------------------|---------------|---------------------|
| **Primary use** | Symbol relationships | Symbol relationships | Text/regex search
| **Speed** | O(1) SQLite lookup | O(1) SQLite lookup | Filesystem walk
| **Index required** | Yes (`.codegraph/`) | Yes (`.codegraph/`) | No
| **Soundness** | Unsound (false negatives) | Unsound (false negatives) | Complete
| **Output weight** | Light (symbol + location) | Light (symbol + location) | Medium (file + line)
| **Multi-file flow** | Native (callers/callees) | Native (callers/callees) | Manual aggregation

### When to Choose Which

**Choose codegraph when:**
- "Where is X used?" / "What calls Y?" / "What breaks if I change Z?"
- Tracing flow across multiple files
- Orienting in unfamiliar codebase (use `explore` for overview)
- Pre-ranking work before grep confirmation
- Repo is initialized (`.codegraph/` exists)

**Choose grep/rg when:**
- Need **complete** caller list (renames, signature changes)
- Searching for string literals, log messages, error codes
- `.codegraph/` doesn't exist and no time to initialize
- Short session (codegraph cold-start cost not worth it)
- Confirming codegraph results for completeness

**Soundness warning:** Codegraph is unsound — it silently drops method dispatch, generics, and trait-dispatch edges. Use grep to confirm completeness before renames or signature changes. See [codegraph-integration.md](codegraph-integration.md).

---

## Feature Comparison: File Finding

| Feature | find tool (fd) | find (system) |
|---------|---------------|---------------|
| **Speed** | Very fast (parallel) | Slower (single-threaded) |
| **Respects .gitignore** | Yes (default) | No |
| **Regex support** | Yes (default mode) | Limited (`-regex`) |
| **Glob support** | Yes (`-g`) | Yes (`-name`) |
| **Smart case** | Yes (default) | No |
| **Colored output** | Yes | No |
| **Syntax** | Intuitive | Verbose |
| **Execution** | `-x` (each), `-X` (batch) | `-exec`, `-exec +` |
| **Size filter** | `-S` | `-size` |
| **Time filter** | `--changed-within/before` | `-mtime`, `-newer` |

### fd vs find: Syntax Comparison

| Task | fd | find |
|------|------|------|
| Find .py files | `fd -e py` | `find . -name '*.py'` |
| Find by regex | `fd 'test_.*'` | `find . -regex '.*test_.*'` |
| Find directories | `fd -t d` | `find . -type d` |
| Find + delete | `fd -e pyc -x rm {}` | `find . -name '*.pyc' -exec rm {} \;` |
| Exclude dir | `fd -E vendor` | `find . -path ./vendor -prune -o -print` |
| Modified today | `fd --changed-within 1d` | `find . -mtime 0` |
| Size > 1MB | `fd -S +1m` | `find . -size +1M` |

**Always use fd instead of find.** It is faster, has better defaults, and
requires less typing.

---

## Performance Characteristics

Approximate performance on a large codebase (~500K files, 50M lines):

| Tool | Typical Time | Notes |
|------|-------------|-------|
| rg (targeted, -t py) | < 1s | File type filter is key |
| rg (unfiltered) | 2-5s | Searches all text files |
| fd (by extension) | < 0.5s | Very fast for file listing |
| ast-grep (single language) | 1-3s | Parses ASTs per file |
| codegraph query/callers | < 0.1s | O(1) SQLite lookup (requires index) |
| codegraph init (cold) | 6-12s | One-time cost per project |
| grep -r (same search as rg) | 30-120s | Single-threaded, no .gitignore |
| find (same search as fd) | 5-20s | Single-threaded |

---

## Tool Combinations

These tools work well together. Common combinations:

```bash
# Find files, then search contents
fd -e py --changed-within 1d -X rg 'TODO'

# Search for files, then analyze structurally
rg -l 'deprecated' -t py | xargs ast-grep --pattern '@deprecated' --lang py

# Find config files, search for setting
fd -g '*.{yml,yaml}' -X rg 'database:'

# Find test files by name, verify they test something
fd -g '*_test.go' -X rg 'func Test'

# Combine fd size filter with rg
fd -S +100k -e js -X rg 'TODO'  # TODOs in large JS files

# Codegraph + grep: find callers with codegraph, confirm with grep
codegraph callers MyFunction  # Pre-rank
rg 'MyFunction' -t go         # Confirm completeness

# Codegraph explore + grep: orient then verify
codegraph query AuthService   # Find definition
rg 'AuthService' -t go -C 3   # See all usages
```

---

## Installation

Core tools (usually pre-installed or available via package managers):

```bash
# Ubuntu/Debian
sudo apt install ripgrep fd-find
# Note: fd binary is 'fdfind' on Debian/Ubuntu, alias to 'fd'

# macOS (Homebrew)
brew install ripgrep fd ast-grep

# Cargo (Rust)
cargo install ripgrep fd-find ast-grep

# npm (ast-grep)
npm install -g @ast-grep/cli
```

---

## Further Reading

- ripgrep: https://github.com/BurntSushi/ripgrep
- ast-grep: https://github.com/ast-grep/ast-grep
- fd: https://github.com/sharkdp/fd
