# Plan: Update Port to Track vendor v2.1.1

Upstream: [charmbracelet/bubbles](https://github.com/charmbracelet/bubbles) at `v2.1.1`
Pinned: `vendor/bubbles/` at `d2b2217` (v2.1.1)
Previous: `f1daacf` (v2.1.0)

## Summary

Only one behavioral change between v2.1.0 and v2.1.1: a prompt-styling consistency fix
in `textarea/textarea.go`. There are no new features, new files, or API additions.

## Change 1 — textarea prompt rendering fix

**Go commit:** `d2b2217` ("fix(textarea): apply prompt style on all lines, including fillers")

**Problem:** `promptView()` returned an un-styled prompt string, and each caller had to
remember to apply `computedPrompt().Render()` on the result. The `placeholderView()`
caller was missing this render step, so placeholder prompts were unstyled.

**Fix:** Move the `computedPrompt().Render()` call *inside* `promptView()` so it always
returns a fully-rendered prompt.

### Go diff (textarea/textarea.go)

```diff
 func (m Model) promptView(displayLine int) (prompt string) {
 	prompt = m.Prompt
-	if m.promptFunc == nil {
-		return prompt
-	}
-	prompt = m.promptFunc(...)
-	width := lipgloss.Width(prompt)
-	if width < m.promptWidth {
-		prompt = fmt.Sprintf("%*s%s", m.promptWidth-width, "", prompt)
+	if m.promptFunc != nil {
+		prompt = m.promptFunc(...)
+		width := lipgloss.Width(prompt)
+		if width < m.promptWidth {
+			prompt = fmt.Sprintf("%*s%s", m.promptWidth-width, "", prompt)
+		}
 	}

-	return prompt
+	return m.activeStyle().computedPrompt().Render(prompt)
 }

 // in view():
-	prompt = styles.computedPrompt().Render(prompt)

 // in placeholderView():
-	prompt = styles.computedPrompt().Render(prompt)
```

### Crystal port (two defects)

The first pass only removed the redundant call-site renders. It missed the early
return in `prompt_view`, so prompts were left **completely unstyled** whenever no
prompt function was set — the exact bug the upstream commit fixes.

| Location | Code | Status |
|----------|------|--------|
| `prompt_view` | `return prompt if @prompt_func.nil?` | Styling skipped for the nil-prompt-func path |
| `src/bubbles/textarea.cr:1320-1321` | `prompt = prompt_view(display_line)` then `prompt = styles.computed_prompt.render(prompt)` | Removed redundant render |
| `src/bubbles/textarea.cr:1456-1457` | `prompt = prompt_view(i)` then `prompt = styles.computed_prompt.render(prompt)` | Removed redundant render |

### Crystal fix

```diff
 private def prompt_view(display_line : Int32) : String
   prompt = @prompt
-  return prompt if @prompt_func.nil?
-
-  info = PromptInfo.new(...)
-  prompt = @prompt_func.as(PromptInfo -> String).call(info)
-  width = Lipgloss.width(prompt)
-  if width < @prompt_width
-    prompt = (" " * (@prompt_width - width)) + prompt
+  unless @prompt_func.nil?
+    info = PromptInfo.new(...)
+    prompt = @prompt_func.as(PromptInfo -> String).call(info)
+    width = Lipgloss.width(prompt)
+    if width < @prompt_width
+      prompt = (" " * (@prompt_width - width)) + prompt
+    end
   end

   active_style.computed_prompt.render(prompt)
 end

 # view_internal (line 1321):
 wrapped_lines.each_with_index do |wrapped_line, wrapped_idx|
   prompt = prompt_view(display_line)
-  prompt = styles.computed_prompt.render(prompt)
   output << style.render(prompt)

 # placeholder_view (line 1457):
 prompt = prompt_view(i)
-prompt = styles.computed_prompt.render(prompt)
 buf << line_style.render(prompt)
```

### Regression test

Upstream added no test for this commit. `spec/textarea_spec.cr` adds one that fails
without the fix: "styles the prompt on all visible lines without a prompt function".

### Verification

- `crystal spec spec/textarea_spec.cr` — 49 examples, 0 failures
- Run `make lint` and `make test` for full regression

## Change 2 — Go dependency bumps (no Crystal action needed)

| Go dependency | v2.1.0 | v2.1.1 |
|---------------|--------|--------|
| bubbletea/v2  | v2.0.2 | v2.0.7 |
| lipgloss/v2   | v2.0.2 | v2.0.4 |
| x/ansi        | v0.11.6 | v0.11.7 |
| go-runewidth  | v0.0.21 | v0.0.24 |
| sahilm/fuzzy  | v0.1.1 | v0.1.3 |

These are Go dependency bumps. Our Crystal shard dependencies (`shard.yml`) are
independent and should be evaluated separately when the upstream behavior requires
it. No action needed here.

## Execution order

1. Move the `computed_prompt.render()` call inside `prompt_view` (drop the nil early return)
2. Remove the two redundant `computed_prompt.render()` calls at the call sites
3. Add a regression spec (upstream has none)
4. `crystal spec spec/textarea_spec.cr` — confirm tests pass
5. `make lint` — confirm formatting and linting
6. `make test` — full regression

## Status

Merged to `main` (`42f39c2`), which also fixes the `dynamic_textarea` example
golden gap in `bubbletea.cr/bubbletea-examples` (Go skips the unchanged gutter
with `CSI 2 C`; the un-styled prompt made Crystal rewrite the cell).
