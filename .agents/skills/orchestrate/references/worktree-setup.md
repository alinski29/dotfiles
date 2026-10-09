# Worktree setup reference

`worktree-setup` is generic plumbing. It creates or reuses a feature branch/worktree, then prepares agent context. It does not depend on Pi hooks.

## Install and invocation

Install manually; skills must not alter `PATH`:

```bash
mkdir -p ~/.local/bin
ln -sfn /path/to/development-workspace/scripts/worktree-setup/worktree-setup ~/.local/bin/worktree-setup
command -v worktree-setup
```

Required arguments are `--repo` and `--branch`; `main` is rejected. Optional arguments: `--worktree`, `--config`, `--herdr-session`, `--dry-run`. For a traditional repository, pass the current checkout explicitly as `--repo "$PWD"`. For a layered workspace, resolve the affected repository checkout first and pass that path. Missing branches are created from repository-local `main`, never remote/HEAD. Spawn each child with `cwd` set to the resolved worktree. Default path:

```text
${WORKTREE_HOME:-$HOME/.herdr/worktrees}/<repository-name>/<branch-with-slashes-replaced-by-hyphens>
```

Without `--worktree`, exact branch worktrees are located first. Ambiguous, mismatched, colliding, dirty, or already-attached state fails closed. Never reset, stash, delete, switch, force-update, or overwrite. `--dry-run` must not mutate Git, files, or Herdr.

## Preparation contract

Configuration defaults to `$PWD/.worktree-setup.json`; `--config` overrides it. Artifact sources resolve relative to config and targets to worktree root. Existing identical files are accepted; differing files fail. Targets are added idempotently to `.git/info/exclude`, never repository `.gitignore`; setup artifacts remain untracked.

Artifacts may declare an optional `repo` filter (string or array) matched against the `--repo` argument with the same resolution logic as the command: the value is resolved against the command's working directory and compared to the resolved repository checkout, so `--repo repos/backend` matches `"repo": "repos/backend"`. Omitted `repo` applies to every repository; non-matching artifacts are skipped and their sources never touched, so a frontend-only artifact cannot break a backend worktree.

Artifacts may declare `"symlink": true` to create a symlink at `target` pointing to the resolved absolute `source` instead of copying (use for heavy ignored directories such as `node_modules`). A target that is already a symlink to the same source is reused idempotently; any other existing target fails closed; a missing source fails closed. Symlink targets stay inside the worktree lexically but may point anywhere, and are added to `.git/info/exclude` like copied artifacts. `--dry-run` reports without creating anything.

Preparation may copy shared standards and issue-tracker guidance, reuse ignored Pi dependencies, link skills from repository manifests, and initialize repository-local CodeGraph where `.pi/settings.json` requires it. It must leave generated indexes, caches, dependencies, and `.pi-subagents` untracked. Tracked Pi settings and guardrails come from normal Git worktree creation. Missing optional configuration means no artifact copying.

Examples:

```bash
# Traditional repository, current checkout as repository source.
worktree-setup --repo "$PWD" --branch feature/example

# Layered workspace, explicit affected repository checkout.
worktree-setup --repo /path/to/project-repo --branch feature/example

# Existing Herdr session.
worktree-setup --repo "$PWD" --branch feature/example --herdr-session dev
```

Configuration example:

```json
{
  "version": 1,
  "artifacts": [
    {"source": "CODING_STANDARDS.md"},
    {"source": "docs/agents/issue-tracker.md"},
    {"source": "repos/backend/.env.dev-local", "target": ".env.dev-local", "repo": "repos/backend"},
    {"source": "repos/frontend/.env.dev", "target": ".env.dev", "repo": "repos/frontend"},
    {"source": "repos/frontend/node_modules", "target": "node_modules", "repo": "repos/frontend", "symlink": true}
  ]
}
```

Herdr integration is optional. `--herdr-session` requires `herdr` in `PATH`; inside Herdr, omitted session may use `HERDR_SESSION`; outside Herdr, omission skips integration. Setup does not configure Pi hooks or user-level Pi settings.
