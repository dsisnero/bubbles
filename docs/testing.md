# Testing

## Running Tests

```bash
make test  # Run all Crystal specs
```

For individual test files:

```bash
crystal spec spec/textinput_spec.cr
```

## Test Conventions

- Test files are in `spec/` directory
- Test file naming: `[component]_spec.cr` (e.g., `textinput_spec.cr`)
- Use Crystal's built-in spec framework
- Follow Go test patterns when porting tests

## Writing Tests

When porting Go tests to Crystal:

1. **Preserve test logic exactly** - Don't change assertions or expected values
2. **Convert Go test tables** to Crystal `it` blocks with `describe`/`context`
3. **Use `pending` for missing functionality** - Mark tests that can't run yet
4. **Maintain test coverage** - Port all Go test cases, including edge cases
5. **Verify against Go implementation** - Ensure Crystal behavior matches Go
   exactly

Example test structure:

```crystal
describe Bubbles::TextInput do
  describe "#update" do
    it "handles character input" do
       # Test logic ported from Go
    end

    pending "handles paste events" do
      # Marked pending until functionality is ported
    end
  end
end
```

## Coverage

- Use `crystal spec --verbose` for detailed output
- Check test parity with Go using the golden files in
  `vendor/bubbles/<component>/testdata/`
- Ensure all ported components have corresponding spec files
- Current test count: **335 examples, 0 failures, 4 pending**

## v2.2.2 Coverage

The v2.2.2 delta is covered by dedicated specs:

- `spec/tree_spec.cr` — tree bubble, including both upstream goldens.
- `spec/textarea_v222_spec.cr` — selection, clipboard, grapheme navigation,
  wrapping, and the v2.2.2 key bindings.
- Component delta tests live in the corresponding component spec (timer,
  stopwatch, table, viewport, list, help, filepicker, paginator, progress,
  textinput).

`spec/progress_golden_spec.cr` requires the `golden` development dependency
declared in `shard.yml`.

## Golden Files

Several components (table, help, viewport) share golden test files with the Go
vendor source. Crystal reads Go's golden files directly from
`vendor/bubbles/<component>/testdata/`, ensuring exact output parity.
