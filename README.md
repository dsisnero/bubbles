# Bubbles (Crystal Port)

This is a Crystal port of [charmbracelet/bubbles](https://github.com/charmbracelet/bubbles),
a collection of components for terminal user interface applications.

The original Go source code is available in the `vendor/` directory. This port
aims to provide equivalent functionality in Crystal while following Crystal
language idioms and conventions.

**Note:** This is a work in progress. Not all components have been ported yet.

## Components

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

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     bubbles:
       github: dsisnero/bubbles
   ```

2. Run `shards install`

## Usage

```crystal
require "bubbles"

# Use individual components as needed
spinner = Bubbles::Spinner.new
text_input = Bubbles::TextInput.new
```

See the `examples/` directory (when available) for complete usage examples.

## Development

```bash
make install    # Install dependencies
make format     # Check code formatting
make lint       # Run linter (ameba)
make test       # Run tests
```

## Porting Guidelines

This is a Crystal port of Go code. All logic should match the Go implementation
exactly, differing only in Crystal language idioms and standard library usage.

- The Go code in `vendor/` is the source of truth
- Port Go tests to Crystal specs to verify behavior
- Use Crystal's type system and idioms where appropriate
- Follow Crystal naming conventions (snake_case for methods, CamelCase for classes)

## Contributing

1. Fork it (<https://github.com/dsisnero/bubbles/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT (same as the original Go library)

## Acknowledgments

- [Charmbracelet](https://charm.sh/) for the original Go implementation
- The Bubble Tea ecosystem for inspiring terminal UI development
