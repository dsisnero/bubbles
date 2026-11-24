# Development

## Prerequisites

- **Crystal** >= 1.19.1
- **Git** with submodule support
- Upstream Go source pinned at Bubbles v2.2.2 (`vendor/bubbles` @ `0c1a491`)

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
   make install
   ```

2. **Run tests while developing**:

   ```bash
   make test
   ```

3. **Check code quality before committing**:

   ```bash
   make format
   make lint
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

## Quality Gates

Before committing, run all checks:

```bash
crystal tool format --check
ameba
crystal spec
rumdl fmt docs/ *.md
```

Parity artifacts are refreshed only on an intentional upstream bump. Use the
installed `cross-language-crystal-parity` skill scripts; the copies under
`scripts/` are historical. See
[plans/vendor-v2.2.2.md](../plans/vendor-v2.2.2.md) for the last refresh.

## Example GIFs

The README component GIFs live in `docs/assets/` and are recorded from
[dsisnero/bubbles-examples](https://github.com/dsisnero/bubbles-examples) with
VHS. Regenerate them with `make gifs` in that repository, then copy `gifs/*.gif`
into `docs/assets/`. See [docs/assets/README.md](assets/README.md) for the
mapping and requirements.

## Porting Guidance

Porting guidance has moved to [plans/development.md](../plans/development.md).
