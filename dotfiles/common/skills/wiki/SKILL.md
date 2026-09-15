---
name: wiki
description: Create, ingest, query, or lint an LLM-maintained wiki. Use for wiki initialization and maintenance; do not use for unrelated documentation work.
---

Use an operation as the first argument:

```text
$wiki init <path> [topic]
$wiki ingest <source> [--wiki <path>]
$wiki query <question> [--wiki <path>]
$wiki lint [--wiki <path>]
```

For `ingest`, `query`, and `lint`, locate the wiki root from `--wiki <path>` when supplied; otherwise walk upward from the current working directory and use the nearest directory containing `AGENTS.md`, `raw/`, and `wiki/`. Resolve relative paths from the current working directory. If no valid root is found, stop and ask for a wiki path.

## init

Create the wiki at the requested destination. Before writing, confirm that the destination does not exist or is empty. If it already contains files, stop and ask the user how to proceed.

Create this layout:

```text
<wiki>/
├── AGENTS.md
├── CLAUDE.md -> AGENTS.md
├── raw/
│   └── index.md
└── wiki/
    ├── index.md
    └── log.md
```

Write a concise `AGENTS.md` that establishes `raw/` as immutable source material and `wiki/` as LLM-maintained derived material. Require every ingest to update the source manifest, relevant pages, wiki index, and log; queries to cite wiki pages; and lint to be read-only unless repairs are requested. Use the optional topic to tailor the title and initial index organization. Do not add example sources or generated content.

Report the resolved wiki root and the files created.

## ingest

Read the wiki root's `AGENTS.md` before doing any work and follow its Ingest workflow. Treat files under `raw/` as immutable. If the source is outside `raw/`, ask whether to copy it into `raw/` or process it in place; do not silently choose.

Update the source manifest, relevant pages, wiki index, and chronological log as required by the schema. Preserve existing pages unless the source materially supersedes them. State the source, pages changed, and unresolved gaps.

## query

Read the wiki root's `AGENTS.md`, then `wiki/index.md` before selecting the pages needed to answer. Follow the wiki's Query workflow. Cite supporting wiki pages and distinguish documented statements from inferences. Do not create or alter pages unless the user explicitly asks to file the result.

## lint

Read the wiki root's `AGENTS.md` and follow its Lint workflow. Inspect the source manifest, wiki index, log, and relevant pages. Check for contradictions, claims superseded by later sources, broken links, orphaned pages, important unrepresented concepts, weak cross-references, and unprocessed or partial sources.

Do not modify files unless repairs are explicitly requested. Report findings by severity with page references, then suggest the smallest useful repairs or research next steps. State when supporting material is insufficient for a confident conclusion.
