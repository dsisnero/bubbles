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
5. **Verify against Go implementation** - Ensure Crystal behavior matches Go exactly

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
- Check test parity with Go using `bin/check_go_test_parity.sh`
- Ensure all ported components have corresponding spec files