# Porting Guidance

**Note:** This document contains detailed porting guidance previously in
`docs/development.md`. It is kept here as a developer reference for porting Go
code to Crystal.

## Porting Workflow

This is a Crystal port of Go code. All logic should match the Go implementation
exactly, differing only in Crystal language idioms and standard library usage.

1. The Go code in `vendor/bubbles/` is the source of truth
2. Port Go tests to Crystal specs to verify behavior
3. Use Crystal's type system and idioms where appropriate
4. Follow Crystal naming conventions (snake_case for methods, CamelCase for
   classes)

## Core Principles

1. **Upstream Go code is the source of truth**
2. Use Crystal idioms without changing semantics
3. Port all Go code and tests
4. Verify behavior parity with Go
5. Never simplify, always port correctly

## Debugging

When something breaks:

1. Check Go source in `vendor/bubbles/` for reference implementation
2. Verify test parity with Go tests
3. Run `make lint` and `make test` to identify issues
4. Check `./temp` directory for test artifacts

## Conventions

- Follow Crystal naming: snake_case for methods/variables, CamelCase for classes
- Use `./temp` directory for temporary files during development
- Never commit temporary files (already in `.gitignore`)
- Port Go tests exactly, maintaining same assertions and edge cases
- Mark missing functionality as `pending` in specs until ported

## Verification

After porting, verify:

1. Run Go tests in `vendor/bubbles/<component>/`: `go test -count=1 ./...`
2. Run Crystal tests: `make test`
3. Run linter: `make lint`
4. Check component-specific specs pass individually
