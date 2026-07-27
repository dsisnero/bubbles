---
upstream_repo: "https://github.com/charmbracelet/bubbles"
pinned_revision: "d2b2217"
import_mode: "submodule"
upstream_submodule_path: "vendor/bubbles/"
---

# Porting Parity

## Upstream Source of Truth

- Repository: `https://github.com/charmbracelet/bubbles`
- Pinned revision: `d2b2217` (v2.1.1)
- Import mode: `submodule`
- Upstream path: `vendor/bubbles/`

## Parity Scope

| Upstream Module/Path | Crystal Target | Status | Notes |
|----------------------|----------------|--------|-------|
| `textinput/` | `src/bubbles/textinput.cr` | Ported | v2.1.1 |
| `textarea/` | `src/bubbles/textarea.cr` | Ported | v2.1.1 — prompt render fix applied |
| `list/` | `src/bubbles/list.cr` | Ported | v2.1.1 |
| `spinner/` | `src/bubbles/spinner.cr` | Ported | v2.1.1 |
| `progress/` | `src/bubbles/progress.cr` | Ported | v2.1.1 |
| `viewport/` | `src/bubbles/viewport.cr` | Ported | v2.1.1 |
| `filepicker/` | `src/bubbles/filepicker.cr` | Ported | v2.1.1 |
| `help/` | `src/bubbles/help.cr` | Ported | v2.1.1 |
| `cursor/` | `src/bubbles/cursor.cr` | Ported | v2.1.1 |
| `key/` | `src/bubbles/key.cr` | Ported | v2.1.1 |
| `paginator/` | `src/bubbles/paginator.cr` | Ported | v2.1.1 |
| `timer/` | `src/bubbles/timer.cr` | Ported | v2.1.1 |
| `stopwatch/` | `src/bubbles/stopwatch.cr` | Ported | v2.1.1 |
| `table/` | `src/bubbles/table.cr` | Ported | v2.1.1 — TODO: verify full test parity |

## Behavior Checklist

- [ ] Public API surface mapped
- [ ] Constants and types ported
- [ ] Error semantics matched
- [ ] Edge cases mirrored
- [ ] Fixtures/goldens verified

## Test Parity

| Upstream Test/Fixture | Crystal Spec | Status | Notes |
|------------------------|--------------|--------|-------|
| `textinput/*_test.go` | `spec/textinput_spec.cr` | Partial | Some tests pending |
| `textarea/*_test.go` | `spec/textarea_spec.cr` | Partial | Some tests pending |
| `list/*_test.go` | `spec/list_spec.cr` | Partial | Some tests pending |
| `spinner/*_test.go` | `spec/spinner_spec.cr` | Partial | Some tests pending |
| `progress/*_test.go` | `spec/progress_spec.cr` | Partial | Some tests pending |
| `viewport/*_test.go` | `spec/viewport_spec.cr` | Partial | Some tests pending |
| `filepicker/*_test.go` | `spec/filepicker_spec.cr` | Partial | Some tests pending |
| `help/*_test.go` | `spec/help_spec.cr` | Partial | Some tests pending |
| `cursor/*_test.go` | `spec/cursor_spec.cr` | Partial | Some tests pending |
| `key/*_test.go` | `spec/key_spec.cr` | Partial | Some tests pending |
| `paginator/*_test.go` | `spec/paginator_spec.cr` | Partial | Some tests pending |
| `timer/*_test.go` | `spec/timer_spec.cr` | Partial | Some tests pending |
| `stopwatch/*_test.go` | `spec/stopwatch_spec.cr` | Partial | Some tests pending |
| `table/*_test.go` | `spec/table_spec.cr` | Ported | Ported from Go v2.1.1 |

## Known Deviations

<!-- TODO: List intentional deviations and why they are unavoidable. -->

## Verification Commands

```bash
crystal tool format src spec
ameba src spec
crystal spec
rumdl fmt docs/ *.md
```
