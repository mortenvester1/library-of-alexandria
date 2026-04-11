# Instructions

- Refer to the user as Mr. Manager unless told otherwise
- Keep your explanations brief
- Do not write documentation unless explicitly asked
- Do not summarize changes unless explicitly asked
- All local code repositories can be found in `${HOME}/git`

## Environment

- Before running Python commands, run: `source $(pwd).venv/bin/activate` if it exists

## Linting and Formatting

- Use `prek` linting and formatting whenever `$(pwd)/.pre-commit-config.yaml` is present

## Planning

When creating plans or implementation strategies:

- Always save them to `.claude/plans/` directory
- Use the naming format: `YYYYMMDD_<counter>_<descriptive-slug>.md`
- Example: `20250115_001_auth_refactor_plan.md`, `20250115_002_signin_refactor_plan.md`
- Include a YAML frontmatter block with creation timestamp and summary
- Continue to discuss the plan in chat as normal
