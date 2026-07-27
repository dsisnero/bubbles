# PR Workflow

## Commit Conventions

Format: `<type>(<scope>): <description>`

Types: feat, fix, docs, refactor, test, chore, perf

### Examples

- `feat(textinput): add placeholder support`
- `fix(list): handle empty list edge case`
- `test(spinner): port Go spinner tests`
- `docs: update porting parity documentation`
- `chore: update dependencies`

## Branch Naming

Format: `<type>/<issue-number>-<short-kebab-description>`

### Examples

- `feat/42-add-textarea-component`
- `fix/57-list-selection-bug`
- `test/89-port-progress-tests`

## PR Checklist

- [ ] Code follows project guidelines (see
      [Coding Guidelines](coding-guidelines.md))
- [ ] Tests added/updated (see [Testing](testing.md))
- [ ] Documentation updated (if applicable)
- [ ] CHANGELOG.md updated for user-facing changes
- [ ] Lint/format checks pass
- [ ] All tests pass

## Review Process

1. **Self-review** using `/forge-reflect-pr` before requesting review
2. **Address feedback** using `/forge-address-pr-feedback` for reviewer comments
3. **Verify quality gates**:

   ```bash
   crystal tool format --check
   ameba --fix
   ameba
   crystal spec
   rumdl fmt docs/ *.md
   ```

4. **Update changelog** for user-facing changes using `/forge-update-changelog`
