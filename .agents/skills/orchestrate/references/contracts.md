# Orchestration contracts

## Coordinator

Coordinator owns intake, explicit repository resolution, issue metadata and native dependency reads, policy precedence, manifests, worktree setup, serial queues, child launch `cwd`, review gates, pause/recovery state, push, and PR creation. Coordinator does not read issue bodies during normal scheduling, never edits repository source, silently repairs Git state, or merges.

Minimum feature manifest:

```json
{
  "repository": "owner/name",
  "checkout": "/path/to/repository",
  "ticket": "123",
  "parent": "120",
  "feature": "feature-name",
  "branch": "feature/name",
  "worktree": "/path/to/worktree",
  "mode": "normal|afk",
  "review": "none|ticket-ai|feature-ai|human|ticket-ai-human",
  "model": "configured-model-policy"
}
```

## Implementer

Implementer is sole writer for assigned repository/worktree. It reads standards and local context, fetches its assigned issue body and comments by identifier with explicit `gh --repo`, and fetches parent or related issue content only when scope requires it. It changes only assigned scope, verifies, and commits. It returns:

```json
{
  "commit": "sha",
  "changedFiles": ["relative/path"],
  "verification": [{"command": "...", "result": "passed|failed|skipped"}],
  "residualRisks": ["..."]
}
```

It does not push, create PRs, merge, reset, stash, delete, change issue scope, or spawn children/reviewers.

## Reviewer

Reviewer is fresh, read-only child. It receives repository/worktree, issue or feature identifier, commit/diff, and standards/spec references. It fetches the assigned issue body and comments itself with explicit `gh --repo`; the coordinator does not copy issue bodies into the prompt. It does not edit or commit. Findings use this shape:

```json
{
  "scope": "ticket|feature",
  "reviewPass": 1,
  "findings": [
    {
      "classification": "blocking|non-blocking",
      "file": "relative/path",
      "line": 1,
      "message": "...",
      "recommendation": "..."
    }
  ],
  "summary": "..."
}
```

Coordinator decides whether fresh implementer fix pass is required.

## Child artifacts and reporting

Every child run writes evidence under `<cwd>/.pi/subagents/artifacts/` or `<cwd>/.pi-subagents/artifacts/` (artifactDir: project).

- `<runId>_<agent>_0_input.md` - the task prompt
- `<runId>_<agent>_0_output.md` - the child's final response text, untruncated
- `<runId>_<agent>_0_meta.json` - run metadata (model, exit code, duration, resolved skills, skillsWarning)
- `<runId>_<agent>_0_transcript.jsonl` - full session log; routinely >500KB, never read raw into context, explore via scout or targeted grep instead
- `.pi/subagents/artifacts/outputs/<runId>/<output-file>` - the report file declared in the agent frontmatter `output:` field: `scout-report.md`, `researcher-output.md`, `reviewer-report.md`, `worker-report.md`

The child writes its report to the resolved output path with the `write` tool. If it does not, the runtime persists the final response there at run end, so the file is never missing. The parent reads the report file. The `runs.run` result `.output` carries only the child's final response text, truncated at 200KB/5000 lines for display; the untruncated text is always in `_output.md`. The transcript is separate and optional reading.

Children coordinate over the supervisor channel (`contact_supervisor`, reasons `need_decision` / `progress_update` / `interview_request`, text-only, 64KiB cap) for intermediate updates and decisions. Reports and findings travel in the output files, not through the channel.

## Repository and safety boundary

One writer per repository/worktree. Cross-repository work may run concurrently only in separate worktrees and only after native blockers are rechecked. Every child uses resolved worktree as `cwd`; every GitHub command names explicit `--repo`. Preserve unrelated user and human-authored changes. Stop on ambiguity, dirty state, dependency inconsistency, timeout, scope drift, or review exhaustion.

## Publication

Coordinator verifies commits, tests, dependencies, and reviews. Normal mode asks before push/PR. AFK may push/open PR but never merge. Publish one PR per affected repository with ticket list, verification evidence, review status, and residual risks. Human approves merge.
