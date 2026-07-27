# Architecture

Bubbles is a Crystal port of the Go Bubbles library, providing terminal UI
components for building interactive command-line applications.

## Project Structure

```text
.
├── src/bubbles/          # Crystal source code (ported from Go)
│   ├── textinput.cr      # Text input component
│   ├── textarea.cr       # Text area component
│   ├── list.cr           # List component
│   └── ...              # Other UI components
├── spec/                 # Crystal specs (ported from Go tests)
├── vendor/bubbles/       # Upstream Go source (submodule)
└── lib/                  # Crystal dependencies (shards)
```

## Data Flow

Components follow the Bubble Tea model pattern:

1. **Model initialization** - Create component with default configuration
2. **Update loop** - Handle messages (keyboard input, timer ticks, etc.)
3. **View rendering** - Convert model state to terminal output
4. **Integration** - Components compose within larger Bubble Tea applications

## Package/Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| `Bubbles::TextInput` | Single-line text input field |
| `Bubbles::TextArea` | Multi-line text input area |
| `Bubbles::List` | Interactive list with selection |
| `Bubbles::Spinner` | Animated progress indicator |
| `Bubbles::Progress` | Progress bar display |
| `Bubbles::Viewport` | Scrollable content viewport |
| `Bubbles::FilePicker` | File system navigation dialog |
| `Bubbles::Table` | Data table with columns, rows, and alignment |
| `Bubbles::Help` | Context-sensitive help display |
| `Bubbles::Cursor` | Terminal cursor manipulation |
| `Bubbles::Key` | Keyboard input handling and key binding management |
| `Bubbles::Paginator` | Content pagination controls |
| `Bubbles::Timer` | Countdown timer with configurable interval |
| `Bubbles::Stopwatch` | Count-up timer for elapsed time measurement |

<!-- TODO: Add diagrams if helpful -->
