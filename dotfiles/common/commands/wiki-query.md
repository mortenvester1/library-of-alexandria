Query a wiki and synthesize an answer.

Arguments: `<wiki-name> <question>`

Example: `/wiki-query arcanum What are the differences between magic and technology?`

---

The wiki is at `~/git/library-of-alexandria/library/$ARGUMENTS` — parse the first word as the wiki name and the rest as the question.

1. Read `~/git/library-of-alexandria/library/<wiki-name>/AGENTS.md` for schema and conventions
2. Follow the Query operation defined there exactly
