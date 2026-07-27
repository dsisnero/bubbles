<p align="center">
  <strong>A Crystal port of Charmbracelet's Bubbles TUI components library</strong><br>
  Terminal UI components for building interactive command-line applications with <a href="https://github.com/dsisnero/bubbletea">Bubble Tea</a>
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

Self-contained, reusable UI components that compose together to create rich
terminal interfaces.

---

## Quick Start

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     bubbles:
       github: dsisnero/bubbles
   ```

2. Run `shards install`

3. Use in your Crystal + Bubble Tea application:

    ```crystal
    require "bubbles"

    spinner = Bubbles::Spinner.new
    text_input = Bubbles::TextInput.new
    text_area = Bubbles::TextArea.new
    ```

## Components

### Spinner

Animated spinner for indicating that an operation is happening. Several built-in
styles are available, and you can define custom frame sequences.

```crystal
s = Bubbles::Spinner.new
s.spinner = Bubbles::Spinner::Dot  # Choose a style
```

**Spinner types:** `Line`, `Dot`, `MiniDot`, `Jump`, `Pulse`, `Points`, `Globe`,
`Moon`, `Monkey`, `Meter`, `Hamburger`, `Ellipsis`

### Text Input

Single-line text input field, akin to `<input type="text">` in HTML. Supports
unicode, pasting, in-place scrolling when the value exceeds the width, and many
customization options.

```crystal
ti = Bubbles::TextInput.new
ti.set_width(40)
ti.placeholder = "Enter text..."
ti.prompt = "> "
km = Bubbles::TextInput.default_key_map
```

### Text Area

Multi-line text input area, akin to `<textarea />` in HTML. Supports unicode,
pasting, vertical scrolling, dynamic height, and full customization.

```crystal
ta = Bubbles::TextArea.new
ta.set_width(60)
ta.set_height(10)
ta.prompt = "> "
ta.dynamic_height = true
ta.min_height = 3
ta.max_height = 20
```

### Table

Display and navigate tabular data (columns and rows). Supports vertical
scrolling, column alignment, and customizable borders and styles.

```crystal
columns = [
  Bubbles::Table::Column.new(title: "Name", width: 20),
  Bubbles::Table::Column.new(title: "Population", width: 15),
]
rows = [
  Bubbles::Table::Row.new(["China", "1.4B"]),
  Bubbles::Table::Row.new(["India", "1.4B"]),
]
t = Bubbles::Table.new
t.set_columns(columns)
t.set_rows(rows)
t.set_width(40)
t.set_height(10)
```

### Progress

Progress bar with optional spring animation via Harmonica. Supports solid and
gradient fills, customizable characters, and percentage display.

```crystal
p = Bubbles::Progress.new(
  width: 40,
  full_color: Lipgloss.color("#5A56E0"),
)
p.view_as(0.75)  # Render at 75%
```

### Viewport

Scrollable viewport for vertically scrolling content. Includes standard pager
keybindings and mouse wheel support. A high performance mode is available.

```crystal
vp = Bubbles::Viewport.new(width: 80, height: 24)
vp.set_content("long content...")
vp.soft_wrap = true
vp.key_map = Bubbles::Viewport.default_key_map
```

### List

Batteries-included component for browsing a set of items. Features pagination,
fuzzy filtering, auto-generated help, an activity spinner, and status messages.

```crystal
items = [
  Bubbles::List::DefaultItem.new(title: "Item 1", description: "First item"),
  Bubbles::List::DefaultItem.new(title: "Item 2", description: "Second item"),
]
delegate = Bubbles::List.new_default_delegate
l = Bubbles::List.new(items, delegate, width: 40, height: 20)
```

### File Picker

Navigate the file system to pick files or directories. Supports filtering by
file extension, showing hidden files, and displaying permissions.

```crystal
fp = Bubbles::FilePicker.new
fp.set_height(20)
fp.show_hidden = true
fp.allowed_extensions = [".cr", ".md"]
```

### Help

Auto-generated help view from your keybindings. Supports single-line and
multi-line modes, with graceful truncation when the terminal is too narrow.

```crystal
h = Bubbles::Help.new
h.styles = Bubbles::Help.default_dark_styles

# In your Bubble Tea update:
# h.view(key_map)  # Renders help from your key bindings
```

### Paginator

Handles pagination logic and optionally draws a pagination UI. Supports
dot-style and numeric page indicators.

```crystal
p = Bubbles::Paginator.new
p.set_width(20)
p.type = Bubbles::Paginator::Dots
p.total_pages = 5
p.page = 2
p.view  # Renders "● ○ ○ ○ ○"
```

### Timer

Countdown timer. The update frequency and output format are customizable.

```crystal
t = Bubbles::Timer.new(30.seconds, interval: 100.milliseconds)
# Sends TickMsg on each interval, TimeoutMsg when done
```

### Stopwatch

Count-up timer. The update frequency and output format are customizable.

```crystal
sw = Bubbles::Stopwatch.new(interval: 100.milliseconds)
# Sends TickMsg on each interval
```

### Cursor

Terminal cursor manipulation. Controls cursor style, blink behavior, and
position.

```crystal
c = Bubbles::Cursor.new
c.style = Bubbles::Cursor::CursorBlink  # Blinking cursor
```

### Key

Non-visual component for managing keybindings. Useful for custom key remapping
and generating help views.

```crystal
km = Bubbles::Key::Binding.new
Bubbles::Key.new_binding(
  Bubbles::Key.with_keys("k", "up"),
  Bubbles::Key.with_help("↑/k", "move up"),
)
```

## Documentation

| Document | Purpose |
|----------|---------|
| [Architecture](docs/architecture.md) | System design and data flow |
| [Development](docs/development.md) | Setup and daily workflow (including porting guide) |
| [Coding Guidelines](docs/coding-guidelines.md) | Code style and conventions |
| [Testing](docs/testing.md) | Test commands and patterns |
| [PR Workflow](docs/pr-workflow.md) | Commits, PRs, and review process |
| [Porting Parity](docs/porting-parity.md) | Upstream source tracking |
| [Upgrading to v2](docs/upgrade_guide_v2.md) | Migration from Go Bubbles v1 to Crystal v2 |

## Contributing

See [Development Guide](docs/development.md) for setup and porting workflow.

## License

MIT (same as the original Go library)

## Acknowledgments

- [Charmbracelet](https://charm.sh/) for the original Go implementation
- The Bubble Tea ecosystem for inspiring terminal UI development
