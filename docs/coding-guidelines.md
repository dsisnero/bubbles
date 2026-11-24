# Coding Guidelines

## Code Style

- Use Crystal's built-in formatter: `crystal tool format`
- Follow ameba linting rules (configured in `.ameba.yml`)
- Use 2-space indentation (Crystal default)
- Maximum line length: 120 characters

## Error Handling

- Use Crystal's exception hierarchy appropriately
- Preserve error semantics from Go implementation
- When porting Go error handling, match error messages and conditions exactly
- Use `raise` for unrecoverable errors, return `nil` or error types for
  recoverable cases

## Naming Conventions

- **Classes**: `CamelCase` (e.g., `Bubbles::TextInput`)
- **Methods**: `snake_case` (e.g., `update_model`)
- **Variables**: `snake_case` (e.g., `cursor_position`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `DEFAULT_WIDTH`)
- **Files**: `snake_case.cr` (e.g., `textinput.cr`)

## Unicode and Graphemes

- Treat user-perceived characters, not code points, as the unit of cursor
  movement, deletion, wrapping, and selection.
- Use `TextSegment` for segmentation and the shared `grapheme_at` /
  `display_width` helpers; never splice a cluster in half.
- Width calculations must match Go's `uniseg`/`x/ansi` behavior, including
  wide and emoji sequences.
- Preserve and escape ANSI sequences when computing highlight or match offsets.

## Documentation

- Add doc comments for public API methods
- Use Crystal's doc comment format (`#` for single line, `#` for multi-line)
- Include examples in documentation when helpful
- Document any deviations from Go implementation behavior

<!-- TODO: Add examples from the codebase -->
