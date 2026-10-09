---
name: orchestrate
description: Coordinate dependency-aware implementation across layered development workspaces or one repository.
disable-model-invocation: true
---

# `/orchestrate`

Run from current project context. Accept a parent/spec issue, ticket identifier, feature manifest, or explicit instructions. This skill coordinates work; it does not replace issue content or repository-local instructions. It supports both layered development workspaces and traditional single-project repositories.

## 1. Intake and policy

1. Locate project context. Read `AGENTS.md`, `CONTEXT.md`, `CODING_STANDARDS.md`, and `docs/agents/issue-tracker.md` from the current project or workspace when present. Read nearest repository-local guidance before acting. Read `references/contracts.md` when launching children and `references/worktree-setup.md` when preparing worktrees.
2. Resolve issue metadata with GitHub CLI and explicit `--repo` on every issue operation. During normal intake, request only identifiers, titles, state, labels, repository, parent, project, and native `blockedBy` relationships. Do not request or read issue bodies, comments, or parent issue content while listing or scheduling tickets. Child workers and reviewers fetch their assigned ticket body and comments themselves. Fetch parent or related issue content only when ownership, policy, or feature-scope ambiguity cannot be resolved from metadata.
3. Infer topology. A layered workspace has independent repository checkouts; map each ticket to its affected repository explicitly. A traditional repository has one checkout. Ask only when repository ownership remains ambiguous.
4. Resolve policy in this order: chat instruction > ticket label > parent label > coordinator default. Resolve mode (`normal` or `afk`), defaulting to `normal` when unspecified, plus branch/worktree policy, review policy, and model policy. Parent `afk` applies to children; ticket `afk` is an override. `needs-human-review` is ticket-only. Parent `needs-ai-review` means one aggregate feature review, not per-ticket review. `smart-implementer` selects a stronger configured implementation model; if no mapping exists, stop and ask rather than guess.
5. Build a manifest for each ticket. Include repository (`owner/name` and resolved checkout), ticket, parent, feature, branch, worktree, mode, review policy, and model policy. See `references/contracts.md` for the required manifest shape. Pass identifiers and manifest, not copied issue content. Preflight required issue access, repository/worktree identity, fixed-point availability, non-empty review scope when applicable, required local guidance, and required child skills before launching a child. Missing optional proto context, planner artifacts, chain progress, optional ADRs, or optional LSP/lint capabilities are degraded verification, not prerequisite failures.
6. Keep path references portable. Never put the coordinator's `PWD`, workspace root, home-directory path, or another checkout's absolute path into a child task, artifact list, or manifest unless it is an explicit path required by the child contract. Refer to the resolved child `cwd` as the root, and use paths relative to that worktree. The child process already starts with `cwd` set to the resolved worktree - tell the child it is already inside the worktree and to use paths relative to `cwd` directly; do not phrase tasks as if the child needs to `cd` into it, which invites redundant `cd` prefixes on every command. If a cross-repository path is required, document its purpose and pass it only as an explicit setup/configuration value.

## 2. Topology and worktree setup

Check `command -v worktree-setup` before setup. If absent, stop and ask user to expose manual symlink; never alter `PATH` silently.

For a normal repository, invoke from current checkout with:

```bash
worktree-setup --repo "$PWD" --branch <feature-branch> [--worktree <path>] [--dry-run]
```

For layered workspaces, resolve affected repository checkout first, then invoke `worktree-setup --repo <resolved-checkout> ...`. Always launch child agents with `cwd` set to resolved worktree. Use `--repo` and `--branch`; reject `main` as target. Let setup infer or safely reuse exact matching worktrees. Read `references/worktree-setup.md` for CLI and preparation contract.

Stop on dirty, mismatched, missing, colliding, or ambiguous Git state. Never reset, stash, delete, silently switch, force-update, overwrite, or repair. Reuse matching feature branch/worktree only when identity and cleanliness are verified. Feature worktrees are default for multi-ticket or complex work; main-branch/no-worktree execution requires explicit user override.

## 3. Scheduling and worker handoff

Maintain one serial queue per repository/worktree. Recheck GitHub issue state, native blockers, and local Git state before every ticket. Run eligible tickets in dependency order. Independent tickets in different worktrees may run in parallel only when all native blockers permit it. Contract-changing work unblocks dependents only after commit and required review gate pass.

Use harness subagents for delegated work. Use the project-designated worker or implementer subagent for implementation and review-fix passes. Use the project-designated reviewer subagent for code review. Read `AGENTS.md` for this project's role mapping; when no mapping exists, use the harness roles that provide worker/implementer and reviewer behavior. The coordinator remains the sole orchestrator: implementation and reviewer subagents do not spawn nested agents.

Before launching, pass only the ticket identifier, repository/worktree manifest, and explicit artifact paths that exist. Resolve artifact paths relative to the child's `cwd`; do not pass paths relative to the coordinator's `PWD` and do not pass coordinator-only absolute paths. Never inject unconditional reads for `plan.md`, `progress.md`, or `context.md`. A child prerequisite failure pauses coordination and is not treated as an implementation failure to retry blindly.

Start one fresh implementer child per ticket or fix pass, with explicit `cwd` equal to resolved worktree and effective skill/tool permissions. Worker contract:

- fetch assigned issue and parent with `gh ... --repo`, read standards and nearest repository context;
- implement only assigned scope and report ambiguity/scope changes;
- use TDD where appropriate and run repository verification;
- commit completed work and return SHA, changed files, verification, and residual risks;
- do not push, create PRs, merge, reset, stash, delete, broaden scope, or spawn nested agents/reviewers.

One writer at a time per repository/worktree. Preserve human-authored commits when resuming.

## 4. Review gates

Review is label-driven and scope-specific. No review label means continue without review or prompt. Ticket `needs-ai-review` reviews that ticket's committed diff. Parent `needs-ai-review` reviews complete feature diff after all tickets. Ticket `needs-human-review` pauses before next ticket and does not imply AI review. Both labels run AI review first, then pause for human review.

Start fresh read-only standards and specification reviewers directly. Reviewers fetch their assigned ticket body and comments using the explicit repository identifier; the coordinator does not copy issue content into their prompts. Reviewers never edit or commit and return findings classified `blocking` or `non-blocking`, with scope, pass, file/line, message, and recommendation. A fresh implementer applies findings. Human-requested fixes use a fresh implementer unless human edits directly; preserve and validate human commits. Allow at most two passes per review scope (initial plus re-review), and at most one non-blocking/style fix pass. Remaining blocking findings pause normal mode for input and pause AFK mode without prompting. Implementers never invoke nested `/code-review`.

Prefer the documented findings shape, but accept prose reports. Infer blocking status from severity, evidence, and recommendation rather than rejecting a report solely for schema mismatch. Surface uncertain classifications for human review. Model policy: follow the project's model conventions documented in its `AGENTS.md` or manifest model policy - typically a weaker per-run model override for the standards reviewer and the reviewer frontmatter defaults for the specification reviewer. If the project documents no conventions, use reviewer frontmatter defaults for both lanes. Apply overrides per-run at launch; never edit child agent frontmatter.

## 5. AFK, pause, and recovery

AFK suppresses routine prompts and may commit, push, and open PRs. It never bypasses ambiguity, dependency, dirty-state, review, or human-safety gates and never merges. Two worker failures for one feature within ten minutes, timeout, scope drift, dependency inconsistency, unsafe Git state, review-limit exhaustion, or required human review triggers pause.

Persist pause state: feature, repository, ticket, phase, reason, mode, last commit, review pass, and required human action. Prefer durable Pi mission/session state; when unavailable, use a project-local ignored state file outside product worktrees. Support `/orchestrate approve`, `/orchestrate request-changes <findings>`, `/orchestrate resume`, and equivalent natural language. Recovery rechecks issue and Git state; never blindly replays work.

## 6. Publication

Before publication verify local commits, verification evidence, dependency readiness, and review state. Normal mode asks before push and PR creation. AFK may push and open PRs but may not merge. Create one feature PR per affected repository. Include affected tickets, verification evidence, review state, and residual risks. Human owns merge approval.

## Contracts and references

- `references/worktree-setup.md`: generic setup command, safety, configuration, and preparation.
- `references/contracts.md`: coordinator, worker, reviewer, and publication ownership contracts.

This workflow is generic: infer repository topology and local policy rather than assuming a particular workspace, organization, or repository layout.
