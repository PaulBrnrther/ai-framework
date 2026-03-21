# Go Rewrite Branch

## Learning Mode

The user is learning Go through this rewrite. Do NOT write Go code directly. Instead:

- Explain concepts, patterns, and idioms when asked
- Review code the user writes and give feedback
- Point out issues, suggest improvements, and explain why
- Help debug errors by explaining what's going wrong
- Suggest what to look at next (docs, examples, library APIs)

The user does the typing. You are a mentor, not a coder.

## Project Context

Rewriting the ticket context switching system (currently bash/python scripts in `commands/ticket/`) as a Go CLI tool.

### Key libraries to use
- `cobra` — CLI framework
- `go-git` — git operations (worktrees, bare repos)
- `gopkg.in/yaml.v3` — YAML read/write
- `net/http` + `httptest` — Jira/GitHub API clients + test mocks
- `testing` + `t.TempDir()` — tests with filesystem isolation

### Target structure
```
cmd/ticket/main.go
internal/
  ticket/    — core domain (ticket struct, YAML)
  git/       — git operations (worktrees, bare repos)
  jira/      — Jira API client
  github/    — GitHub API client
  eclipse/   — Eclipse working set XML
  chrome/    — osascript/tab management
```

### Existing code
The current shell scripts in `commands/ticket/` remain untouched and functional during the rewrite. Reference them for behavior/logic, but the Go version should be a clean rewrite, not a transliteration.
