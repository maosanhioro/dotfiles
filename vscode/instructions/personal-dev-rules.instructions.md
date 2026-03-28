# Personal Copilot Rules for Solo/Internal Tools

## Scope
- This file defines always-on personal development rules.
- Apply to coding, review, and refactoring tasks.

## Fact-Based Responses
- Do not fabricate APIs, files, commands, or package behavior.
- If uncertain, say what is unknown and what must be verified.
- Read relevant files before proposing concrete edits.
- Distinguish facts from assumptions.

## Git Workflow

### Commit message language and format
- Commit messages must be written in Japanese.
- Keep subject concise (about 50 chars).
- Recommended format:

```text
[type] 概要

必要なら詳細説明
```

### Allowed commit types
- `[feat]` new feature
- `[fix]` bug fix
- `[docs]` docs only
- `[refactor]` refactor without behavior change
- `[test]` test add/update
- `[chore]` maintenance

### Branch strategy
- `main`: production-ready only
- `develop`: integration branch for upcoming release
- `feature/<topic>`: branch from `develop`, merge back to `develop`
- `bugfix/<topic>`: branch from `develop`, merge back to `develop`
- `hotfix/<topic>`: branch from `main`, merge to `main` and `develop`
- `release/<version>`: prepare release, then merge to `main` and `develop`

### Pull request minimum rules
- Explain why, not only what changed.
- Ensure tests pass before merge.
- Keep PR scope small and focused.

## Coding Quality
- Prefer simple, readable code over clever code.
- Keep functions small and composable.
- Avoid unnecessary dependencies.
- Follow project formatter/linter settings when present.

## Testing
- Add tests for new behavior.
- Add regression tests for bug fixes.
- Run relevant tests after edits and report results.

## Security Baseline
- Never hardcode secrets.
- Validate and sanitize external input.
- Avoid logging sensitive values.

## Documentation
- Update README or inline docs for behavior changes.
- Document non-obvious decisions near the code.

## Priority with project rules
- If a project has `.github/copilot-instructions.md`, project-specific rules can override this default.
