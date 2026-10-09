---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

If the user passes a ticket reference, fetch it from the issue tracker and state its title before starting. If the reference is ambiguous, ask.

You run inside the assigned worktree: the process `cwd` is already the repository root. Use paths relative to `cwd` directly; do not prefix bash commands with `cd <worktree>`.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, call the Skill tool with "code-review" to review the work.

Review is opt-in and defaults to false. Enable it when human language clearly requests code review, including `/code-review`, "do a code review", "review this code", or equivalent wording. An active orchestration review policy such as `needs-ai-review` also enables review. In `afk` mode, invoke `/code-review` when policy enables it without prompting. Coordinator-launched implementers still do not invoke nested review; coordinator owns those review gates and starts fresh read-only reviewers.

Commit completed work to current branch. Return commit SHA, changed files, verification results, and residual risks.
