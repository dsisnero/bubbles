# Example GIFs

These are recorded from the Crystal examples in
[dsisnero/bubbles-examples](https://github.com/dsisnero/bubbles-examples)
with [VHS](https://github.com/charmbracelet/vhs), not copied from Charm's
upstream assets.

Upstream keeps recorded GIFs next to the Go example programs. We keep the VHS
tape files alongside the Crystal examples so the README assets are
reproducible.

## Regenerating

```bash
git clone https://github.com/dsisnero/bubbles-examples.git
cd bubbles-examples
make gifs                 # builds src/*.cr and runs tapes/*.tape
cp gifs/*.gif ../bubbles/docs/assets/
```

Requirements: Crystal, VHS, `ttyd`, and `ffmpeg`. Build artifacts are written to
`build/`; recordings land in `gifs/`.

## Mapping

| README section | Asset | Example | Tape |
|----------------|-------|---------|------|
| Spinner | `spinner.gif` | `src/spinner.cr` | `tapes/spinner.tape` |
| Text Input | `textinput.gif` | `src/textinput.cr` | `tapes/textinput.tape` |
| Text Area | `textarea.gif` | `src/textarea.cr` | `tapes/textarea.tape` |
| Tree | `tree.gif` | `src/tree.cr` | `tapes/tree.tape` |
| Table | `table.gif` | `src/table.cr` | `tapes/table.tape` |
| Progress | `progress.gif` | `src/progress_animated.cr` | `tapes/progress_animated.tape` |
| Viewport | `viewport.gif` | `src/viewport.cr` | `tapes/viewport.tape` |
| List | `list.gif` | `src/list_default.cr` | `tapes/list_default.tape` |
| File Picker | `filepicker.gif` | `src/file_picker.cr` | `tapes/file_picker.tape` |
| Help | `help.gif` | `src/help.cr` | `tapes/help.tape` |
| Paginator | `pagination.gif` | `src/paginator.cr` | `tapes/paginator.tape` |
| Timer | `timer.gif` | `src/timer.cr` | `tapes/timer.tape` |
| Stopwatch | `stopwatch.gif` | `src/stopwatch.cr` | `tapes/stopwatch.tape` |

Cursor and Key have no recording; they are non-visual or cursor-only APIs.
