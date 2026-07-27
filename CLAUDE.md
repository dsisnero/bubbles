# Bubbles

A Crystal port of Charmbracelet's Bubbles TUI components library.

## Commands

```bash
make install    # Install dependencies
make update     # Update dependencies
make format     # Check code formatting
make lint       # Run linter (ameba --fix then ameba)
make test       # Run tests
make clean      # Clean temporary files
```

## Documentation

| Document | Purpose |
|----------|---------|
| [Architecture](docs/architecture.md) | System design, data flow, package responsibilities |
| [Development](docs/development.md) | Prerequisites, setup, daily workflow |
| [Coding Guidelines](docs/coding-guidelines.md) | Code style, error handling, naming conventions |
| [Testing](docs/testing.md) | Test commands, conventions, patterns |
| [PR Workflow](docs/pr-workflow.md) | Commits, PRs, branch naming, review process |
| [Porting Parity](docs/porting-parity.md) | Upstream source tracking and parity verification |

## Core Principles

1. Upstream Go code is the source of truth
2. Use Crystal idioms without changing semantics
3. Port all Go code and tests
4. Verify behavior parity with Go
5. Never simplify, always port correctly

## Commits

Format: `<type>(<scope>): <description>`

Types: feat, fix, docs, refactor, test, chore, perf

Examples:

- `feat(textinput): add placeholder support`
- `fix(list): handle empty list edge case`
- `test(spinner): port Go spinner tests`

## Crystal Code Gates

```bash
crystal tool format src spec
ameba --fix
ameba
crystal spec
rumdl fmt docs/ *.md
```

## External Dependencies

- **Go source**: `vendor/bubbles/` (pinned at upstream commit)
- **Bubble Tea**: Crystal port of terminal UI framework
- **Golden/Teatest**: Testing utilities for terminal output verification

## Debugging

When something breaks:

1. Check Go source in `vendor/bubbles/` for reference implementation
2. Verify test parity with Go tests
3. Run `make lint` and `make test` to identify issues
4. Check `./temp` directory for test artifacts

## Conventions

- Follow Crystal naming: snake_case for methods/variables, CamelCase for classes
- Use `./temp` directory for temporary files during development
- Never commit temporary files (already in `.gitignore`)
- Port Go tests exactly, maintaining same assertions and edge cases
- Mark missing functionality as `pending` in specs until ported
