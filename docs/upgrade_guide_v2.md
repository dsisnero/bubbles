# Upgrading to Bubbles v2 (Crystal Port)

This guide covers the changes when migrating from the Go Bubbles v1 to the Crystal port of Bubbles v2. Since this is a Crystal port, the changes are both about the v2 API changes and the language transition from Go to Crystal.

> **Note:** This Crystal port targets the Bubbles v2 API from `charm.land/bubbles/v2`. The upstream Go source is pinned in `vendor/bubbles/`.

---

## Table of Contents

1. [Import Paths](#1-import-paths)
2. [Global Patterns](#2-global-patterns)
3. [Per-Component Migration](#3-per-component-migration)
   - [Cursor](#cursor)
   - [Filepicker](#filepicker)
   - [Help](#help)
   - [List](#list)
   - [Paginator](#paginator)
   - [Progress](#progress)
   - [Spinner](#spinner)
   - [Stopwatch](#stopwatch)
   - [Table](#table)
   - [Textarea](#textarea)
   - [Textinput](#textinput)
   - [Timer](#timer)
   - [Viewport](#viewport)
4. [Light and Dark Styles](#4-light-and-dark-styles)
5. [Crystal-Specific Changes](#5-crystal-specific-changes)

---

## 1. Import Paths

In Crystal, imports work differently than Go. You require the entire `bubbles` module or specific components:

```crystal
# Before (Go)
import (
    "github.com/charmbracelet/bubbles/cursor"
    "github.com/charmbracelet/bubbles/help"
    "github.com/charmbracelet/bubbles/key"
)

# After (Crystal)
require "bubbles"
# or require specific components through the main module
```

All components are available under the `Bubbles` module namespace:

```crystal
# Access components
cursor = Bubbles::Cursor.new
help = Bubbles::Help.new
key = Bubbles::Key.new
```

> **Note:** The `runeutil` and `memoization` packages are internal and not directly accessible.

---

## 2. Global Patterns

These patterns repeat across multiple components in the Crystal port.

### 2a. `Tea::KeyMsg` → `Tea::KeyPressMsg`

Bubble Tea v2 renames `Tea::KeyMsg` to `Tea::KeyPressMsg`. Update your `update` methods:

```crystal
# Before (Go-style thinking)
case msg
when Tea::KeyMsg
  # handle key

# After (Crystal port)
case msg
when Tea::KeyPressMsg
  # handle key
```

### 2b. Width/Height Fields → Getter/Setter Methods

Many components replaced exported `width` and `height` fields with methods:

```crystal
# Before (Go-style fields)
model.width = 40
model.height = 20
puts model.width, model.height

# After (Crystal methods)
model.set_width(40)
model.set_height(20)
puts model.width, model.height
```

**Affected components:** `filepicker`, `help`, `progress`, `table`, `textinput`, `viewport`.

### 2c. `DefaultKeyMap` Variables → Class Methods

Global `DefaultKeyMap` variables are now class methods returning fresh values:

```crystal
# Before (Go-style variable)
km = Bubbles::TextInput::DefaultKeyMap
km.paste.set_enabled(false)

# After (Crystal class method)
km = Bubbles::TextInput.default_key_map
km.paste.set_enabled(false)
```

**Affected components:** `paginator`, `textarea`, `textinput`.

### 2d. Crystal Naming Conventions

Follow Crystal naming conventions:
- Methods: `snake_case` (e.g., `set_width`, `default_key_map`)
- Classes/Modules: `CamelCase` (e.g., `Bubbles::TextInput`)
- Constants: `SCREAMING_SNAKE_CASE` (e.g., `DEFAULT_WIDTH`)

### 2e. Removed `NewModel` Aliases

All `NewModel` aliases have been removed. Use `new` directly.

**Affected components:** `help`, `list`, `paginator`, `spinner`, `textinput`.

---

## 3. Per-Component Migration

### Cursor

| Go v1 | Crystal v2 |
|-------|------------|
| `model.Blink` | `model.blinked?` |
| `model.BlinkCmd()` | `model.blink` |

```crystal
# Crystal example
cursor = Bubbles::Cursor.new
if cursor.blinked?
  # cursor is blinking
end

# Start blinking
model, cmd = cursor.blink
```

### Filepicker

| Go v1 | Crystal v2 |
|-------|------------|
| `DefaultStylesWithRenderer(r)` | `default_styles` |
| `model.Height = 10` | `model.set_height(10)` |
| `_ = model.Height` | `_ = model.height` |

Boolean properties use `property?` syntax in Crystal:
```crystal
fp = Bubbles::FilePicker.new
fp.show_permissions? = true  # Setter
if fp.show_permissions?      # Getter
  # show permissions
end
```

### Help

| Go v1 | Crystal v2 |
|-------|------------|
| `model.Width = 80` | `model.set_width(80)` |
| `_ = model.Width` | `_ = model.width` |
| `NewModel()` | `new` |

New methods:
- `default_styles(is_dark : Bool) : Styles`
- `default_dark_styles : Styles`
- `default_light_styles : Styles`

```crystal
# Apply styles explicitly
h = Bubbles::Help.new
h.styles = Bubbles::Help.default_styles(is_dark)
```

### List

| Go v1 | Crystal v2 |
|-------|------------|
| `DefaultStyles()` | `default_styles(is_dark)` |
| `NewDefaultItemStyles()` | `new_default_item_styles(is_dark)` |
| `styles.FilterPrompt` | `styles.filter.focused.prompt` / `styles.filter.blurred.prompt` |
| `styles.FilterCursor` | `styles.filter.cursor` |
| `NewModel(...)` | `new(...)` |

The `Styles.filter_prompt` and `Styles.filter_cursor` fields have been consolidated into `Styles.filter`, which is a `Bubbles::TextInput::Styles` struct.

### Paginator

| Go v1 | Crystal v2 |
|-------|------------|
| `DefaultKeyMap` (var) | `default_key_map` (method) |
| `model.UsePgUpPgDownKeys` | Removed — customize `key_map` directly |
| `model.UseLeftRightKeys` | Removed — customize `key_map` directly |
| `model.UseUpDownKeys` | Removed — customize `key_map` directly |
| `model.UseHLKeys` | Removed — customize `key_map` directly |
| `model.UseJKKeys` | Removed — customize `key_map` directly |
| `NewModel(...)` | `new(...)` |

### Progress

This component has extensive changes in the Crystal port.

#### Width
```crystal
# Before (Go-style thinking)
p.width = 40
puts p.width

# After (Crystal)
p.set_width(40)
puts p.width
```

#### Colors
Color handling differs in Crystal:

```crystal
# Crystal uses Colorful shard for colors
require "colorful"

# Set colors
p.full_color = Colorful::Color.new("#FF0000")
p.empty_color = Colorful::Color.new("#333333")
```

#### Options Pattern
```crystal
# Crystal uses initializer parameters or builder pattern
p = Bubbles::Progress.new(
  width: 40,
  full_color: Colorful::Color.new("#5A56E0"),
  empty_color: Colorful::Color.new("#EE6FF8")
)

# Or use with methods if available
p = Bubbles::Progress.new
  .with_colors(Colorful::Color.new("#5A56E0"), Colorful::Color.new("#EE6FF8"))
  .with_scaled(true)
```

### Spinner

| Go v1 | Crystal v2 |
|-------|------------|
| `NewModel()` | `new` |
| `spinner.Tick()` (package func) | `model.tick` (method) |

```crystal
spinner = Bubbles::Spinner.new
model, cmd = spinner.tick
```

### Stopwatch

```crystal
# Before (Go-style thinking)
sw = Bubbles::Stopwatch.new_with_interval(500.milliseconds)

# After (Crystal)
sw = Bubbles::Stopwatch.new(interval: 500.milliseconds)
```

### Table

| Go v1 | Crystal v2 |
|-------|------------|
| `model.viewport.Width` | `model.width` / `model.set_width(w)` |
| `model.viewport.Height` | `model.height` / `model.set_height(h)` |

The table already had `set_width`/`set_height`/`width`/`height` methods.

### Textarea

#### KeyMap
```crystal
# Crystal uses class methods
km = Bubbles::TextArea.default_key_map
```

#### Styles
The styling system follows Crystal patterns:

```crystal
ta = Bubbles::TextArea.new
# Styles are nested under a styles struct
ta.styles.focused.base = Lipgloss::Style.new.border(Lipgloss::Border::Rounded)
ta.styles.blurred.base = Lipgloss::Style.new.border(Lipgloss::Border::Hidden)
```

#### Cursor
```crystal
# Crystal uses Tea::Cursor directly
ta.cursor                    # Returns Tea::Cursor
ta.set_cursor_column(col)    # Set cursor column
ta.virtual_cursor = true     # Use virtual cursor mode
```

### Textinput

#### KeyMap
```crystal
km = Bubbles::TextInput.default_key_map
```

#### Width
```crystal
ti.set_width(40)
```

#### Styles
Individual style fields are in a `Styles` struct:

```crystal
s = Bubbles::TextInput.default_styles(is_dark)
s.focused.prompt = Lipgloss::Style.new.foreground(Lipgloss::Color.new("63"))
s.focused.text = Lipgloss::Style.new
s.focused.placeholder = Lipgloss::Style.new.foreground(Lipgloss::Color.new("240"))
s.focused.suggestion = Lipgloss::Style.new.foreground(Lipgloss::Color.new("240"))
ti.styles = s
```

### Timer

```crystal
# Before (Go-style thinking)
t = Bubbles::Timer.new_with_interval(30.seconds, 100.milliseconds)

# After (Crystal)
t = Bubbles::Timer.new(30.seconds, interval: 100.milliseconds)
```

### Viewport

#### Constructor
```crystal
# Before (Go-style)
vp = Bubbles::Viewport.new(80, 24)

# After (Crystal)
vp = Bubbles::Viewport.new(width: 80, height: 24)
# or
vp = Bubbles::Viewport.new
vp.set_width(80)
vp.set_height(24)
```

#### Width, Height, YOffset
```crystal
vp.set_width(80)
vp.set_height(24)
vp.set_y_offset(5)
puts vp.width, vp.height, vp.y_offset
```

#### New Features (Crystal implementation)
- **Soft wrapping:** `vp.soft_wrap = true`
- **Left gutter** for line numbers (Crystal lambda syntax):
  ```crystal
  vp.left_gutter_func = ->(info : Bubbles::Viewport::GutterContext) do
    if info.soft
      "     │ "
    elsif info.index >= info.total_lines
      "   ~ │ "
    else
      sprintf("%4d │ ", info.index + 1)
    end
  end
  ```
- **Highlighting:**
  ```crystal
  vp.set_highlights(regex.find_all(content).map(&.begin_end))
  vp.highlight_next
  vp.highlight_previous
  vp.clear_highlights
  ```

---

## 4. Light and Dark Styles

The Crystal port requires explicit light/dark style selection.

### Query via Bubble Tea
```crystal
def init : Tea::Cmd
  Tea.request_background_color
end

def update(msg : Tea::Msg) : {Model, Tea::Cmd?}
  case msg
  when Tea::BackgroundColorMsg
    is_dark = msg.dark?
    @help.styles = Bubbles::Help.default_styles(is_dark)
    @list.styles = Bubbles::List.default_styles(is_dark)
    # ... apply to other components
  end
  {self, nil}
end
```

### Manual Selection
```crystal
h.styles = Bubbles::Help.default_dark_styles   # force dark
h.styles = Bubbles::Help.default_light_styles  # force light
```

---

## 5. Crystal-Specific Changes

### Type System
Crystal has a strong static type system. Pay attention to types:

```crystal
# Go returns (Model, tea.Cmd)
# Crystal returns {Model, Tea::Cmd?}
def update(msg : Tea::Msg) : {Bubbles::TextInput::Model, Tea::Cmd?}
  # ...
  {model, cmd}
end
```

### Error Handling
Crystal uses exceptions instead of error returns:

```crystal
# Go style
err := validate(input)
if err != nil {
    return err
}

# Crystal style
validate!(input)  # raises exception on error
```

### Concurrency
Crystal uses fibers and channels instead of goroutines:

```crystal
# Go
go func() {
    // concurrent work
}()

# Crystal
spawn do
  # concurrent work
end
```

### Time Handling
Crystal has built-in time types:

```crystal
# Time intervals
interval = 500.milliseconds
timeout = 30.seconds
duration = 2.minutes + 30.seconds
```

### Collections
Crystal collections have different APIs:

```crystal
# Arrays
items = ["a", "b", "c"]
items.each do |item|
  puts item
end

# Hashes (maps)
config = {"width" => 80, "height" => 24}
config["width"] = 100

# Ranges
(1..10).each do |i|
  puts i
end
```

### Testing
Crystal uses `spec` for testing:

```crystal
require "spec"

describe Bubbles::TextInput do
  it "handles character input" do
    ti = Bubbles::TextInput.new
    # test logic
  end
end
```

---

## Summary

The Crystal port of Bubbles v2 maintains the same API concepts as the Go version but adapts them to Crystal idioms:

1. **Crystal naming conventions** (snake_case methods, CamelCase classes)
2. **Crystal type system** (strong static typing, generic support)
3. **Crystal error handling** (exceptions instead of error returns)
4. **Crystal collection APIs** (Enumerable, Array, Hash)
5. **Crystal time handling** (Time, Time::Span, number methods like `.seconds`)

When porting Go code to use this Crystal library:
1. Update import/require statements
2. Follow Crystal naming conventions
3. Adapt to Crystal's type system
4. Use Crystal's error handling patterns
5. Update test code to use Crystal's spec framework

Refer to the `spec/` directory for examples of how to use each component in Crystal.