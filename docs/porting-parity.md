---
upstream_repo: "https://github.com/charmbracelet/bubbles"
pinned_revision: "8d9107f"
import_mode: "submodule"
upstream_submodule_path: "vendor/bubbles/"
---

# Porting Parity

## Upstream Source of Truth

- Repository: `https://github.com/charmbracelet/bubbles`
- Pinned revision: `8d9107f`
- Import mode: `submodule`
- Upstream path: `vendor/bubbles/`

## Parity Scope

| Upstream Module/Path | Crystal Target | Status | Notes |
|----------------------|----------------|--------|-------|
| `textinput/` | `src/bubbles/textinput.cr` | Ported | Basic functionality complete |
| `textarea/` | `src/bubbles/textarea.cr` | Ported | Basic functionality complete |
| `list/` | `src/bubbles/list.cr` | Ported | Basic functionality complete |
| `spinner/` | `src/bubbles/spinner.cr` | Ported | Basic functionality complete |
| `progress/` | `src/bubbles/progress.cr` | Ported | Basic functionality complete |
| `viewport/` | `src/bubbles/viewport.cr` | Ported | Basic functionality complete |
| `filepicker/` | `src/bubbles/filepicker.cr` | Ported | Basic functionality complete |
| `help/` | `src/bubbles/help.cr` | Ported | Basic functionality complete |
| `cursor/` | `src/bubbles/cursor.cr` | Ported | Basic functionality complete |
| `key/` | `src/bubbles/key.cr` | Ported | Basic functionality complete |
| `paginator/` | `src/bubbles/paginator.cr` | Ported | Basic functionality complete |
| `timer/` | `src/bubbles/timer.cr` | Ported | Basic functionality complete |
| `stopwatch/` | `src/bubbles/stopwatch.cr` | Ported | Basic functionality complete |
| `table/` | `src/bubbles/table.cr` | TODO | Not yet ported |

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
| `table/*_test.go` | TODO | TODO | Not yet ported |

## Known Deviations

<!-- TODO: List intentional deviations and why they are unavoidable. -->

## Verification Commands

```bash
crystal tool format src spec
ameba src spec
crystal spec
rumdl fmt docs/ *.md
```