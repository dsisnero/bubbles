# Changelog

All notable user-facing changes to this project will be documented in this file.

Changes are grouped by release date and category. Only user-facing changes are included — internal refactors, test updates, and CI changes are omitted.

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