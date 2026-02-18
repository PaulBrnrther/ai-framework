# AI Framework

## Purpose

This repository maintains the usage of AI agents (currently: Claude Code) and provides a framework for iterating their environment after given time intervals (e.g., every end-of-day).

## Main Functionalities

### (a) Framework Setup

The framework defines the general setup on the computer, addressing questions like:

- Where do I want to create new helper-tools?
- How do I manage the environment?
- How do I handle multiple environments (if needed)?
- How do I create a new environment?

This is the **product** that this repository ships.

### (b) Self-Improvement Process

A system for continuously improving the framework itself, supporting improvements ranging from small to groundbreaking:

- **Small notes**: Capture ideas for future improvements
- **Reusable tools**: Extract tools that might be useful in other circumstances
- **Environments**: Create dedicated setups for specific tasks

**Workflow:**
- During regular work: Improvements can be issued manually when something reusable is identified ("hey, this might be useful elsewhere, let's make it reusable")
- Manual improvements during development should not be relied upon too heavily here, as they can become a side-track
- Thus: At dedicated intervals: Actively review, clean up, and develop ideas that originated from conversations since the last review session

The time interval (e.g., end-of-day) serves as the point to both:
- Review what happened
- Extract learnings
- Run the self-improvement process (modifying/adding tools, environments, etc.)

(In the future, this might be largely automated, resulting in a PR to review the next morning)

## Terminology

These terms are used consistently throughout, though their precise definitions will evolve:

- **Environment**: Umbrella term for all things that can be set up before starting a conversation with an agent:
  - System prompts
  - **Tool**:
    - Documentation (e.g. specific on-demand Prompts)
    - Commands (deterministic helpers (e.g. MCPs but also just terminal commands))
    - Agents (non-deterministic helpers)
  - Permissions (to perform specific actions without asking; access to specific repos)

## Ticket Context Switching (In Progress)

A system for managing multiple concurrent ticket contexts across terminal, Claude Code, and IDEs.

### Current State

Scripts live in `commands/ticket/` and are sourced from `~/.zshrc`.

### Commands

| Command | Alias | Description |
|---|---|---|
| `ticket <branch>` | `t <branch>` | Create a new ticket from a branch name (e.g., `t enh/UIEXT-1234-fix-the-koala-bug`) |
| `ticket` (no args) | `t` | Switch between active tickets (fzf picker) |
| `ticket repo` | `tr` | Switch between repos of the active ticket (fzf picker). Creates worktree on the fly if needed. |
| `ticket add-repo <repo>` | `ta <repo>` | Add a repo to the active ticket. Clones bare repo + creates worktree. |
| `ticket status` | `tst` | Show active ticket state (repos, branches, modified plugins) |
| `ticket sync-plugins` | `tsp` | Detect modified plugins (vs merge-base with master) and add to YAML |
| `ticket fetch-jars` | `tfj` | Run `mvn clean package` in `lib/fetch_jars/` for plugins that need it |
| `ticket workingset` | `tws` | Create/update Eclipse working set (symlinks are auto-managed on ticket switch) |
| `ticket pull` | `tpU` | Fetch + hard reset all repos to upstream (confirms if uncommitted changes/unpushed commits) |
| `ticket pr` | `tpr` | Open the GitHub PR for the active ticket's branch in the browser (auto-detects repo from cwd, fzf picker if multiple) |
| `ticket done` | `td` | Tear down a ticket: remove worktrees, symlinks, YAML, and update active ticket |

### Architecture

- **Ticket YAML** (`~/.tickets/<TICKET>.yaml`): Per-ticket state — name, branches, repos, plugins (see schema below)
- **Active ticket** (`~/.active-ticket`): System-wide focused ticket, read on shell startup → `$ACTIVE_TICKET`
- **Recent order** (`~/.tickets/.recent`): MRU-ordered ticket list for the fzf picker
- **Bare repos** (`~/knime/repos/<name>.git`): Git bare clones, worktrees live inside at `worktrees/<branch>/`
- **Repo config** (`~/knime/repos/repos.yaml`): Manually maintained registry of repos, plugins, and frontend packages (not yet populated)

### Git Worktree Setup

Repos are cloned as bare repos (`<name>.git`) with worktrees created inside them:
```
~/knime/repos/
  knime-core-ui.git/           ← bare repo
    worktrees/
      enh/UIEXT-1234-.../      ← worktree per ticket branch
      enh/UIEXT-999-.../
  knime-core-ui/               ← existing clone (to be replaced by symlink later)
```

Bare repos have their fetch refspec fixed to `+refs/heads/*:refs/remotes/origin/*` (bare clones default to only fetching HEAD).

### Ticket YAML Schema

```yaml
ticket: UIEXT-1234
name: Human Readable Name
branches:
  enh/UIEXT-1234-branch-name:
    repos:
      knime-core-ui:
        plugins:
          - org.knime.core.ui                    # simple string format
          - name: org.knime.core.ui.tests        # object format (used when tracking jar state)
            jars_fetched: true
      knime-base:
        plugins:
          - org.knime.base
```

**Plugin formats:**
- **String**: `- org.knime.base` — basic plugin entry
- **Object**: `- name: org.knime.base` with optional `jars_fetched: true` — tracks whether `mvn clean package` was run in `lib/fetch_jars/`

The `jars_fetched` field is set automatically by `ticket fetch-jars` for plugins that have a `lib/fetch_jars/pom.xml`.

### Eclipse Integration

**Working Sets & Symlinks** (`ticket workingset` / `tws`):
- Reads plugins from the active ticket's YAML
- Creates/updates a working set named after the ticket (e.g., "UIEXT-1234") in Eclipse's `workingsets.xml`
- Sets up repo symlinks: `~/knime/repos/<repo>` → worktree for the ticket's branch
- Backs up original repo directories to `~/knime/repos/remember-local/` before symlinking
- Deduplicates plugins across repos
- Must be run while Eclipse is stopped (Eclipse overwrites the file on shutdown)

**Jar Fetching** (`ticket fetch-jars` / `tfj`):
- Some KNIME plugins have `<plugin>/lib/fetch_jars/pom.xml` that must be built to populate `lib/` with dependencies
- Runs `mvn clean package` for each plugin that has this structure and hasn't been fetched yet
- Marks plugins as `jars_fetched: true` in YAML to avoid re-running

### Symlink Setup

`ticket workingset` automatically manages symlinks so Eclipse sees worktree contents:
```
~/knime/repos/
  knime-core-ui.git/           ← bare repo
    worktrees/enh/UIEXT-1234-.../
  knime-core-ui -> knime-core-ui.git/worktrees/enh/UIEXT-1234-.../  ← symlink (auto-created)
  remember-local/              ← backup of original clones (auto-created)
    knime-core-ui/
```

When switching tickets, run `tws` again to update symlinks to point to the new ticket's worktrees.

### Shell Integration

- `commands/ticket/ticket-shell-function.zsh` is sourced in `~/.zshrc`
- Custom zsh prompt: at repo root shows `➜  repo-name (branch)`, in subfolders shows `➜  folder (repo:branch)`
- Commands that need to modify the shell (cd, export) use an eval pattern: scripts output commands to stdout (or a temp file for fzf commands), the shell function evals them

### Not Yet Implemented

- `repos.yaml` population
- Eclipse workspace path in a config file (currently hardcoded)
