---
name: improve-agents-md
description: improve an AGENTS.md (or CLAUDE.md) file using <important if> blocks and aggressive trimming to improve instruction adherence
---

When the user provides an agent instruction file — `AGENTS.md`, `CLAUDE.md`, or whatever the harness reads — or asks you to improve one, rewrite it following the principles and structure below.

## Core Problem

Agent instruction files are injected as ambient context on every task, alongside the harness's own system prompt and tool definitions. Most of that file is irrelevant to any given task, and irrelevance is contagious: the more content that does not apply, the more likely the agent is to skim past all of it — including the parts that matter.

Some harnesses make this explicit. Claude Code, for example, injects the file with a note that "this context may or may not be relevant to your tasks." Others simply concatenate it. Either way the failure mode is the same.

## Solution: `<important if="condition">` Blocks

Wrap conditionally-relevant sections in `<important if="condition">` XML tags. This gives the model an explicit relevance signal per section: the whole file is still visible, but each block carries the trigger that makes it apply. Adherence varies by model and harness, so treat it as a way to structure instructions, not a guarantee.

It is a prompting technique, not a harness feature — nothing parses these tags. Do not tell the user the runtime enforces them.

## Principles

### 1. Foundational context stays bare, domain guidance gets wrapped

Not everything should be in an `<important if>` block. Context relevant to virtually every task — project identity, project map, tech stack — should be left as plain markdown at the top of the file. This is onboarding context the agent always needs.

Domain-specific guidance that only matters for certain tasks — testing patterns, API conventions, state management, i18n — gets wrapped in `<important if>` blocks with targeted conditions.

The rule of thumb: if it's relevant to 90%+ of tasks, leave it bare. If it's relevant to a specific kind of work, wrap it.

### 2. Conditions must be specific and targeted

Bad — overly broad conditions that match everything:

```
<important if="you are writing or modifying any code">
- Import from the package root, not submodules
- Use Pydantic models for boundaries
- Name test files test_*.py
</important>
```

Good — each rule has its own narrow trigger:

```
<important if="you are adding or modifying imports">
- Import from `myproj.api`, never from `myproj.api._internal`
- Keep imports at module top; inline only for genuinely expensive modules
</important>

<important if="you are defining a function or method signature that crosses a package boundary">
- Validate inputs with a Pydantic model rather than a dict
</important>

<important if="you are adding a new test file">
- Name it `test_<module>.py` next to the code under `tests/`
</important>
```

### 3. Keep it short, use progressive disclosure sparingly

Do not shard into separate files that require the agent to make tool calls to discover, unless the extra context is incredibly verbose or complex.

The whole point of `<important if>` blocks is that everything is inline but conditionally weighted — the agent sees it all but only attends to what matches.

Prefer to keep the file concise.

### 4. Less is more

- Every instruction competes with every other one for adherence. The file should be as lean as possible.
- Cut any instruction that a linter, formatter, or pre-commit hook can enforce.
- Cut any instruction the agent can discover from existing code patterns. LLMs are in-context learners — if your codebase consistently uses a pattern, the agent will follow it after a few searches.
- Cut code snippets. They go stale and bloat the file. Use file path references instead (e.g., "see `src/myproj/clients/base.py` for the pattern").

### 5. Keep all commands

Do not drop commands from the original file. The commands table is foundational reference — the agent needs to know what's available even if some commands are used less frequently.

### 6. One file, pointers for the rest

`AGENTS.md` is the cross-agent convention; keep the real content there. Where a harness insists on its own filename (`CLAUDE.md`, and similar), make that file a one-line pointer or import rather than a second copy — duplicated instruction files drift apart and then contradict each other.

If the harness supports imports (Claude Code reads `@AGENTS.md` in `CLAUDE.md`), use that. Otherwise a symlink, or a single line naming the real file.

## Output Structure

When rewriting, produce this structure:

```
# AGENTS.md

[one-line project identity — what it is, what it's built with]

## Project map
[directory listing with brief descriptions]

<important if="you need to run commands to build, test, lint, or generate code">
[commands table — all commands from the original]
</important>

<important if="<specific trigger for rule 1>">
[rule 1]
</important>

<important if="<specific trigger for rule 2>">
[rule 2]
</important>

... more rules, each with their own block ...

<important if="<specific trigger for domain area 1>">

[guidance]

</important>

... more domain sections ...
```

## How to Apply

When given an existing instruction file to improve:

1. **Identify the project identity** — extract a single sentence describing what this is. Leave it bare at the top.
2. **Extract the directory map** — keep it bare (no `<important if>` wrapper). This is foundational context.
3. **Extract the tech stack** — if present, keep it bare near the top. Condense to one or two lines.
4. **Extract commands** — keep ALL commands from the original. Wrap in a single `<important if>` block.
5. **Break apart rules** — split any list of rules into individual `<important if>` blocks with specific conditions. You can group rules, but never group unrelated rules under one broad condition.
6. **Wrap domain sections** — testing, API patterns, data models, background jobs, deployment, etc. each get their own block with a condition describing when that knowledge matters.
7. **Delete linter territory** — remove style guidelines, formatting rules, and anything enforceable by tooling. Suggest replacing with pre-push or pre-commit hooks.
8. **Delete code snippets** — replace with file path references.
9. **Delete vague instructions** — remove anything like "leverage the X agent" or "follow best practices" that isn't concrete and actionable.
10. **Consolidate duplicates** — if the repo has both `AGENTS.md` and `CLAUDE.md` (or other per-harness files) with overlapping content, merge into `AGENTS.md` and reduce the others to pointers.

## Example

Input:

```markdown
# AGENTS.md

This is a FastAPI service with a Celery worker, managed with uv.

## Commands

| Command                                           | Description               |
| ------------------------------------------------- | ------------------------- |
| `uv sync`                                         | Install dependencies      |
| `uv run pytest`                                   | Run all tests             |
| `uv run ruff check`                               | Lint                      |
| `uv run ruff format`                              | Format                    |
| `uv run mypy src`                                 | Type check                |
| `uv run alembic upgrade head`                     | Apply database migrations |
| `uv run alembic revision --autogenerate -m "..."` | Create a migration        |
| `uv run fastapi dev src/myproj/api/app.py`        | Start the dev server      |
| `uv run celery -A myproj.worker worker`           | Start the worker          |

## Project Structure

- `src/myproj/api/` - FastAPI routes and dependencies
- `src/myproj/worker/` - Celery tasks
- `src/myproj/db/` - SQLAlchemy models and Alembic migrations
- `src/myproj/clients/` - outbound HTTP clients
- `tests/` - pytest suite

## Coding Standards

- Use snake_case for functions and variables, PascalCase for classes
- Prefer f-strings over `.format()` and `%`
- Always use type hints on public functions
- Use `pathlib.Path`, not `os.path`
- Line length is 120
- Sort imports with isort ordering
- Write Google-style docstrings on all public functions
- Prefer list comprehensions over `map`/`filter`

## API Development

- All routes go in `src/myproj/api/routes/`
- Request and response bodies are Pydantic models
- Database access goes through a repository in `src/myproj/db/repositories/`
- Errors return RFC 7807 problem details via the handler in `api/errors.py`
- Auth is a FastAPI dependency, `require_user`

## Testing

- pytest with `pytest-asyncio` in strict mode
- Fixtures live in `tests/conftest.py`; factories in `tests/factories/`
- Use the `client` fixture for API tests, not a raw `TestClient`
- Database tests run against a transactional fixture that rolls back

## Background Work

- Every Celery task must be idempotent and take only JSON-serializable args
- Long tasks report progress through `task.update_state`
- Never call a task synchronously from a request handler
```

Output:

```markdown
# AGENTS.md

FastAPI service plus a Celery worker, managed with uv.

## Project map

- `src/myproj/api/` - FastAPI routes and dependencies
- `src/myproj/worker/` - Celery tasks
- `src/myproj/db/` - SQLAlchemy models and Alembic migrations
- `src/myproj/clients/` - outbound HTTP clients
- `tests/` - pytest suite

<important if="you need to run commands to install, test, lint, type check, migrate, or start a service">

Run everything through `uv` from the repo root.

| Command                                           | What it does                            |
| ------------------------------------------------- | --------------------------------------- |
| `uv sync`                                         | Install dependencies                    |
| `uv run pytest`                                   | Run all tests                           |
| `uv run ruff check`                               | Lint                                    |
| `uv run ruff format`                              | Format                                  |
| `uv run mypy src`                                 | Type check                              |
| `uv run alembic upgrade head`                     | Apply database migrations               |
| `uv run alembic revision --autogenerate -m "..."` | Create a migration after a model change |
| `uv run fastapi dev src/myproj/api/app.py`        | Start the dev server                    |
| `uv run celery -A myproj.worker worker`           | Start the worker                        |

</important>

<important if="you are adding or modifying API routes">

- All routes go in `src/myproj/api/routes/`
- Request and response bodies are Pydantic models
- Database access goes through a repository in `src/myproj/db/repositories/`
- Errors return RFC 7807 problem details via the handler in `api/errors.py`
- Auth is a FastAPI dependency, `require_user`
</important>

<important if="you are writing or modifying tests">

- pytest with `pytest-asyncio` in strict mode
- Fixtures live in `tests/conftest.py`; factories in `tests/factories/`
- Use the `client` fixture for API tests, not a raw `TestClient`
- Database tests run against a transactional fixture that rolls back
</important>

<important if="you are writing or modifying a Celery task">

- Every task must be idempotent and take only JSON-serializable args
- Long tasks report progress through `task.update_state`
- Never call a task synchronously from a request handler
</important>

<important if="you are changing a SQLAlchemy model">

- Generate a migration with `uv run alembic revision --autogenerate` and read it before committing — autogenerate misses server defaults and index renames

</important>
```

What was removed and why:

- snake_case/PascalCase, f-strings, `pathlib`, line length, import sorting, docstrings, comprehensions — ruff and the formatter enforce these, or they are obvious from the existing code
- "Always use type hints on public functions" — `mypy src` is in the commands table and enforces it
- Coding Standards as a grouped section — the survivors were split by trigger, the rest deleted

What was NOT removed:

- All commands kept, including the ones used rarely
- Project map left bare (foundational context, relevant to every task)

What was added:

- A migration-review block. The original had the commands but never said autogenerate output needs reading — that is exactly the non-obvious, non-lintable knowledge an agent file should carry
