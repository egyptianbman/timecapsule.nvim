# timecapsule.nvim

Automatic backup plugin for Neovim that copies files to a backup repository on write, maintaining the full directory structure.

## How It Works

When you write a file in Neovim, timecapsule.nvim:
1. Copies the file to the configured backup directory
2. Preserves the full relative path structure
3. Initializes a git repository in the backup directory if needed
4. Stages and commits the file with a descriptive message

Example: If you edit `/etc/config.conf`, it gets backed up to `~/.backup/etc/config.conf`.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "egyptianbman/timecapsule.nvim",
  opts = {
    backup = vim.fn.stdpath('data') .. '/timecapsule',
    enable = true,
    message_format = 'auto: {path}',
    push = {
      enable = false,
      branch = 'main',
    },
    notify = {
      success = false,
      failure = true,
    },
  },
}
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `backup` | string | `nil` | Backup directory path (required) |
| `enable` | boolean | `true` | Enable/disable auto-backup |
| `file_patterns` | string[] | nil | `nil` | File patterns to include; replaces default exclusions when set (use `!` prefix for exclusions) |
| `message_format` | string | `"auto: {path}"` | Commit message format with `{path}` placeholder |
| `push.enable` | boolean | `false` | Enable auto-push after commit |
| `push.branch` | string | `"main"` | Remote branch to push to |
| `notify.success` | boolean | `false` | Show success notifications |
| `notify.failure` | boolean | `true` | Show failure notifications |

### File Patterns

Use wildcard patterns with `*`. When `file_patterns` is set, it **replaces** the default exclusions entirely. Add `!` prefix for exclusions:

- `{'*.lua'}` - Only stage Lua files (no default exclusions)
- `{'*', '!*.swp', '!*.log'}` - Stage all files except swaps and logs
- `{'*.js', '!node_modules/**', '!*.min.js'}` - JS files excluding specific patterns

### Default Exclusions

When `file_patterns` is not set, these patterns are excluded by default:
```
package-lock.json, yarn.lock, pnpm-lock.yaml, Cargo.lock, go.sum, 
Pipfile.lock, poetry.lock, Gemfile.lock, composer.lock,
node_modules/, vendor/, .venv/, build/, dist/, out/, 
.next/, .nuxt/, .angular/, __pycache__/, .DS_Store, 
Thumbs.db, .idea/, .vscode/, *.log, *.tmp, *.swp, 
*.swo, .cache/, coverage/
```

## Usage

### Toggle Auto-Backup

`:TimecapsuleToggle` - Enable/disable auto-backup

### Manual Backup

You can test the backup by editing any file and writing it (`:w` or `Ctrl+O`). The file will be copied to the backup directory and committed.

## Workflow

1. Edit files normally in Neovim
2. On write, files are automatically backed up
3. Check backup directory for copied files
4. Review git history in backup directory for version tracking

## Requirements

- Neovim 0.10+
- Git

## Notes

- The backup directory is initialized as a git repository automatically
- Each file maintains its relative path structure from the working directory
- Backups are local; configure `push` to sync to remote if needed

## License

MIT
