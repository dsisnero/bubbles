<p align="center">
  <strong>A Crystal port of Charmbracelet's Bubbles TUI components library</strong><br>
  Terminal UI components for building interactive command-line applications
</p>

<p align="center">
  <a href="docs/architecture.md">Architecture</a> &middot;
  <a href="docs/development.md">Development</a> &middot;
  <a href="docs/coding-guidelines.md">Guidelines</a> &middot;
  <a href="docs/testing.md">Testing</a> &middot;
  <a href="docs/pr-workflow.md">PR Workflow</a> &middot;
  <a href="docs/porting-parity.md">Porting Parity</a> &middot;
  <a href="docs/upgrade_guide_v2.md">Upgrading</a>
</p>

---

Bubbles are self-contained, reusable UI components that float together to create
rich terminal interfaces.

---

## Quick Start

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     bubbles:
       github: dsisnero/bubbles
   ```

2. Run `shards install`

3. Use in your Crystal code:

    ```crystal
    require "bubbles"

    # Use individual components as needed
    spinner = Bubbles::Spinner.new
   text_input = Bubbles::TextInput.new
   ```

## Features

The bubbles library includes various UI components for terminal applications:

- **Spinner** - Animated spinners for indicating progress
- **Text Input** - Single-line text input fields
- **Text Area** - Multi-line text input areas
- **List** - Interactive lists with selection
- **Table** - Data tables with sorting and pagination
- **Viewport** - Scrollable viewport for content
- **Progress** - Progress bars for long-running operations
- **File Picker** - File and directory selection dialogs
- **Help** - Context-sensitive help displays
- **Cursor** - Terminal cursor manipulation utilities
- **Key** - Keyboard input handling and key mapping
- **Paginator** - Content pagination controls
- **Timer** - Time-based utilities
- **Stopwatch** - Timing utilities

**Note:** This is a work in progress. Not all components have been ported yet.

## Development

```bash
make install    # Install dependencies
make format     # Check code formatting
make lint       # Run linter (ameba)
make test       # Run tests
rumdl fmt docs/ *.md  # Format markdown documentation
```

See [Development Guide](docs/development.md) for full setup instructions.

## Documentation

| Document | Purpose |
|----------|---------|
| [Architecture](docs/architecture.md) | System design and data flow |
| [Development](docs/development.md) | Setup and daily workflow |
| [Coding Guidelines](docs/coding-guidelines.md) | Code style and conventions |
| [Testing](docs/testing.md) | Test commands and patterns |
| [PR Workflow](docs/pr-workflow.md) | Commits, PRs, and review process |
| [Porting Parity](docs/porting-parity.md) | Upstream source tracking |
| [Upgrading to v2](docs/upgrade_guide_v2.md) | Migration from Go Bubbles v1 to Crystal v2 |

## Porting Guidelines

This is a Crystal port of Go code. All logic should match the Go implementation
exactly, differing only in Crystal language idioms and standard library usage.

- The Go code in `vendor/bubbles/` is the source of truth
- Port Go tests to Crystal specs to verify behavior
- Use Crystal's type system and idioms where appropriate
- Follow Crystal naming conventions (snake_case for methods, CamelCase for
  classes)

## Contributing

1. Create an issue: `/forge-create-issue`
2. Implement: `/forge-implement-issue <number>`
3. Self-review: `/forge-reflect-pr`
4. Address feedback: `/forge-address-pr-feedback`
5. Update changelog: `/forge-update-changelog`

## License

MIT (same as the original Go library)

## Acknowledgments

- [Charmbracelet](https://charm.sh/) for the original Go implementation
- The Bubble Tea ecosystem for inspiring terminal UI development
