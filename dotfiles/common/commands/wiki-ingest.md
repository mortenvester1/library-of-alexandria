Ingest a new source into a wiki.

Arguments: `<wiki-name> <source-filename>`

Example: `/wiki-ingest arcanum manual.md`

---

The wiki is at `~/git/library-of-alexandria/library/$ARGUMENTS` — parse the first word as the wiki name and the rest as the source filename.

1. Read `~/git/library-of-alexandria/library/<wiki-name>/AGENTS.md` for schema and conventions
2. Follow the Ingest operation defined there exactly
