---
name: tool-summary
description: Generates a one-page Markdown summary for a technology by researching its official website, documentation, and GitHub repository, then writes the note to Obsidian. Use when the user wants a concise technical summary of a tool, library, framework, service, website, or language.
---

# Tool Summary

Create a single Markdown note for the requested technology.

## Output goal

Produce one Obsidian-ready Markdown file with the exact structure below, using accurate source URLs and concise, technically precise writing.

## Workflow

1. Identify the technology from the user request.
2. Determine the output file path:
   - If the user explicitly provides a destination path, use it.
   - Otherwise write to `~/Documents/Obsidian/Tools/`.
   - Expand `~` to the home directory.
   - The file name should be capitalized and match the technology name. It can also contain spaces, e.g.: "Apache Arrow.md".
3. Determine the `used` frontmatter value:
   - Set `used: 1` only if the user explicitly says they have used this skill or asks for `used` to be true.
   - Otherwise set `used: 0`.
   - Never ask the user a question about `used`.
4. Determine the `tags` frontmatter value:
   - Always include `/tool`.
   - Allowed additional values are: `open-source`, `library`, `self-hosting`, `devops`, `ai`, `rag`, `llm`, `python`, `golang`, `datastore`, `web-dev`, `web-design`.
   - If the user explicitly specifies tags in the message, use those tags directly and do not ask for confirmation.
   - Otherwise infer a proposed tag list from the research and ask the user to confirm it with `ask_user_question` before writing the note.
   - Use a multi-select question and present the proposed tags in the options or description so the user can accept or adjust them.
   - Write the final YAML value as an inline list, for example: `tags: [/tool, open-source, python, ai, llm]`.
5. Research sources in this order of preference:
   - official website
   - official documentation
   - canonical GitHub repository
   - logo or brand image from an official source, if available
6. Use web tools / web search to find the most relevant sources.
7. Prefer authoritative sources over secondary sources.
   - If multiple sources conflict, prefer official documentation over the website, and the website over third-party references.
   - Do not guess URLs when they cannot be verified.
8. Write the final note as a clean Markdown document with no internal citation markers.
9. Use a slugified technology name for the filename unless the user explicitly requests a different filename.

## Exact note structure

```markdown
---
category: "library/framework/technology/website/programming-language/datastore/service"
used: 0
familiarity: null
documentation_url: "https://example.com/docs"
repository_url: "https://github.com/example/repo"
website_url: "https://example.com"
logo_url: null
created_time: "2025-02-17T12:00:00Z"
updated_time: "2025-02-17T12:00:00Z"
tags: [/tool]
---

# Technology Name

## Overview
Write a concise narrative overview of the technology, its purpose, and what makes it notable.

## Key Features
- At most five key features.
- Keep each item short and specific.

## Resources
- [Documentation](https://example.com/docs)
- [Repository](https://github.com/example/repo)
- [Website](https://example.com)

## Similar Technologies
- Up to five, ordered by popularity.
- Add a link if you have a reliable official or GitHub URL; otherwise use plain text.

## Personal Notes & Experience

## AI summary sources
- List the five most relevant web resources used in the research, ordered by relevance.
- Prefer official sources.

## Related topics and concepts
- Three to five related topics or concepts.
- Add a link when a reliable reference is available.
```

## Writing rules

- Keep the summary concise and technically precise.
- Make the `category` the most appropriate single option for the technology.
- Fill `documentation_url`, `repository_url`, and `website_url` with the best verified canonical URLs.
- Set `logo_url` to a direct image URL only when it can be verified from an official source; otherwise leave it as `null`.
- Set `created_time` and `updated_time` to the current UTC timestamp in ISO 8601 format.
- Keep `Personal Notes & Experience` blank.
- Do not exceed five items in `Key Features` or `Similar Technologies`.
- If a field cannot be verified, prefer `null` or an empty section over inventing details.
- The `tags` field must always be an inline YAML list.
- If the user explicitly gave tag instructions in the message, follow them without asking.
- Otherwise ask for tag confirmation with `ask_user_question` before writing the note.
- If the user specifies a different destination path, obey it exactly.
