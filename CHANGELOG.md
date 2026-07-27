# Changelog

All notable user-facing changes to this project will be documented in this file.

Changes are grouped by release date and category. Only user-facing changes are included — internal refactors, test updates, and CI changes are omitted.

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