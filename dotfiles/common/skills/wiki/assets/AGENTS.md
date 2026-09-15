# {{WIKI_TITLE}}

This wiki is an LLM-maintained knowledge base about {{TOPIC}}.

## Architecture

- `raw/` contains immutable source material. Never edit, rename, or delete files there.
- `raw/index.md` is the source manifest. Record each source's filename, type, processing status (`pending`, `partial`, or `complete`), corresponding wiki page, and unresolved gaps.
- `wiki/` contains LLM-maintained derived material: source summaries, entity pages, concept pages, comparisons, and synthesis.
- `wiki/index.md` is the content catalog. List every page with a link and concise summary, organized by category.
- `wiki/log.md` is append-only. Each entry starts with `## [YYYY-MM-DD] <operation> | <title>`.
- `CLAUDE.md` is a symlink to this file.

## Ingest

1. Read the source without modifying it.
2. Create or update its source page and the relevant concept, entity, and synthesis pages.
3. Update `raw/index.md`, `wiki/index.md`, and append an ingest entry to `wiki/log.md`.
4. Preserve prior content unless the new source materially supersedes it; identify superseded claims.

## Query

1. Read `wiki/index.md`, then the pages relevant to the question.
2. Answer from the wiki and cite the supporting page paths.
3. Distinguish sourced statements from inferences.
4. Create a new page only when the user asks to file the result.

## Lint

Inspect the source manifest, index, log, and relevant pages for contradictions, stale claims, broken links, orphaned pages, missing concepts, weak cross-references, and incomplete source processing. Report findings and proposed repairs; do not modify files unless asked.
