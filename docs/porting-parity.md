---
upstream_repo: "https://github.com/charmbracelet/bubbles"
pinned_revision: "0c1a491"
import_mode: "submodule"
upstream_submodule_path: "vendor/bubbles/"
---

# Porting Parity

## Upstream Source of Truth

- Repository: `https://github.com/charmbracelet/bubbles`
- Pinned revision: `0c1a491` (v2.2.2)
- Port baseline: v2.1.1; the v2.2.2 delta is tracked in
  [plans/vendor-v2.2.2.md](../plans/vendor-v2.2.2.md)
- Import mode: `submodule`
- Upstream path: `vendor/bubbles/`

## Parity Scope

All 14 modules from the v2.1.1 port baseline are ported, plus the `tree/`
bubble introduced in v2.2.2. `v2.1.1` in the Notes column means the module's
port baseline, not the current pin.

| Upstream Module | Crystal Target | Status | Tests | Notes |
|-----------------|----------------|--------|-------|-------|
| `textinput/` | `src/bubbles/textinput.cr` | ✅ Ported | 19 | v2.1.1 |
| `textarea/` | `src/bubbles/textarea.cr` | ✅ Ported | 109 | v2.2.2 selection/copy + 6 bug fixes |
| `list/` | `src/bubbles/list.cr` | ✅ Ported | 5 | v2.1.1 |
| `spinner/` | `src/bubbles/spinner.cr` | ✅ Ported | — | v2.1.1 |
| `progress/` | `src/bubbles/progress.cr` | ✅ Ported | — | v2.1.1 |
| `viewport/` | `src/bubbles/viewport.cr` | ✅ Ported | 23 | v2.1.1 + 3 bug fixes |
| `filepicker/` | `src/bubbles/filepicker.cr` | ✅ Ported | 7 | v2.1.1 |
| `help/` | `src/bubbles/help.cr` | ✅ Ported | 1 | v2.1.1 — golden files shared with Go |
| `cursor/` | `src/bubbles/cursor.cr` | ✅ Ported | 25 | v2.1.1 |
| `key/` | `src/bubbles/key.cr` | ✅ Ported | 12 | v2.1.1 |
| `paginator/` | `src/bubbles/paginator.cr` | ✅ Ported | 8 | v2.1.1 |
| `timer/` | `src/bubbles/timer.cr` | ✅ Ported | — | v2.1.1 |
| `stopwatch/` | `src/bubbles/stopwatch.cr` | ✅ Ported | 8 | v2.1.1 |
| `table/` | `src/bubbles/table.cr` | ✅ Ported | 22 | v2.1.1 |
| `tree/` | `src/bubbles/tree.cr` | ✅ Ported | 10 | New in v2.2.2 — upstream goldens match |

## Test Parity

| Component | Go Tests | Crystal Tests | Status |
|-----------|----------|---------------|--------|
| textarea | 30 | 109 | ✅ All ported + strengthened |
| viewport | ~30 | 23 | ✅ All ported |
| textinput | 4 | 19 | ✅ All ported + extra coverage |
| table | 33 | 22 | ✅ All ported (golden files shared) |
| list | 5 | 5 | ✅ All ported |
| filepicker | 0 | 7 | ✅ No Go tests, Crystal coverage |
| help | 3 | 1 | ✅ Golden-driven |
| cursor | 1 | 25 | ✅ All ported + extra coverage |
| key | — | 12 | ✅ Covered in spec |
| paginator | 7 | 8 | ✅ All ported + 1 extra |
| stopwatch | 0 | 8 | ✅ No Go tests, Crystal coverage |
| timer | — | — | ⚠️ No spec yet |
| progress | — | — | ⚠️ No spec yet |
| spinner | — | — | ⚠️ No spec yet |
| tree | 8 | 10 | ✅ Ported (new in v2.2.2) |

**Total: 268 examples, 0 failures, 4 pending** (pending = skipped in upstream
Go)

## Known Deviations

- **Stopwatch microsecond symbol**: Crystal renders `"us"` (ASCII) instead of
  Go's `"µs"` (micro sign, U+00B5) in `format_duration`.
- **Fuzzy matching**: Crystal implements its own fuzzy search algorithm instead
  of importing `sahilm/fuzzy`. Behavior matches Go for tested inputs.

## Verification Commands

```bash
make lint
make test
```
