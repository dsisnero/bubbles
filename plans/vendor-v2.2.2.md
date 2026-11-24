# Plan: Bubbles v2.2.2 Vendor Refresh

- Upstream: [charmbracelet/bubbles](https://github.com/charmbracelet/bubbles) at
  `v2.2.2`
- Pinned: `vendor/bubbles/` at `0c1a491` (v2.2.2)
- Previous: `d2b2217` (v2.1.1)
- Parent plan: [parity.md](parity.md)

## Why this file

`plans/parity.md` is the feature roadmap for the whole port. This file owns the
`v2.1.1 -> v2.2.2` delta so the roadmap stays readable and each phase lands as
its own commit.

## Release delta

| Metric | Value |
|--------|-------|
| Commits | 61 |
| Files changed | 43 |
| Diff | +5514 / -206 |
| Non-test code | +2133 / -153 across 17 files |
| Source ids removed | 0 |
| New source declarations | 97 |
| New upstream tests | 132 |
| New component | `tree/` |

The 435 source ids from v2.1.1 all still exist, so this is additive. The curated
ledger grew from 509 to 738 rows: 97 source declarations and 132 tests are
recorded as `missing` and assigned to the phases below.

| Component | Non-test change | New source ids | New tests | Phase |
|-----------|-----------------|----------------|-----------|-------|
| `tree/` | new bubble (`node.go`, `styles.go`, `tree.go`) | 82 | 8 | 1 |
| `textarea/` | `selection.go`, `grapheme.go`, copy messages, new key bindings | 14 | 59 | 2 |
| `textinput/` | paste error unwrap + behavior delta | 1 | 12 | 3 |
| `timer/` | behavior delta | 0 | 15 | 3 |
| `table/` | cursor shrink + behavior delta | 0 | 12 | 3 |
| `viewport/` | `highlight.go`, soft-wrap delta | 0 | 3 | 3 |
| `filepicker/` | behavior delta | 0 | 5 | 3 |
| `list/` | filter/status-bar delta | 0 | 4 | 3 |
| `stopwatch/` | behavior delta | 0 | 6 | 3 |
| `help/` | style/padding delta | 0 | 3 | 3 |
| `paginator/` | behavior delta | 0 | 3 | 3 |
| `progress/` | behavior delta | 0 | 2 | 3 |

## Phase 1 — Tree bubble (new) — done

Port the three new files and their tests:

- `tree/node.go` — `Node`, `NewNode`, `Root`, traversal/insert/remove helpers.
- `tree/styles.go` — default styles and key map styling.
- `tree/tree.go` — `Model`, navigation, filtering, help, viewport integration.
- Tests: `tree/node_value_test.go`, `tree/tree_test.go`, plus the golden
  fixtures under `tree/testdata/` (`TestTree/default_tree.golden`,
  `TestTreeAdditionalHelp/additional_help.golden`).

Deliverables:

- `src/bubbles/tree.cr` added to `src/bubbles.cr`.
- `spec/tree_spec.cr` (and golden specs if the fixtures are used).
- 82 ledger ids leave `missing`; 8 test rows close.
- `plans/parity.md` gains a completed feature line.

Gotcha: `tree` landed in v2.2.0 (`e97af08`) and was fixed in v2.2.2
(`65f99f0`, `SetValue` refreshes rendered node values). Port against v2.2.2, not
the initial commit.

## Phase 2 — Textarea selection, copy, grapheme cursor — done

The largest behavioral change. Files:

- `textarea/selection.go` — `Position`, `BeginSelection`, `EndSelection`,
  `ExtendSelection`, `ClearSelection`, `HasSelection`, `SelectAll`,
  `SelectedText`, `Selection`, `PositionAt`, `DeleteSelection`, `CopySelection`.
- `textarea/grapheme.go` — grapheme-aware cursor math used by selection.
- `textarea/textarea.go` — new select/copy key bindings, `copyMsg`/`copyErrMsg`,
  clipboard integration, updated word motion bindings (`ctrl+left/right`,
  `ctrl+backspace`, `ctrl+delete`).

Deliverables:

- Selection API on `Bubbles::Textarea::Model`, clipboard via Bubble Tea's
  existing clipboard command, new key bindings with defaults matching Go.
- 14 ledger ids and 59 tests close; port `selection_test.go`,
  `grapheme_test.go`, `grapheme_cursor_test.go`, and the selection cases in
  `textarea_test.go`.

## Phase 3 — Remaining component deltas — done

Small, independent changes. Land one component per commit:

- `textinput`: `pasteErrMsg.Unwrap` plus the v2.2.2 behavior changes.
- `timer`, `stopwatch`, `paginator`, `progress`: small behavioral deltas.
- `table`: cursor shrink behavior.
- `viewport`: highlight and soft-wrap changes.
- `filepicker`, `list`, `help`: style/behavior deltas.

Closes 1 source id and 65 tests.

## Definition of done (per phase)

1. Ported specs fail first, then pass.
2. Ledger rows for the phase are `ported` or `intentional_divergence` with
   `crystal_refs`; no stale `missing` rows remain for that phase.
3. `crystal tool format --check`, `ameba`, `crystal spec` are green.
4. Source/test parity checks pass at the pinned revision.
5. `plans/parity.md` checkbox and **Where we are** block refreshed.
6. One `port: <phase>` commit.

## Refresh record

Vendor bump and manifest refresh performed with the installed
`cross-language-crystal-parity` skill:

```bash
SKILL=~/.config/opencode/skills/cross-language-crystal-parity
git -C vendor/bubbles checkout v2.2.2
PORT_PARSER=regex "$SKILL/scripts/ensure_parity_plan.sh" . vendor/bubbles go regex 1
python3 "$SKILL/scripts/check_kind_vocabulary.py" --scan go=vendor/bubbles
PORT_PARSER=regex "$SKILL/scripts/check_source_parity.sh" . plans/inventory/go_source_parity.tsv vendor/bubbles go
PORT_PARSER=regex "$SKILL/scripts/check_test_parity.sh" . plans/inventory/go_test_parity.tsv vendor/bubbles go
PORT_PARSER=regex "$SKILL/scripts/check_port_inventory.sh" . plans/inventory/go_port_inventory.tsv vendor/bubbles go
```

Results:

- Kind gate: 1199 declarations in 7 kinds, no drops.
- Source parity: 532 API items tracked.
- Test parity: 206 tests tracked.
- Port inventory: 532 source items tracked, 0 missing.

Artifacts updated:

- `plans/inventory/go_source_parity.tsv` (+ metadata)
- `plans/inventory/go_test_parity.tsv` (+ metadata)
- `plans/inventory/go_port_inventory.tsv` (97 source + 132 test rows added)
- `plans/inventory/v2.2.2_delta.tsv` (229 additions: 97 source + 132 tests)

## Scoping notes

- The ledger is keyed on the historical regex vocabulary (`func`, `struct`,
  `type`, `method`, `const`). Keep `PORT_PARSER=regex` until a reviewed
  tree-sitter migration; mixed vocabularies churn every id.
- `scripts/vendor_drift.py` is Rust-oriented: its visibility index only reads
  `*.rs`, so for this Go tree the report's visibility column is `unknown` and
  the `added`/`moved` split is unreliable (the `--scan-subdirs .` prefix made
  every symbol look moved). The authoritative delta here is the manifest diff
  (`435 -> 532` ids, no removals), recorded in `v2.2.2_delta.tsv`.
- The copied `scripts/` in this repo predate the installed skill (they differ
  from the canonical scripts, including the tree-sitter paths). Prefer the
  installed skill's scripts; do not run the stale copies as a gate.
- The v2.1.1 prompt-style fix remains valid: `promptView` is identical in
  v2.1.1 and v2.2.2, including the `CSI 2 C` gutter-skip outcome in the
  `dynamic_textarea` example.
- Keep `vendor/bubbles` at exactly `0c1a491` while working through phases; a
  later tag means a new plan file and a re-based ledger.

## Status

Released as **v2.2.2** (tag matches upstream `charmbracelet/bubbles` v2.2.2).
Vendor bumped and manifests refreshed. All three phases are complete: `tree`,
textarea selection/copy/graphemes, and the remaining component deltas. The
ledger records every v2.2.2 addition as ported, and the suite is at 335 specs
(4 skipped upstream).

The release was verified against ultraviolet 1.1.7, colorprofile 0.1.1 and the
`dsisnero/terminfo` fork; `shards install` works from scratch. A viewport
highlight byte-slicing bug found during that verification is fixed and covered
by regression tests. `bubbletea-examples` pins this tag and its README GIFs are
recorded from our examples with VHS.

Remaining consumer work lives in `bubbletea.cr/plans/parity.md`: the five
approximation examples and the documented pending specs.
