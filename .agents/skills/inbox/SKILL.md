---
name: inbox
description: Capture, process, prioritize, and clean workspace Inbox.md items.
disable-model-invocation: true
---

# Inbox

Manage temporary `Inbox.md` work capture. Inbox items are rough pointers, not specifications, tickets, or an archive. Preserve user intent while making structure and next actions clearer.

Use only when the user explicitly invokes `/inbox`.

## Commands

- `/inbox capture <thought>` - append one captured item.
- `/inbox process [selection]` - inspect, prioritize, relate, estimate, and route items. Does not implement work, create GitHub issues, or invoke another skill.
- `/inbox clean [selection]` - audit structure, identify duplicates and stale/completed items, and propose merges or deletions.

Without a subcommand, ask whether the user wants `capture`, `process`, or `clean`.

## Locate the Inbox

Find the workspace-level `Inbox.md`. The file may cover multiple related repositories. Do not assume the current repository is the only project represented. Read workspace instructions and the Inbox before changing it.

## Canonical item format

Use one `# Inbox` heading, an optional `## Current goals` section, and one `##` heading per item. Each item has a required stable `id` metadata field and optional metadata fields.

Example:
```md
# Inbox

## Current goals

- Launch production-ready app by 2026-08-31.
- Prioritize launch blockers, reliability, and critical user flows.

## Support audio & video files

id: support-audio-video-files
type: enhancement
projects: all
labels: document-processing
priority: 4
impact: 5
effort: 4

Use a model to transcribe audio and video files.

---
```

Rules:

- Metadata field names are lowercase.
- `id` is required for every item. Assign it at capture time.
- Generate `id` as a short lowercase kebab-case slug from the initial title.
- IDs are stable forever. Do not change an ID when the title or body changes.
- Resolve collisions with a unique suffix such as `-2`; never reuse deleted IDs.
- `type` values: `bug`, `enhancement`, `task`, `grilling`, `note`.
- `projects` is a comma-separated project/repository list. Use `all` for whole-application work.
- Use controlled labels: `api`, `architecture`, `backend`, `billing`, `database`, `document-processing`, `frontend`, `infrastructure`, `knowledge-graph`, `schema`, `search`, `settings`, and `ux`. Propose new labels instead of inventing them.
- `priority`, `impact`, and `effort` are optional integers from 1 to 5. Higher means more.
- `priority` is relative to current goals, urgency, dependencies, and value.
- `impact` is expected product or technical value independent of current goals.
- `effort` is rough total work size, including relevant investigation, design, implementation, and review. It is not an hour estimate.
- `related` is one free-form field for references, suspected blockers, dependencies, and related items.
- `captured_at` is optional. Never invent it.
- All metadata is optional except `id`; skip values that are not obvious.
- Keep metadata immediately before the body, with one blank line between metadata and body.
- Keep one blank line between item body and `---`.
- Preserve substantive user content unless a clearer rewrite is approved.
- Newest capture goes at the bottom unless the user requests another ordering.

## Capture

1. Parse the supplied thought without turning it into a specification.
2. Create a concise heading that preserves the original intent.
3. Assign a stable unique `id` from the initial heading.
4. Add only obvious metadata. Use controlled labels.
5. Append the item to `Inbox.md`.
6. Report the new ID and any metadata assigned.

If an obvious duplicate exists, show it and ask whether to append, update, or cancel. Never merge during capture.

AI may suggest capture during conversation, but must wait for explicit user confirmation before writing.

## Process

`/inbox process` scans all items by default. It may accept selectors:

```text
/inbox process support-audio-video-files
/inbox process 01, 05, 08
/inbox process 01:06
/inbox process 01 to 06
/inbox process search
```

Stable slug IDs are the canonical selectors. Numeric selectors refer to current one-based item positions and are provided as a convenience; they are not stable references and can change after reordering. Numeric ranges are inclusive. If free-text selection matches multiple items, show candidates and process nothing until the user selects.

Read `## Current goals` and use it to rank work. Treat goals as free-form active context. A one-run focus may supplement current goals but does not rewrite them.

Produce an actionable report before proposing changes:

1. Inbox health and structural problems.
2. Recommended priority order, goal alignment, and deferrals.
3. Suggested metadata changes.
4. Effort, impact, and priority estimates with brief reasoning.
5. Relation candidates, distinguishing duplicates, likely prerequisites, shared topics, and shared labels.
6. Suggested grilling groups based on shared decisions or dependencies.
7. Items suitable for direct implementation.
8. Items needing repository-aware clarification.

Use summary-first output, followed by per-item details and a reviewable patch.

Safe mechanical formatting fixes may be applied automatically. Semantic changes require one explicit approval before applying:

- metadata additions or changes;
- labels, projects, scores, or relations;
- body rewrites;
- item reordering.

Never silently reorder. Preserve stable IDs when reordering. Never silently infer a blocker or dependency as fact. Propose likely relations and explain evidence.

Routing:

- Clear `type: task` items are direct implementation candidates.
- `bug`, `enhancement`, and `grilling` items normally need `/grill-with-docs` first.
- Prefer `/grill-with-docs` for repository, schema, code, architecture, and implementation-context questions. It routes through grilling with repository glossary access.
- Group multiple items into one suggested grilling session when they share a design decision or dependency.
- Do not invoke `/grill-with-docs`, `/grilling`, `/triage`, implementation, specification creation, or ticket creation automatically.

A rewrite may clarify grammar, factual mistakes, or an unclear pointer, but show the current text, proposed text, and reason before applying it.

## Clean

`/inbox clean` audits without doing downstream work. Check:

- heading, metadata, blank-line, and separator structure;
- required IDs and stable ID uniqueness;
- lowercase field names and valid type/score values;
- controlled labels and recognizable project names;
- duplicate or near-duplicate items;
- stale or completed-looking items;
- possible merge candidates;
- items that appear to have a GitHub issue or completed implementation replacement.

Apply deterministic formatting fixes automatically. Propose semantic changes.

For a merge proposal, show candidate IDs, retained ID, proposed combined title/body, and resulting metadata. Apply only after explicit approval. Never silently merge.

For deletion, require explicit user confirmation and a replacement reference when available:

```text
Delete item `support-audio-video-files`?
Replacement: GitHub issue #123
```

Deletion is appropriate only after a GitHub issue has been created or the work was solved/implemented in a session. `/inbox clean` performs deletion only after explicit confirmation. Do not archive deleted items in Inbox.

## Completion criteria

Capture is complete when one valid item with a unique stable ID is appended.

Process is complete when selected items have a report, proposed routing, proposed changes, and no unapproved semantic mutation remains.

Clean is complete when structural issues are fixed or reported, merge/delete candidates are presented, and no merge or deletion occurs without explicit confirmation.
