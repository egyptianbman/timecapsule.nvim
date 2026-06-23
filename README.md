# timecapsule.nvim

Automatic file backup for Neovim — copies your files to a local git repo on every write, preserving directory structure.

[![CI](https://github.com/egyptianbman/timecapsule.nvim/actions/workflows/test.yml/badge.svg)](https://github.com/egyptianbman/timecapsule.nvim/actions/workflows/test.yml)
[![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-3399AA)](https://neovim.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Table of Contents

- [Getting Started](#getting-started)
- [Installation](#installation)
- [Configuration](#configuration)
- [Commands](#commands)
- [Push to Remote](#push-to-remote)
- [Notifications](#notifications)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

## Getting Started

### Requirements

- Neovim 0.10+
- Git

### Quick Install

Add to your lazy.nvim config:

```lua
{
  "egyptianbman/timecapsule.nvim",
  opts = {
    backup = vim.fn.stdpath("data") .. "/timecapsule",
  },
}
```

### Try It

1. Install the plugin
2. Set `backup` to any directory (e.g. `~/.timecapsule`)
3. Edit and save a file — it's now in your backup repo

Check `git log` in your backup directory to see the history.

## Installation

### lazy.nvim (recommended)

```lua
{
  "egyptianbman/timecapsule.nvim",
  version = "*", -- pin to a tag for stability
  opts = {
    backup = vim.fn.stdpath("data") .. "/timecapsule",
    enable = true,
    message_format = "Updated: {path}",
    push = {
      enable = false,
      branch = nil, -- falls back to current git branch
    },
    notify = {
      success = false,
      failure = true,
    },
  },
}
```

Other package managers (packer.nvim, mini.deps, etc.) work the same way — just make sure `lua/timecapsule/` is on your runtime path and call `require("timecapsule").setup()`.

## Configuration

### Full Setup Example

```lua
require("timecapsule").setup({
  -- Where to store backups (defaults to stdpath("data")/timecapsule)
  backup = vim.fn.stdpath("data") .. "/timecapsule",

  -- Toggle auto-backup on/off (default: true)
  enable = true,

  -- File patterns to back up.
  -- When set, replaces default exclusions entirely.
  -- Use "!" prefix to exclude from a wildcard set.
  file_patterns = nil,

  -- Commit message format. {path} is replaced with the source file path.
  message_format = "Updated: {path}",

  -- Push to remote after commit
  push = {
    enable = false,
    branch = nil, -- nil = auto-detect current branch
  },

  -- Notifications
  notify = {
    success = false,       -- show on successful backup
    failure = true,        -- show on errors
    success_level = vim.log.levels.INFO,
    failure_level = vim.log.levels.ERROR,
  },
  -- Command name is hardcoded as "TimecapsuleToggle" in the plugin loader
})
```

### Config Table

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `backup` | `string` | `stdpath("data")/timecapsule` | Backup directory path |
| `enable` | `boolean` | `true` | Enable or disable auto-backup |
| `file_patterns` | `string[] \| nil` | `nil` | Custom include patterns; replaces default exclusions when set |
| `message_format` | `string` | `"Updated: {path}"` | Commit message template; `{path}` = source file path |
| `push.enable` | `boolean` | `false` | Auto-push to remote after each commit |
| `push.branch` | `string \| nil` | `nil` → auto-detect | Remote branch to push to |
| `notify.success` | `boolean` | `false` | Show `vim.notify` on successful backup |
| `notify.failure` | `boolean` | `true` | Show `vim.notify` on errors |
| `notify.success_level` | `number` | `vim.log.levels.INFO` | Log level for success notifications |
| `notify.failure_level` | `number` | `vim.log.levels.ERROR` | Log level for failure notifications |

### File Patterns

Set `file_patterns` to control which files get backed up. **Default exclusions always apply first** — `file_patterns` only acts as an include filter on top.

```lua
-- Only back up Lua files (but still exclude node_modules/, *.log, etc.)
file_patterns = { "*.lua" }

-- Back up everything except swap files and logs
file_patterns = { "*", "!*.swp", "!*.log" }

-- JS ecosystem, exclude node_modules and minified files
file_patterns = { "*.js", "!node_modules/**", "!*.min.js" }
```

Patterns support `*` glob matching. Prefix with `!` to exclude.

### Default Exclusions

These patterns are always applied, regardless of `file_patterns`:

```
Lock files:       package-lock.json, yarn.lock, pnpm-lock.yaml, Cargo.lock,
                  go.sum, Pipfile.lock, poetry.lock, Gemfile.lock, composer.lock

Dependencies:     node_modules/, vendor/, .venv/

Build outputs:    build/, dist/, out/, .next/, .nuxt/, .angular/, __pycache__/

Runtime/IDE:      .DS_Store, Thumbs.db, .idea/, .vscode/, .cache/, coverage/

Temp files:       *.log, *.tmp, *.swp, *.swo
```

## Commands

| Command | Description |
|---------|-------------|
| `:TimecapsuleToggle` | Enable or disable auto-backup |

Toggle runs during normal editing — no extra keymaps needed.

## Push to Remote

When `push.enable = true`, timecapsule pushes each commit to the configured remote after backing up.

### Setup

```lua
push = {
  enable = true,
  branch = "main", -- or nil to auto-detect
}
```

### Git Identity

The backup repo is initialized with:

- `user.email` = `timecapsule@local`
- `user.name` = `Timecapsule`

If these are already set in the backup repo, timecapsule leaves them alone. To push to a real remote:

```bash
cd ~/.timecapsule
git remote add origin git@github.com:you/backup.git
git push -u origin main
```

## Notifications

Notifications use Neovim's built-in `vim.notify()`. Configure per-level:

```lua
notify = {
  success = true,   -- "Timecapsule: backed up /path/to/file"
  failure = true,   -- "Timecapsule: <error message>"
  success_level = vim.log.levels.INFO,
  failure_level = vim.log.levels.ERROR,
}
```

Silence everything:

```lua
notify = { success = false, failure = false }
```

## Troubleshooting

### Backup not triggering

- Ensure `enable = true` (it is by default)
- Check that `backup` points to a valid directory
- Verify the file isn't matching an exclusion pattern
- Unnamed buffers (new, unsaved files) are skipped — they have no path

### Git identity conflicts

The backup repo sets its own `user.email` and `user.name`. If you've manually configured different identity in the backup directory, timecapsule won't overwrite it.

To reset:

```bash
cd ~/.timecapsule
git config user.email "timecapsule@local"
git config user.name "Timecapsule"
```

### Push failures

- Ensure a remote named `origin` exists in the backup repo
- Verify you have push access
- Check `notify.failure` is enabled to see error messages

### Pattern matching surprises

- Patterns match the **full file path** relative to the working directory
- `*.swp` excludes files ending in `.swp` anywhere in the tree
- `node_modules/**` excludes everything under `node_modules/`
- Default exclusions always apply first — `file_patterns` can only add further inclusions/exclusions

## FAQ

**Can I disable backup for specific files?**

Yes — use `file_patterns` with `!` exclusion:

```lua
file_patterns = { "*", "!*.log", "!__pycache__/**" }
```

**Does it back up unnamed buffers?**

No. Unnamed buffers (new files with no path) are skipped.

**Does it commit to a remote?**

By default, no. The backup repo is local. Set `push.enable = true` to auto-push after each commit.

**Is there a dry-run mode?**

Not currently. Toggle backup off with `:TimecapsuleToggle` if you want to experiment without creating commits.

## Contributing

1. **Tests** — Plenary test harness. Run with:
   ```bash
   nvim --headless -c "PlenaryBustedDirectory tests/" -c "qa"
   ```

2. **Lint** — Run before committing:
   ```bash
   stylua --check .
   luacheck lua/
   ```

3. **CI** — Local execution via [nektos/act](https://github.com/nektos/act):
   ```bash
   act -j test    # run tests
   act -j lint    # run linters
   act            # run all
   ```

4. **Pull requests** — Welcome! Please include tests for new behavior.

## License

MIT
