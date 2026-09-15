---
name: eli5
description: Explain things in plain English — one short description each, under a word cap, optionally as a list. Subject defaults to what the current conversation has been about; the user may instead supply anything (PRs, tickets, commits, files, errors, concepts). Trigger on "eli5", "ELI5", "explain like I'm five", "layman", "in layman's terms", "explain this in plain English", "summarize this simply", "what does this actually do".
model: claude-opus-5
effort: medium
---

# layman

Explain something in plain English: what it means or does for a person using or running the system, not how it works internally.

## Input

`$ARGUMENTS` is free-form natural language. Parse out:

- **Subject** — whatever the user names. Could be PR/ticket/commit references, file paths, error messages, a concept, or nothing at all. **If no subject is given, the subject is the current conversation** — the work just done, the findings just reported, the thing just built.
- **Items** — if the subject is plural (several PRs, several findings, several files), produce one description per item, in the order given. If it is one thing, produce one description.
- **Word cap** — e.g. `<20 words`, `in 10 words`, `max 15 words`. Default **20**. Applies to the description only, not any identifier prefix.
- **List format** — on only if the user asks for it ("as a list", "list format", "bullets"). Default **off**.

## Steps

1. Establish the subject. Prefer what is already in context — do not re-fetch or re-derive something you have already read this session. Fetch only what you genuinely lack, using the narrowest command (e.g. `gh pr view`, `git show --stat`, `sed -n`).
2. If the subject is ambiguous and the reading changes the answer materially, ask one targeted question. Otherwise proceed and state the assumption in one line.
3. Write one description per item, under the word cap. Rules:
   - Name the **effect**, not the mechanism. No kernel names, file paths, config keys, or internal subsystem names unless the term is the whole point.
   - Lead with a verb.
   - One clause, or two joined by a semicolon. No trailing period needed.
   - Never invent an effect the source does not support. If something is purely internal with no visible effect, say that plainly.

## Output format

Default (list off) — one line per item, no bullets, with a short identifier prefix only when there are several items to tell apart:

```
somerepo#113 — Stop reserving 32–64 GiB of GPU memory decode never uses; frees it for KV cache
somerepo#114 — Make enable_thinking=false actually work on GLM-5.3, so replies skip reasoning
```

A single item gets the bare description with no prefix.

List on:

```
- **somerepo#113** — Stop reserving 32–64 GiB of GPU memory decode never uses; frees it for KV cache
```

## Calibration

Good (effect): `Use a stable sorting kernel so identical requests stop giving different answers`

Bad (mechanism): `Wrap the kpool indexer top-k in aiter.top_k_per_row_prefill with stable=True and rebase column ids`

Nothing else — no preamble, no detail sections, no closing summary.
