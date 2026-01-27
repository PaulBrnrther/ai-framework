# Add Ideas Framework

## Purpose

Provides a terminal-based workflow for capturing ideas that emerge during development conversations, making them easily reviewable during dedicated self-improvement sessions.

## Commands

### `add-idea`

Low-level command that creates an idea markdown file.

**Usage:**
```bash
add-idea <file_name> <body>
```

**Arguments:**
- `file_name`: Snake-case name for the idea file (without .md extension)
- `body`: Description of the idea

**Behavior:**
- Creates a markdown file in `ideas/<file_name>.md`
- Captures timestamp
- Captures location (working directory where command was issued)
- Structures the information in a consistent format

### `idea`

High-level command that uses Claude Code to parse free-text into structured idea format.

**Usage:**
```bash
idea "Free-text description of your idea"
```

**Behavior:**
1. Takes free-text input describing the idea
2. Calls Claude Code to:
   - Generate a good snake_case filename that captures the essence
   - Correct any typos in the text
3. Outputs structured JSON
4. Parses JSON and calls `add-idea` with the extracted arguments

**Example:**
```bash
idea "We could cache user preferances locally to reduce API calls"
```

This would create an idea file named `cache_user_preferences_locally.md` with typos corrected.

## Workflow

1. During development, when an idea emerges: `idea "your free-text thought"`
2. The command captures it automatically in the ideas folder
3. During review sessions, examine ideas and decide which to pursue

## Implementation

Commands are stored in `commands/` directory and should be added to PATH.
