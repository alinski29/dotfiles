---
name: refine-ticket
description: Sharpen a prepared ticket into an implementation contract — the public shapes (types, signatures, interfaces, seams) plus an optional RED-phase test plan - before it is handed to an implementer. Use when a ticket is already broken down but is still missing the contract details that would let an implementer code without repeated review churn. Refine by grilling the human from foundational contract decisions down to details.
---

# Refine Ticket

A ticket from the chain (`/to-spec` -> `/to-tickets`) carries requirements, acceptance criteria, and reference anchors — but not the contract: the exact types, signatures, interfaces, and test surfaces the implementer must build to. Without that, the implementer free-wheels, the reviewer catches the mismatch, and the loop repeats.

This skill closes that gap. It refines a ticket into a **contract**: the public shapes agreed before implementation, plus an optional RED test plan. It works standalone, is optional in the chain, and must never be assumed.

The playbook: **grill** — the contract questions start from the foundational decisions and narrow to details (see `/grill-with-docs`). The ticket is the settled root; don't reopen what `/to-tickets` already decided.

## When to run

Run when the ticket is ready but the implementation contract is not. The trigger is the user asking for the ticket to be clarified, pinned down, or made implementation-ready: "agree the contract", "what are the types?", "what does the interface look like?", "plan the RED tests", "refine this ticket".

It is **optional**. Contracts can be refined with or without TDD; with or without lingering behavior notes. Nothing here must happen for a ticket to be implemented.

## Which mode

Two modes, inferred from how the request is worded, not by a flag:

- **Contract core** — the public contract: types, signatures, interfaces, seams, per-AC mapping. Always produced.
- **Contract + TDD** — the above plus a RED test plan. Produced when the human language signals tests or TDD ("red-green", "failing test first", "what do the tests look like", "RED phase").

If the language is ambiguous, ask — don't assume.

## Vocabulary

Use the `/codebase-design` vocabulary (module, interface, depth, seam, adapter, leverage, locality) so this skill stays consistent with `/tdd`. The load-bearing terms here:

- **Module** — anything with an interface and an implementation; scale-agnostic (function, class, package, slice).
- **Interface** — everything a caller must know to use the module correctly: the type signature, plus invariants, ordering, error modes, required config. *Not* just the type-level surface.
- **Seam** — the public contract of a module; where its interface lives. When there is no explicit interface, the public functions/methods reachable from outside. A seam can span many files.
- **Depth** — behavior per unit of interface a caller must learn. Prefer the deep module.
- Reference anchors in the ticket are for **navigation**, not seam separation.

## Process

### 1. Read the record

Fetch the ticket's full body and comments from the configured issue tracker, typically in `./docs/agents/issue-tracker.md`. In case a parent spec exists, you may read it for orientation, but only when more context is needed: tickets should be, in general, self-contained. Read the reference anchors to map the current code around the seam; anchors are pointers, not boundaries.

### 2. Read joining docs when present

Read `CONTEXT.md` (domain glossary), AGENTS.md, and any ADRs in the touched area so the contract uses the project's vocabulary and doesn't re-litigate settled decisions.

### 3. Grill the frontier

Run the `/grill-with-docs` session. Compose the contract questions from the settled properties, broadest first:

- Where does the module(s) sit, and what is each seam?
- What is the public interface (types, signatures, invariants, error modes) at each seam?
- Which AC groups into which deliverable slice, and in what order?
- What must not happen (failure cases) — the behavior notes — when requested?
- In TDD mode: what red test for each slice covers each AC?

Let the sub-questions jump off each answer. Work from the coarse questions to the fine ones.

### 4. Produce the contract section

On approval, append an **Implementation Contract** section to the ticket body (the tracker issue opened, or the local file for local trackers). Add a short line to the ticket so the implementer knows the contract exists.

The contract groups by **Deliverable Slices** — the AC-grouped units of work, in the ticket's existing dependency/blocker chronology. Do not re-sequence; the ticket's order is settled by design. Only re-derive order if investigation shows the plan was wrong, as the exception. Within each slice, the seams it crosses, the contract it carries, and the red test (TDD mode).

## Output shape

```
## Implementation Contract

**Approved by:** <who> on <date>
**Mode:** contract-only | contract + TDD

### Deliverable Slices

**[AC1] <slice title>**
- **Seams touched:** <modules/interfaces/seams across files>
- **Contract:** <types, signatures, invariants, error modes at the seam>

[AC3, AC4] <slice title>
- ...

[AC2, AC6] <slice title>
- ...
```

### RED test plan (TDD mode only)

For each slice, a red test inventory — names + assertion intent, not code. One vertical red -> green cycle per slice; behavior not implementation. There is **no hard rule** on test granularity: a larger test may cover a slice with several ACs, or focused tests may cover single ACs. Choose situationally; the goal is reducing ambiguity, not counting rules. Each AC's expectation stays recorded so the implementer's red test aligns with the human's.

### Behavior notes (optional)

Edge cases and "must not happen" boundaries, kept optional. When omitted, the slice contract already covers it.

### Anchor map (navigation only)

Map each ticket reference anchor to the slice/seam it navigates. Not a seam list.

## Rules

- **Never** append the contract to the ticket until the human approves the grilled draft.
- **Never** re-sequence the AC order the ticket already declares; that is `/to-tickets`' settled ground, re-opened only when investigation shows the plan was wrong.
- **Never** write implementation code into the contract; the contract carries shapes, not bodies.
