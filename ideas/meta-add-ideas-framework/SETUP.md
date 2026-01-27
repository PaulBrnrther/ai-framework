# Setup Instructions

## Add Commands to PATH

To use the `idea` and `add-idea` commands from anywhere, add the commands directory to your PATH.

### Option 1: Add to your shell profile

Add this line to your `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$PATH:/Users/paulbaernreuther/ai/framework/commands"
```

Then reload your shell:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

### Option 2: Create symlinks (alternative)

```bash
ln -s /Users/paulbaernreuther/ai/framework/commands/idea /usr/local/bin/idea
ln -s /Users/paulbaernreuther/ai/framework/commands/add-idea /usr/local/bin/add-idea
```

## Verify Installation

Test that the commands are available:

```bash
which idea
which add-idea
```

## Usage Examples

### Using the high-level `idea` command:

```bash
idea "We could implement a token refresh mechanism to keep users logged in automatically"
```

### Using the low-level `add-idea` command directly:

```bash
add-idea "token_refresh_mechanism" "Implement automatic token refresh to keep users logged in"
```

## Requirements

- `jq` or `python3` for JSON parsing
- Claude Code CLI (`claude` command available)
