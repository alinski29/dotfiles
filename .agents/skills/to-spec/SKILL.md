---
name: to-spec
description: Use when system behaviour must be agreed before implementation, work crosses components or interfaces, acceptance criteria matter, or technical decisions must become an implementation-ready specification.
---

# To Spec

Create an implementation-ready engineering spec from settled requirements, existing decisions, and codebase context. Use it for substantial features as well as architecture, migrations, refactoring, platform infrastructure, API contracts, and internal developer experience.

## Process

1. Gather source material
   - Read any ADRs, existing specs, issue text, and relevant conversation context.
   - If paths are provided, read those files first.
   - If no paths are provided, infer the relevant docs from the user request.

2. Explore the codebase
   - Read local `AGENTS.md` files before inspecting implementation files.
   - Identify current integration points, ownership boundaries, data flow, and likely files/modules.
   - Prefer code facts over assumptions. If a claim can be checked in code, check it.

3. Ask only blocking questions
   - Do not interview by default.
   - Ask only when ambiguity would materially change the architecture, scope, or migration order.
   - Otherwise document assumptions explicitly.

4. Draft the spec
   - Use the template below.
   - Describe current and required behaviour, flows, failure cases, contracts, ownership, acceptance criteria, and verification.
   - Cover security, privacy, observability, compatibility, rollout, and migration only when relevant.
   - Separate confirmed requirements, assumptions, and open questions.
   - Do not write implementation steps, issue breakdowns, or detailed code changes.
   - Include small code-shaped examples only when they define an interface or contract.

5. Save the spec
   - Default path: `docs/specs/YYYY-MM-DD-<topic>.md`.
   - If the repo uses another docs layout, follow that convention.
   - If the user requested a specific path, use it.

6. Self-review
   - Check for placeholders, contradictions, vague ownership, and missing deletion criteria.
   - Ensure each relevant ADR decision appears in the spec or is explicitly out of scope.
   - Ensure changed behaviour has externally verifiable acceptance criteria and an appropriate verification method.
   - Ensure the spec can feed `to-issues` without needing another design pass.

## Output Rules

- Write the spec file; do not only print it in chat.
- Keep the spec implementation-neutral.
- Do not publish issues.
- Do not create a product PRD unless the user explicitly asks for one.

## Good Inputs

- "Turn these ADRs into a spec."
- "Create an engineering spec for removing Action Queue."
- "Convert this architecture discussion into a spec."
- "Write a brownfield migration spec from this plan."

## Spec template 

# <Title> Spec

## Goal

State what this changes and why. Keep this to one or two paragraphs.

## Requirements

### Confirmed

- Settled behaviour and constraints.

### Assumptions

- Unconfirmed assumptions that shaped this spec. Omit when empty.

## Background

Describe the current architecture, pain points, and relevant constraints. 

<important>
Always link to ADRs or existing docs. The user may refer to an ADR as context when using this skill, use that ADR. If none exist then do not link anything.
</important>

## Decisions

List accepted decisions that shape the spec. Reference ADRs when available.

- Decision:
- Source:
- Consequence:

## Scope

### In

- What this spec covers.

### Out

- What this spec explicitly does not cover.

## Current Architecture

Describe the existing data flow, ownership boundaries, modules, and integration points.

## Current Behaviour

Describe externally relevant behaviour that changes. Omit when the spec is purely structural.

## Target Architecture

Describe the desired ownership model and data flow. Name the important modules, providers, APIs, contracts, and deletion boundaries.

## Required Behaviour

Describe user or system flows, including important success paths, failures, recovery, and edge cases. State what the system must not do where that boundary matters.

## Contracts

Define stable interfaces and data shapes. Include examples only when they clarify the contract.

Examples:

- API response shape
- command/event shape
- provider/hook API
- route contract
- bootstrap payload
- migration compatibility adapter

<important>
    You MUST tag contracts with [ADDED], [REMOVED], and [CHANGED] based on the change being introduced.
</important>

## Migration Plan

Only write this section if a migration plan is required. Ask only when migration ambiguity would materially change the design.

Break the migration into phases. Each phase should be independently reviewable and should reduce risk.

### Phase 1: <Name>

- Change:
- Compatibility:
- Acceptance criteria:

### Phase 2: <Name>

- Change:
- Compatibility:
- Acceptance criteria:

## Deletion Criteria

If applicable, list the conditions that allow old code, adapters, flags, or compatibility paths to be removed.

## Acceptance Criteria

- [ ] Externally observable or executable completion criterion.
- [ ] Failure or edge-case criterion where relevant.
- [ ] Compatibility or migration criterion where relevant.

## Testing Strategy

For each changed behaviour, identify the appropriate verification level: unit, integration, contract, end-to-end, type checking, compilation, or runtime observation.

Cover critical success paths, failure behaviour, compatibility requirements, and regression risks. Prefer tests through public interfaces over implementation-detail tests.

State any behaviour that cannot be verified automatically and how it will be validated instead. Do not prescribe individual test files unless their location is part of an established repository convention.

## Operational Considerations

Include security, privacy, observability, rollout, and compatibility requirements when relevant. Omit this section when none apply.

## Open Questions

- Only unresolved decisions. Do not include questions that the spec already answers.
