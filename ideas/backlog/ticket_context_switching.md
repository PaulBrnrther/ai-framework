# Ticket Context Switching

## Origin Ideas
- `ticket_scoped_environments_with_templates.md`
- `eclipse_working_sets_cli_management.md`
- `claude_code_standalone_with_ide_environment.md`

## Goal

Enable fast, seamless switching between ticket contexts across the entire development toolchain — terminal, Claude Code, Eclipse, and VS Code — with a single command like `ticket UIEXT-1234`.

## Spec

### Core: Git Worktrees

- A command creates git worktrees in all relevant repos for a given ticket (e.g., `ticket UIEXT-1234` creates worktrees in `knime-core-ui`, `knime-excel`, etc.)
- Which repos are relevant can be specified per invocation or derived from templates for recurring patterns (e.g., a "cross-repo KNIME refactor" template)

### Active Ticket Tracking

- The system tracks which ticket is currently active via an environment variable
- Multiple tickets may be active simultaneously
- A Claude Code instance is always started with the active ticket environment variable set, so the agent automatically operates in the correct worktrees

### IDE Integration via Symlinks

- Stable symlink directories point to the active ticket's worktrees
- These symlinks are imported into IDEs so switching tickets updates what the IDE sees without reconfiguring it each time

### Eclipse: Working Sets

- Programmatically create/update Eclipse Working Sets for the active ticket
- Working sets are managed by editing `.metadata/.plugins/org.eclipse.ui.workbench/workingsets.xml` (Eclipse must be stopped)
- Each ticket gets a working set containing its relevant projects

### VS Code

- No special handling needed — typically only one repo is open per VS Code instance, so just opening the worktree directory is sufficient

### Teardown

- When a ticket is done, clean up: delete worktrees, remove symlinks, archive/remove working sets
- Details TBD

## Open Questions

- What's the exact UX for specifying which repos a ticket needs? Interactive prompt? Config file? Template selection?
- How do templates get defined and stored?
- Should teardown be manual or automatic (e.g., when a branch is merged)?
- How does this interact with the framework's environment concept — is a ticket context just a specialization of an environment?
