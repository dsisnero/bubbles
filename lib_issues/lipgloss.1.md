# Lipgloss Issue #1: Track remaining lipgloss-related parity gaps after switching to shard

## Description
`bubbles` now uses the external `lib/lipgloss` shard (local shim removed), so the original API-surface blocker for `list` is largely resolved.

This file now tracks remaining parity gaps that still show up in Go test behavior where lipgloss rendering interacts with viewport/table output.

## Resolved
- List-related lipgloss API surface is available through `lib/lipgloss`.
- `src/lipgloss.cr` shim was removed in favor of shard usage.

## Remaining gaps for this issue
- No current blocker remains in `lib/lipgloss` for table parity.
- The previously observed crash was traced to `Bubbles::Table.with_styles` option application path (host repo), not lipgloss rendering itself.
- With viewport ANSI clipping fixes and `with_styles` fix in table options, the following now pass:
  - `TestModel_RenderRow_AnsiWidth`
  - `TestTableAlignment` (no border + with border)
  - `TestModel_View` (except upstream-skipped width-less-than-columns case)

## Impact
- Go table parity tests remain pending:
  - `TestModel_RenderRow_AnsiWidth`
  - `TestTableAlignment`
  - `TestModel_View`
- These are parity-sensitive and cannot be safely unpended yet.

## Suggested Fix
1. Keep `lib/lipgloss` as the only lipgloss implementation.
2. Fix ANSI-width-safe clipping and selection-render interaction in the table/viewport rendering path.
3. Unpend table Go-golden tests only after exact fixture match.

## References
- `spec/table_spec.cr`
- `src/bubbles/table.cr`
- `src/bubbles/viewport.cr`
- `vendor/bubbles/list/list.go`
- `vendor/bubbles/list/style.go`
- `vendor/bubbles/list/defaultitem.go`
- `vendor/bubbles/table/table_test.go`
