# Parity Plan: Bubbles (Go → Crystal)

- Upstream: [charmbracelet/bubbles](https://github.com/charmbracelet/bubbles) at
  `v2.2.2`
- Pinned: `vendor/bubbles/` at `0c1a491` (v2.2.2)
- Status: `208 examples, 0 failures, 0 errors, 4 pending`

**Vendor delta:** `v2.1.1 -> v2.2.2` is planned in
[vendor-v2.2.2.md](vendor-v2.2.2.md) — the new `tree` bubble, textarea
selection/copy, and the remaining component deltas.

## Where we are

- **Current focus:** Phase 2 — textarea selection/copy/grapheme (14 ids, 59
  tests).
- **Next up:** Phase 3 — remaining component deltas (1 id, 65 tests).
- **Upstream:** `charmbracelet/bubbles` v2.2.2 at `0c1a491` (`vendor/bubbles`).
- **Port baseline:** everything from v2.1.1 is ported and green; the v2.2.2
  `tree` bubble is now ported.
- **Last commit:** `port: tree bubble`.
- **Gates:** `crystal spec` 208 / 0 failures / 4 pending; `ameba` 0 findings;
  `crystal tool format --check` clean; source parity 532; test parity 206;
  port inventory 532 source / 738 total rows (90 tree rows ported).

## Feature Roadmap

### Open (v2.2.2)

- [ ] **Textarea selection/copy** — selection, grapheme cursor, clipboard.
- [ ] **v2.2.2 component deltas** — textinput, timer, table, viewport, and the
  smaller components.

### Completed (v2.2.2)

- [x] **Tree bubble** — `src/bubbles/tree.cr`, `spec/tree_spec.cr`; 82 source
  ids and 8 tests ported against the upstream goldens. See
  [vendor-v2.2.2.md](vendor-v2.2.2.md).

### Completed (v2.1.1)

- [x] **Textarea prompt styling** — `prompt_view` always applies
  `computed_prompt`; closes the `dynamic_textarea` example golden gap
  (upstream `d2b2217`).

### Completed (v2.1.0)

- [x] **Textarea Dynamic Height** — new fields `DynamicHeight`, `MinHeight`,
      `MaxContentHeight`, methods `recalculateHeight`, `atContentLimit`,
      `totalVisualLines`, `visualLinesForInsert`. 16 tests ported from
      `textarea/textarea_test.go`.

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
