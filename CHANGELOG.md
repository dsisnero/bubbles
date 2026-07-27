# Changelog

All notable user-facing changes to this project will be documented in this file.

Changes are grouped by release date and category. Only user-facing changes are included — internal refactors, test updates, and CI changes are omitted.

## [2.1.2] - 2026-07-27

### Fixed
- **Textarea `merge_line_below` use-after-delete** — referenced `@value[row + 1]`
  after `delete_at(row + 1)`. Rewritten to match Go's shift+truncate semantics.
- **Textarea `recalculate_height` zero-handling bug** — `if max_offset = total - h`
  made 0 falsy in Crystal, skipping viewport reset. Also removed a no-op comparison.
- **Textarea `insert_string` char-by-char iteration** — now delegates to
  `insert_runes_from_user_input` like Go, properly handling sanitizer, char limits,
  MAX_LINES, and MaxContentHeight at batch level.
- **Textarea `word()` edge cases** — now returns `""` when cursor at line start,
  on space, or past line end, matching Go.
- **Textarea `recalculate_height` call order** — moved before `viewport.set_content`
  to match Go order.
- **Viewport `View()` style handling** — now accounts for `Style.GetWidth/Height`,
  frame sizes, and renders style borders/padding correctly.
- **Viewport `scroll_percent` raw line count** — now uses `calculate_line(0)`
  for soft-wrap mode instead of `@lines.size`.
- **Viewport `total_line_count` raw line count** — now returns visual line count
  from `calculate_line(0)`.
- **Key `set_keys`/`with_keys` no-arg nil keys** — Go's empty-variadic creates
  an empty (non-nil) slice, keeping the binding enabled. Crystal now uses
  `[] of String` instead of `nil`.

### Added
- **Viewport standalone page scroll methods** — `page_up`, `page_down`,
  `half_page_up`, `half_page_down` public API matching Go.
- **Viewport `horizontal_step` public property** — exposed for test parity.
- **Textarea `end_of_buffer_character` public property** — exposed for parity.
- **TextInput suggestion methods public** — `update_suggestions`, `next_suggestion`,
  `previous_suggestion` made public for Go test parity.
- **17 new textarea tests** — strong port of Go `TestView`, `TestWord`, vertical
  navigation, scrolling, and overflow tests with exact assertions.
- **13 new viewport tests** — `TestNew` (8 cases), `TestRenderRow` exact matching,
  `TestVisibleLines`, `TestMatchesToHighlights`, `TestSizing` edge cases.
- **12 new table tests** — `TestNew` (8 sub-tests), `TestRenderRow` (3 sub-tests
  with exact string matching).
- **README updated** — usage descriptions and examples from vendor README.
- **Porting guidance** moved from `docs/development.md` to `plans/development.md`.
- **All docs/* updated** — architecture, testing, porting-parity reflect current
  195-test state.

### Changed
- Lint fix: `dynamic_height` uses `property?` for Crystal naming convention.
- `spec/table_spec.cr` — `TestModel_RenderRow` uses exact string matching instead
  of `contain` assertions.
- `spec/key_spec.cr` — no-arg `with_keys`/`set_keys` expectations updated from
  nil to empty array for Go parity.

### Notes
- No breaking changes; all existing APIs unchanged.
- 195 examples, 0 failures, 4 pending (skipped in upstream).

## [2.1.1] - 2026-07-27

### Changed
- **Textarea prompt rendering fix** — `prompt_view` now applies prompt style
  internally, matching upstream Go v2.1.1 fix (`charmbracelet/bubbles#921`).
  Fixes placeholder prompts not being styled.
- Vendor submodule updated to `charmbracelet/bubbles` v2.1.1.

### Notes
- No breaking changes; all existing APIs unchanged.
- 156 examples, 0 failures, 4 pending (skipped in upstream).

## [2.1.0] - 2026-05-28

### Added
- **Textarea dynamic height** (`DynamicHeight`, `MinHeight`, `MaxContentHeight`) — textarea
  can now grow and shrink its height to fit content, ported from upstream Go v2.1.0.
  See `vendor/bubbles/textarea/textarea.go` (v2.1.0) for reference.
- New `Textarea::Model` methods: `total_visual_lines`, `recalculate_height`,
  `at_content_limit`, `visual_lines_for_insert`
- New `Textarea::Model` properties: `dynamic_height`, `min_height`, `max_content_height`,
  `max_height`, `max_width`, `viewport`
- 20 parity tests ported from Go v2.1.0 textarea tests

### Changed
- Textarea height management unified through `recalculate_height`; `MaxHeight` newline
  guard replaced with `at_content_limit` for backward-compatible `MaxContentHeight` support

### Notes
- This release represents feature parity with upstream Go Bubbles v2.1.0
- No breaking changes; all existing APIs unchanged
- 156 examples, 0 failures, 4 pending (skipped in upstream)

## [2.0.0] - 2026-03-06

### Added
- Complete Crystal port of Bubbles v2.0.0 from upstream Go implementation
- All core components: TextInput, TextArea, List, Table, Viewport, Progress, Filepicker, Help, Paginator, Spinner, Stopwatch, Timer, Cursor
- Comprehensive test suite ported from Go tests
- Upgrade guide for migrating from Go Bubbles v1 to Crystal v2

### Changed
- Version bumped from 0.1.0 to 2.0.0 to match upstream Go version
- API follows Crystal naming conventions while maintaining Go semantics

### Notes
- This release represents feature parity with upstream Go Bubbles v2.0.0
- All components have been ported with test verification
- See `docs/upgrade_guide_v2.md` for migration guidance