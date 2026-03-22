# Architecture

## Directory Structure

```
internal/                    ← private packages (not importable by other modules)
  model/                     ← shared types: Ticket, Branch, Repo, Plugin
  config/                    ← Config struct + path helpers
  state/                     ← MRU lists, active ticket, color mode
  ticket/                    ← CRUD operations (uses model, config, state)
  git/                       ← bare repos, worktrees, status
  symlink/                   ← repo symlink management
  github/                    ← find branches via GraphQL
  jira/                      ← find tickets, fetch context
  ui/                        ← color system, fzf picker
  shell/                     ← eval output (ShellAction)
  eclipse/                   ← working sets, .location files
  tabs/                      ← Chrome tab group FIFO
  prompt/                    ← zsh prompt output
cmd/
  ticket/                    ← cobra commands (main.go, status.go, etc.)
```

## Package Conventions

- **One package per domain.** Each folder under `internal/` is a self-contained package.
- **`internal/` prefix** ensures these packages are private to this module.
- **File names don't matter** — Go imports by package path, not file name. Organize files by responsibility within a package (e.g., `git/repo.go`, `git/worktree.go`, `git/status.go`).
- **Types live with their behavior.** Don't create a separate `types.go` unless a package has shared types used across many files within it.
- **Test files** use the `_test.go` suffix: `model/ticket_test.go`.

## Where Types Live

**Shared types** (`model/`): `Ticket`, `Branch`, `Repo`, `Plugin` — used across many packages.

**Domain-specific types** stay in their own package:

| Type | Package |
|---|---|
| `Ticket`, `Branch`, `Repo`, `Plugin` | `model/` |
| `Config` | `config/` |
| `RepoStatus` | `git/` |
| `RepoBranch` | `github/` |
| `JiraTicket`, `JiraContext` | `jira/` |
| `ShellAction` | `shell/` |
| `PickerOpts` | `ui/` |

## Dependency Flow

```
cmd/ticket/
  ↓ (imports everything below)
internal/
  ticket/   → model, config, state
  git/      → config
  symlink/  → config, model
  github/   → (net/http only)
  jira/     → (net/http only)
  ui/       → (os/exec for fzf, fatih/color)
  shell/    → (no internal deps)
  eclipse/  → (encoding/xml, os)
  tabs/     → (os, net)
  prompt/   → config, model, state
  state/    → (os only)
  config/   → (path/filepath only)
  model/    → (gopkg.in/yaml.v3 only)
```

Packages at the bottom (`model`, `config`, `state`, `shell`) have no internal dependencies. Packages higher up compose them. `cmd/ticket/` is the only package that imports across domains — each cobra command wires the pieces together.

## Configuration Pattern

**Single overview, local consumption.**

`config/` is the one place to see every configurable value:

```go
// internal/config/config.go
type Config struct {
    TicketsDir       string   // ~/.tickets
    ReposDir         string   // ~/knime/repos
    ActiveTicketFile string   // ~/.active-ticket
    NotesDir         string   // ~/knime/tickets
    RemoteBase       string   // git@github.com:knime
    JiraBaseURL      string   // https://knime-com.atlassian.net
    GitHubOrg        string   // knime
}
```

Each domain package defines its own small config struct (or just takes path arguments) for what it needs:

```go
// internal/git/repo.go — only knows about git-relevant config
type GitConfig struct {
    ReposDir   string
    RemoteBase string
}

// internal/jira/client.go — only knows about Jira-relevant config
type JiraConfig struct {
    Email    string
    APIToken string
    BaseURL  string
}
```

`Config` provides factory methods to build these:

```go
func (c *Config) GitConfig() *git.GitConfig { ... }
func (c *Config) JiraConfig() *jira.JiraConfig { ... }
```

**Why this way:**

- **One place to see everything** — open `config/config.go` for the full picture
- **Packages stay decoupled** — `git/` doesn't import `config/`, it just takes a `GitConfig`
- **Easy to test** — construct a small config struct with `t.TempDir()` paths, no need for the full `Config`
- **Wiring happens in `cmd/`** — `main.go` creates `Config`, passes the right pieces to each package
