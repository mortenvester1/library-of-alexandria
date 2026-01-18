# AGENTS.md

- _project-name_: entrance
- _source code location_: src/entrance

## Communication Guidelines

- **Be brief and concise** in responses
- **Do NOT write documentation** (README.md, .md files, etc.) unless explicitly asked
- Focus on code implementation, not documentation

## Commands

1. **Activate Virtual Environment**

   ```bash
   source .venv/bin/activate
   ```

2. **Format Code**
   Run Ruff formatter on the `src/` directory:

   ```bash
   uvx ruff format src/
   ```

3. **Lint**
   Run Ruff linter on the `src/` directory:

   ```bash
   uvx ruff check src/
   ```

4. **Run Tests**
   Execute unit tests in the `tests/` folder run:

   ```bash
   uv run pytest
   ```

   Ensure tests are written in a dedicated `tests/` directory.

5. **Sync Dependencies**
   After updating dependencies in `pyproject.toml`, run:
   ```bash
   uv sync --extra dev
   ```

## Development Guide

- Do **NOT** write any external documentation (markdown files, README updates, guides, etc.) unless explicitly asked
- Do **NOT** create new .md files for documentation purposes
- Keep responses **brief and to the point**
- Do write brief doc-strings for functions
- Do **NOT** write doc-strings for modules
- Write unit tests using `pytest` with `@pytest.mark.parametrize` to test multiple sets of inputs
