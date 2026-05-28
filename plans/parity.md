# Parity Plan: Bubbles (Go → Crystal)

Upstream: [charmbracelet/bubbles](https://github.com/charmbracelet/bubbles) at `v2.1.0`
Pinned: `vendor/bubbles/` at `f1daacf` (v2.1.0)
Status: `152 examples, 0 failures, 0 errors, 4 pending`

## Feature Roadmap

### Completed (v2.1.0)

- [x] **Textarea Dynamic Height** — new fields `DynamicHeight`, `MinHeight`, `MaxContentHeight`, methods `recalculateHeight`, `atContentLimit`, `totalVisualLines`, `visualLinesForInsert`. 16 tests ported from `textarea/textarea_test.go`.

### Completed (v2.0.0 baseline — all tests green)

- [x] **Spinner** — full port, `spec/spinner_spec.cr`
- [x] **Cursor** — full port, `spec/cursor_spec.cr`
- [x] **Filepicker** — full port, `spec/filepicker_spec.cr`
- [x] **Help** — full port, `spec/help_spec.cr`
- [x] **Key** — full port, `spec/key_spec.cr`
- [x] **List** — full port, `spec/list_spec.cr`
- [x] **Paginator** — full port, `spec/paginator_spec.cr`
- [x] **Progress** — full port, `spec/progress_spec.cr`
- [x] **Stopwatch** — full port, `spec/stopwatch_spec.cr`
- [x] **Table** — full port, `spec/table_spec.cr`
- [x] **TextInput** — full port, `spec/textinput_spec.cr`
- [x] **Textarea** — full port, `spec/textarea_spec.cr`
- [x] **Timer** — full port, `spec/timer_spec.cr`
- [x] **Viewport** — full port, `spec/viewport_spec.cr`
- [x] **Internal** — memoization, runeutil, `spec/internal/*`

### Skipped Upstream (pending — not actionable)

| Test | Reason |
|------|--------|
| `TestModel_View_Width_less_than_columns` | Skipped in Go upstream |
| `TestModel_View_CenteredInABox` | Skipped in Go upstream |
| `TestChinesePlaceholder` | Flaky in Go upstream |
| `TestPlaceholderTruncate` | Flaky in Go upstream |
