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
- Port baseline: v2.2.2 (fully ported)
- Release plan: [plans/vendor-v2.2.2.md](../plans/vendor-v2.2.2.md)
- Import mode: `submodule`
- Upstream path: `vendor/bubbles/`

## Parity Scope

All 14 modules from the v2.1.1 baseline are ported, plus the `tree/` bubble
introduced in v2.2.2. Modules whose upstream behavior did not change in v2.2.2
keep their v2.1.1 note; everything else is aligned to the current pin.

| Upstream Module | Crystal Target | Status | Tests | Notes |
|-----------------|----------------|--------|-------|-------|
| `textinput/` | `src/bubbles/textinput.cr` | ✅ Ported | 32 | v2.2.2 delta |
| `textarea/` | `src/bubbles/textarea.cr` | ✅ Ported | 109 | v2.2.2 selection/copy + 6 bug fixes |
| `list/` | `src/bubbles/list.cr` | ✅ Ported | 9 | v2.2.2 delta |
| `spinner/` | `src/bubbles/spinner.cr` | ✅ Ported | — | v2.1.1 |
| `progress/` | `src/bubbles/progress.cr` | ✅ Ported | 4 | v2.2.2 delta |
| `viewport/` | `src/bubbles/viewport.cr` | ✅ Ported | 28 | v2.2.2 delta + 3 bug fixes |
| `filepicker/` | `src/bubbles/filepicker.cr` | ✅ Ported | 13 | v2.2.2 delta |
| `help/` | `src/bubbles/help.cr` | ✅ Ported | 4 | v2.2.2 delta — golden files shared with Go |
| `cursor/` | `src/bubbles/cursor.cr` | ✅ Ported | 25 | v2.1.1 |
| `key/` | `src/bubbles/key.cr` | ✅ Ported | 12 | v2.1.1 |
| `paginator/` | `src/bubbles/paginator.cr` | ✅ Ported | 11 | v2.2.2 delta |
| `timer/` | `src/bubbles/timer.cr` | ✅ Ported | 20 | v2.2.2 delta |
| `stopwatch/` | `src/bubbles/stopwatch.cr` | ✅ Ported | 14 | v2.2.2 delta |
| `table/` | `src/bubbles/table.cr` | ✅ Ported | 34 | v2.2.2 delta |
| `tree/` | `src/bubbles/tree.cr` | ✅ Ported | 10 | New in v2.2.2 — upstream goldens match |

## Test Parity

| Component | Go Tests | Crystal Tests | Status |
|-----------|----------|---------------|--------|
| textarea | 30 | 109 | ✅ All ported + strengthened |
| viewport | ~30 | 28 | ✅ All ported |
| textinput | 4 | 32 | ✅ All ported + extra coverage |
| table | 33 | 34 | ✅ All ported (golden files shared) |
| list | 5 | 9 | ✅ All ported |
| filepicker | 0 | 13 | ✅ No Go tests, Crystal coverage |
| help | 3 | 4 | ✅ Golden-driven |
| cursor | 1 | 25 | ✅ All ported + extra coverage |
| key | — | 12 | ✅ Covered in spec |
| paginator | 7 | 11 | ✅ All ported |
| stopwatch | 0 | 14 | ✅ No Go tests, Crystal coverage |
| timer | — | 20 | ✅ Covered in spec |
| progress | — | 4 | ✅ Covered in spec |
| spinner | — | — | ⚠️ No spec yet |
| tree | 8 | 10 | ✅ Ported (new in v2.2.2) |

**Total: 335 examples, 0 failures, 4 pending** (pending = skipped in upstream
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
