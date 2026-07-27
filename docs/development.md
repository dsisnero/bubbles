# Development

## Prerequisites

- **Crystal** >= 1.19.1
- **Git** with submodule support
- **rumdl** (for markdown formatting): Install via Rust/Cargo:
  `cargo install rumdl`

## Setup

1. Clone the repository with submodules:

   ```bash
   git clone --recurse-submodules https://github.com/dsisnero/bubbles.git
   cd bubbles
   ```

2. Install Crystal dependencies:

   ```bash
   make install
   ```

3. Verify upstream Go source is available:

   ```bash
   ls vendor/bubbles/
   ```

## Daily Workflow

1. **Start development session**:

   ```bash
   make install  # Ensure dependencies are up to date
   ```

2. **Run tests while developing**:

   ```bash
   make test
   ```

3. **Check code quality before committing**:

   ```bash
   make format
   make lint
   rumdl fmt docs/ *.md  # Format markdown documentation
   ```

4. **Clean up temporary files**:

   ```bash
   make clean
   ```

## Available Commands

| Command | Purpose |
|---------|---------|
| `make install` | Install Crystal dependencies |
| `make update` | Update dependencies to latest versions |
| `make format` | Check Crystal code formatting |
| `make lint` | Run ameba linter (fixes then verifies) |
| `make test` | Run all Crystal specs |
| `make clean` | Remove temporary files from ./temp directory |

## Porting Guidelines

This is a Crystal port of Go code. All logic should match the Go implementation
exactly, differing only in Crystal language idioms and standard library usage.

- The Go code in `vendor/bubbles/` is the source of truth
- Port Go tests to Crystal specs to verify behavior
- Use Crystal's type system and idioms where appropriate
- Follow Crystal naming conventions (snake_case for methods, CamelCase for
  classes)

## Contributing via Forge

1. Create an issue: `/forge-create-issue`
2. Implement: `/forge-implement-issue <number>`
3. Self-review: `/forge-reflect-pr`
4. Address feedback: `/forge-address-pr-feedback`
5. Update changelog: `/forge-update-changelog`
