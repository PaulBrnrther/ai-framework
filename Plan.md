# Go Rewrite Migration Plan

TDD approach: introduce one concept at a time, write tests as soon as types are available.

---

## Phase 1: Ticket Model + YAML Round-Trip

**Goal:** Define Go structs for the ticket data model and implement YAML marshal/unmarshal. No file I/O — just `yaml.Marshal`/`yaml.Unmarshal` on `[]byte`.

**Types:**

```go
type Ticket struct {
    Key      string              `yaml:"ticket"`
    Name     string              `yaml:"name"`
    Color    string              `yaml:"color"`
    Branches map[string]Branch   `yaml:"branches"`
}

type Branch struct {
    Repos map[string]Repo `yaml:"repos"`
}

type Repo struct {
    Plugins []Plugin `yaml:"plugins"`
}

// Plugin needs custom UnmarshalYAML to handle both formats:
//   - "org.knime.base"                     (string)
//   - name: org.knime.base                 (object)
//     jars_fetched: true
type Plugin struct {
    Name        string `yaml:"name"`
    JarsFetched bool   `yaml:"jars_fetched,omitempty"`
    NoJars      bool   `yaml:"no_jars,omitempty"`
}
```

**Tests:**

- Parse real-world YAML → structs → back to YAML (round-trip)
- Parse both plugin formats (string and object)
- Handle edge cases: empty plugins `[]`, empty repos `{}`
- Color validation (9 allowed values: grey, blue, red, yellow, green, pink, purple, cyan, orange)

**Files:** `internal/model/ticket.go`, `internal/model/ticket_test.go`

---

## Phase 2: Config + Paths

**Goal:** Define a Config struct that holds all base paths. Replaceable for testing via `t.TempDir()`.

**Paths:**

| Field | Default | Example |
|---|---|---|
| TicketsDir | `~/.tickets` | `~/.tickets/UIEXT-1234.yaml` |
| ReposDir | `~/knime/repos` | `~/knime/repos/knime-core-ui.git` |
| ActiveTicketFile | `~/.active-ticket` | — |
| NotesDir | `~/knime/tickets` | `~/knime/tickets/enh/UIEXT-1234-.../JIRA.md` |
| RemoteBase | `git@github.com:knime` | — |

**Helper methods:**

```go
func (c *Config) YAMLPath(ticket string) string
func (c *Config) BareRepoPath(repo string) string
func (c *Config) WorktreePath(repo, branch string) string
func (c *Config) NotesPath(branch string) string
func (c *Config) RecentFile() string           // .recent
func (c *Config) RecentReposFile() string      // .recent-repos
func (c *Config) ColorModeFile() string        // color-mode
```

**Tests (`t.TempDir()`):**

- Each method returns the expected path
- Paths are joined correctly (no double slashes, etc.)

**Files:** `internal/config/config.go`, `internal/config/config_test.go`

---

## Phase 3: State Files (MRU, Active Ticket, Color Mode)

**Goal:** Read/write simple state files. Building on Config from Phase 2.

**MRU list** (`.recent`, `.recent-repos`):

```go
func ReadMRU(path string) ([]string, error)
func TouchMRU(path string, entry string) error   // move to top, deduplicate
func RemoveMRU(path string, entry string) error   // delete entry
```

**Active ticket** (`~/.active-ticket`):

```go
func ReadActiveTicket(path string) (string, error)
func WriteActiveTicket(path string, ticket string) error
func ClearActiveTicket(path string) error
```

**Color mode** (`~/.tickets/color-mode`):

```go
func ReadColorMode(path string) string  // "dark" or "light", defaults to "dark"
```

**Tests (`t.TempDir()`):**

- MRU touch moves existing item to top
- MRU touch on new item prepends it
- MRU remove deletes item, preserves order of rest
- MRU read on missing file returns empty slice
- Active ticket read/write/clear round-trip
- Color mode defaults to "dark" when file missing

**Files:** `internal/state/mru.go`, `internal/state/active.go`, `internal/state/color.go`, `internal/state/*_test.go`

---

## Phase 4: Ticket CRUD Operations

**Goal:** Higher-level operations on ticket YAML files. Builds on Phase 1 (model), Phase 2 (config), Phase 3 (state).

**Functions:**

```go
func CreateTicket(cfg *Config, key, name, branch string, repos ...string) (*Ticket, error)
func LoadTicket(cfg *Config, key string) (*Ticket, error)
func SaveTicket(cfg *Config, t *Ticket) error
func DeleteTicket(cfg *Config, key string) error

func (t *Ticket) AddRepo(branch, repo string)
func (t *Ticket) RemoveRepo(branch, repo string)
func (t *Ticket) AddPlugins(branch, repo string, plugins ...string)
func (t *Ticket) RemovePlugins(branch, repo string, plugins ...string)
func (t *Ticket) SetJarsFetched(branch, repo, plugin string)
func (t *Ticket) SetNoJars(branch, repo, plugin string)
```

**Color assignment:**

- Round-robin from 9 colors, checking existing tickets to avoid immediate repeats

**Tests (`t.TempDir()`):**

- Create ticket → Load → verify all fields
- Add repo → verify YAML structure
- Add plugin (becomes string format) → verify
- Remove plugin → verify it's gone
- Remove repo → verify it's gone
- No duplicate plugins on double-add
- Color assignment cycles through 9 colors
- Delete ticket removes YAML + MRU entry + clears active if it was active

**Files:** `internal/ticket/crud.go`, `internal/ticket/crud_test.go`

---

## Phase 5: Git Operations (Bare Repos + Worktrees)

**Goal:** Git operations using go-git and/or `os/exec` where go-git falls short.

**Functions:**

```go
func EnsureBareRepo(cfg *Config, repo string) error
func EnsureWorktree(cfg *Config, repo, branch string) error
func RemoveWorktree(cfg *Config, repo, branch string) error
func WorktreeStatus(cfg *Config, repo, branch string) (*RepoStatus, error)
func ListWorktrees(cfg *Config, repo string) ([]string, error)

type RepoStatus struct {
    CommitsAhead   int  // ahead of merge-base with origin/master
    AheadUpstream  int
    BehindUpstream int
    DirtyFiles     int
}
```

**Details:**

- `EnsureBareRepo`: clone bare, fix fetch refspec to `+refs/heads/*:refs/remotes/origin/*`, copy hooks from remember-local if available
- `EnsureWorktree`: fetch, create worktree, set upstream tracking
- May need `os/exec` fallback for worktree operations (go-git support is limited)

**Tests (`t.TempDir()` with local git repos):**

- Create local bare repo → verify refspec is fixed
- Create worktree → verify files exist on disk
- Remove worktree → verify it's gone
- Status shows correct ahead/behind/dirty counts
- EnsureBareRepo is idempotent (second call is no-op)
- EnsureWorktree is idempotent

**Files:** `internal/git/repo.go`, `internal/git/worktree.go`, `internal/git/status.go`, `internal/git/*_test.go`

---

## Phase 6: Symlink Management

**Goal:** Manage `~/knime/repos/<repo>` symlinks pointing to active ticket's worktrees.

**Functions:**

```go
func UpdateSymlinks(cfg *Config, ticket *Ticket) error
func BackupOriginal(cfg *Config, repo string) error
func RestoreOriginal(cfg *Config, repo string) error
```

**Behavior:**

- For each repo in ticket YAML: `~/knime/repos/<repo>` → `~/knime/repos/<repo>.git/branches/<branch>/`
- If `<repo>` is a real directory (not symlink): move to `remember-local/<repo>` first
- Skip if symlink already points to correct target
- Handle missing worktree gracefully (warn, don't fail)

**Tests (`t.TempDir()`):**

- Create symlink → verify target
- Update symlink to new target → verify
- Backup real dir → verify moved to remember-local
- Skip if symlink already correct (idempotent)
- Missing worktree → error or warning

**Files:** `internal/symlink/symlink.go`, `internal/symlink/symlink_test.go`

---

## Phase 7: GitHub API (Find Branches)

**Goal:** Search GitHub for branches matching a ticket key across repos. Replaces `find-ticket-branches`.

**Functions:**

```go
type RepoBranch struct {
    Repo   string
    Branch string
}

func FindBranches(ticketKey string, org string) ([]RepoBranch, error)
```

**Details:**

- GitHub GraphQL API via `net/http` (or `gh` CLI as fallback)
- Batch repos: 25 per GraphQL query using aliasing
- Filter: only repos with `pushedAt` within last year
- Returns all repos that have a branch containing the ticket key

**Tests (`httptest.NewServer`):**

- Mock GraphQL response → verify parsed results
- Multiple repos with matching branches
- No matches → empty slice
- Handles pagination/batching correctly

**Files:** `internal/github/branches.go`, `internal/github/branches_test.go`

---

## Phase 8: Jira API (Find Tickets, Fetch Context)

**Goal:** Query Jira for tickets and fetch descriptions. Replaces `find-jira-tickets` and Jira parts of `ticket-jira`.

**Types & Functions:**

```go
type JiraTicket struct {
    Key       string
    Status    string
    Summary   string
    IssueType string
}

type JiraContext struct {
    Description      string
    StepsToReproduce string
    Parent           *JiraTicket
    Siblings         []JiraTicket
}

func FindTickets(cfg *JiraConfig, filter TicketFilter) ([]JiraTicket, error)
func FetchContext(cfg *JiraConfig, key string) (*JiraContext, error)
func WriteContextFiles(notesDir string, ctx *JiraContext) error
```

**Details:**

- Auth: `KNIME_ATLASSIAN_EMAIL` + `KNIME_ATLASSIAN_API_TOKEN`
- Status priority sorting: Resolved > Awaiting merge > In Progress > In Backlog > New > On Hold
- Writes `JIRA.md`, `parent-ticket/<KEY>.md`, `sibling-tickets/<KEY>.md`

**Tests (`httptest.NewServer`):**

- Mock Jira response → verify parsed tickets
- Status priority sorting is correct
- Subtask → parent + siblings fetched
- Missing fields handled gracefully
- WriteContextFiles creates expected file structure

**Files:** `internal/jira/client.go`, `internal/jira/context.go`, `internal/jira/*_test.go`

---

## Phase 9: Color System (ANSI Codes + Ticket Colors)

**Goal:** Terminal color output for ticket display. Replaces `ticket_ansi_color` from `ticket-lib.sh`.

**Functions:**

```go
func TicketANSI(colorName string, mode string) string  // returns raw ANSI escape

// 9 colors × 2 modes
// Dark:  kGoogle*300 (e.g., blue → \033[38;5;111m)
// Light: kGoogle*600/700 (e.g., blue → \033[38;5;33m)
```

**Integration with `fatih/color`** for general styling (bold, dim, green, cyan, etc.) in command output like `ticket status`.

**Tests:**

- Each of 9 color names returns valid ANSI code in dark mode
- Each of 9 color names returns valid ANSI code in light mode
- Unknown color returns reset code
- All 18 codes match the values in `ticket-lib.sh`

**Files:** `internal/ui/color.go`, `internal/ui/color_test.go`

---

## Phase 10: Shell Eval Output Pattern

**Goal:** Commands that modify shell state (cd, export) output eval-able commands to stdout.

**Types & Functions:**

```go
type ShellAction struct {
    Dir   string            // cd target
    Env   map[string]string // export KEY=VALUE
    Flags []string          // TICKET_NEEDS_REPO, TICKET_NEEDS_ADD_REPO
}

func (a *ShellAction) Render() string
```

**Output format:**

```bash
export ACTIVE_TICKET=UIEXT-1234; cd /Users/.../knime/tickets/enh/UIEXT-1234-...
```

**Tests:**

- Dir only → `cd /path`
- Env only → `export KEY=VALUE`
- Combined Dir + Env → correct order
- Multiple env vars → all exported
- Flags → `export TICKET_NEEDS_REPO=1`
- Empty action → empty string

**Files:** `internal/shell/action.go`, `internal/shell/action_test.go`

---

## Phase 11: FZF Picker Integration

**Goal:** Interactive selection via fzf (`os/exec`).

**Functions:**

```go
type PickerOpts struct {
    Prompt  string
    Multi   bool
    Header  string
    Preview string  // preview command
}

func Pick(items []string, opts PickerOpts) (string, error)
func PickMulti(items []string, opts PickerOpts) ([]string, error)
```

**Details:**

- Pipes items to fzf stdin
- Connects fzf stderr to os.Stderr (for the UI)
- Captures stdout (selected items)
- Returns error if user cancels (exit code 130)

**Tests:**

- FZF command construction (verify args match opts)
- Input formatting (items joined by `\n`)
- Output parsing (trim whitespace, split for multi-select)
- Note: actual fzf interaction can't be unit tested — integration test only

**Files:** `internal/ui/picker.go`, `internal/ui/picker_test.go`

---

## Phase 12: Wire Up Cobra Commands

**Goal:** Connect all domain logic into cobra subcommands. Each command is thin: parse args/flags → call domain functions → output ShellAction.

**Commands (priority order):**

| Command | Replaces | Key deps |
|---|---|---|
| `ticket` (no args) | `ticket-switch` | FZF, state, CRUD |
| `ticket <branch>` | `ticket` script | CRUD, git |
| `ticket status` | `ticket-status` | CRUD, git status, color |
| `ticket repo` | `ticket-repo` | FZF, CRUD |
| `ticket add-repo <repo>` | `ticket-add-repo` | CRUD, git, symlinks |
| `ticket done` | `ticket-done` | CRUD, git, symlinks |
| `ticket jira` | `ticket-jira` | Jira, GitHub, FZF, CRUD, git |
| `ticket sync-plugins` | `ticket-sync-plugins` | CRUD, git |
| `ticket fetch-jars` | `ticket-fetch-jars` | CRUD, mvn (os/exec) |
| `ticket plugins` | `ticket-plugins` | FZF, CRUD |
| `ticket plugins-delete` | `ticket-plugins-delete` | FZF, CRUD |
| `ticket repo-delete` | `ticket-repo-delete` | FZF, CRUD, git |
| `ticket pull` | `ticket-pull` | CRUD, git |
| `ticket pr` | `ticket-pr` | CRUD, gh CLI |
| `ticket eclipse` | alias chain | sync-plugins + fetch-jars + workingset |

**Structure:** `cmd/ticket/` — one file per command (current pattern).

**Files:** `cmd/ticket/*.go`

---

## Phase 13: Eclipse Integration

**Goal:** Working set management and .location file rewriting. Replaces `ticket-workingset`.

**Functions:**

```go
func UpdateWorkingSet(workspacePath string, ticket string, plugins []string) error
func RewriteLocationFiles(repoDir string) error
func ShutdownEclipse() error
func StartEclipse(workspacePath string, importProjects []string) error
```

**Details:**

- Parse `workingsets.xml` (XML) → add/update working set → write back
- Binary `.location` files: 16-byte header + 2-byte BE length + UTF-8 URI + trailer
  - Rewrite URI: `repos/knime-core.git/branches/enh/...` → `repos/knime-core/`
- Eclipse shutdown/start via `osascript`
- Auto-import new projects with `-importProject` flag

**Tests:**

- Parse workingsets.xml → add working set → verify XML output
- Rewrite .location binary → verify URI changed correctly
- Handle missing Eclipse gracefully

**Files:** `internal/eclipse/workingset.go`, `internal/eclipse/location.go`, `internal/eclipse/*_test.go`

---

## Phase 14: Chrome Tab Group Management

**Goal:** Communicate with Chrome tab manager extension via FIFO. Replaces `tab-open`, `tab-close-group`, `tab-clear*`.

**Functions:**

```go
func OpenTab(group, color string, urls ...string) error
func CloseGroup(group string) error
func ClearUngroupedTabs() error
func ClearIdleTerminalTabs() error  // osascript
```

**Details:**

- FIFO at `~/.tab-manager.fifo`
- Write JSON messages with timeout
- Fallback: if FIFO unavailable, use `open` command for URLs

**Tests:**

- Message format is correct JSON
- Fallback when FIFO missing
- Timeout handling (don't block forever)

**Files:** `internal/tabs/manager.go`, `internal/tabs/manager_test.go`

---

## Phase 15: Shell Function + Prompt Command (Last)

**Goal:** Update zsh integration to call Go binary. Add `ticket prompt` for the zsh prompt.

**Part 1 — Rewrite `ticket-shell-function.zsh`:**

- Replace script calls with Go binary: `ticket-switch` → `ticket switch`, etc.
- Keep eval pattern: shell function evals stdout
- Keep aliases (`t`, `T`, `ta`, etc.)
- Keep `T`/`Ticket` uppercase variants for global mode (pass `--global` flag)

**Part 2 — `ticket prompt` subcommand:**

```go
// Outputs a zsh-formatted prompt string
func promptInfo() string
```

- Detect git repo + branch (handle worktrees: `.git/worktrees/` path)
- Look up ticket color from YAML
- Check active ticket → green repo color if matching
- Output zsh-escaped string with `%{...%}` sequences (NOT fatih/color — raw escapes for zsh)

**Tests:**

- In git repo at root → `repo (branch)` format
- In git repo subfolder → `folder (repo:branch)` format
- Worktree → correct repo name extracted from `.git` path
- Active ticket branch → green repo color
- Non-ticket branch → default blue

**Files:** `cmd/ticket/prompt.go`, `internal/prompt/prompt.go`, `internal/prompt/prompt_test.go`, updated `ticket-shell-function.zsh`
