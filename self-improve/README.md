# Self-Improve

Tools for the self-improvement process described in the framework. These support reviewing past work and extracting learnings at dedicated intervals.

## Available Commands

### `list-conversations`

Lists Claude conversations since a given date, grouped by project.

```
Usage: list-conversations [date]

  date: optional, e.g. "2026-01-27", "3 days ago", "yesterday"
        Defaults to "today" if omitted.
```

**Data source:** `~/.claude/history.jsonl`
