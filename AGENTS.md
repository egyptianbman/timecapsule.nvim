# timecapsule.nvim

Neovim plugin that backs up files to a local git repo on BufWritePost.

## Agent Workflow

**Always add a failing test before fixing any issue.** This applies to:
- Bugs (crashes, wrong behavior, edge cases)
- Regressions (new code that breaks existing functionality)
- New features (ensure the behavior is testable)

The test goes in `tests/` using Plenary test_harness. Run the full suite after:
```bash
nvim --headless -c "PlenaryBustedDirectory tests/" -c "qa"
```

## Test Conventions

- Use `assert.equal()`, `assert.truthy()`, `assert.is_false()`, `assert.error()` (NOT `assert_not_nil()`)
- Clean up temp dirs with `vim.fn.delete(dir, "rf")` (NOT `os.execute("rm -rf " .. dir)` — shell injection)
- Use `vim.fn.system({ "git", ... })` table form (NOT string interpolation — shell injection)
- Test isolation: clean stale state at start of tests that use shared paths

## Architecture

| File | Purpose |
|---|---|
| `lua/timecapsule/init.lua` | Main module: setup, toggle, _handle_write() |
| `lua/timecapsule/config.lua` | Config validation and defaults |
| `lua/timecapsule/git.lua` | Git operations: add, commit, push, is_in_repo, is_clean |
| `lua/timecapsule/log.lua` | Logging wrapper |
| `plugin/timecapsule.lua` | Plugin loader (16 lines) |

## CI

- Tests run on 2 Neovim versions (nightly, v0.10.0)
- Plugin requires Neovim 0.10+
- Plenary loaded from `~/.local/share/nvim/site/pack/vendor/start/plenary.nvim`
- Run tests: `nvim --headless -c "PlenaryBustedDirectory tests/" -c "qa"` (plenary must be in a pack path)

- Lint runs stylua (formatting) and luacheck (static analysis) via GitHub Actions
- Run locally: `pre-commit run --all-files` (requires pre-commit installed, hooks configured in .pre-commit-config.yaml)
- Run in CI: `act -j lint` (requires Docker and nektos/act)
