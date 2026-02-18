# Source this file in .zshrc:
#   source /Users/paulbaernreuther/ai/framework/commands/ticket/ticket-shell-function.zsh

# Initialize ACTIVE_TICKET from .active-ticket on shell startup
if [ -f ~/.active-ticket ]; then
  export ACTIVE_TICKET=$(cat ~/.active-ticket)
fi

# Shell function wrapper — evals script output to set env vars / cd in current shell
# Use TICKET_GLOBAL=1 to also write ~/.active-ticket (system-wide focus).
# The uppercase alias `T` sets this automatically.
_ticket_impl() {
  # If the current directory no longer exists (e.g. a deleted worktree), move home
  # before spawning any subprocess — otherwise getcwd() failures pollute all output.
  if ! builtin pwd > /dev/null 2>&1; then
    cd "$HOME"
  fi

  local SCRIPT_DIR="/Users/paulbaernreuther/ai/framework/commands/ticket"
  local cmd="${1:-}"
  local script
  local uses_fzf=false

  case "$cmd" in
    add-repo)
      shift
      script="$SCRIPT_DIR/ticket-add-repo"
      # No args → fzf picker for repo selection
      if [ $# -eq 0 ]; then
        uses_fzf=true
      fi
      ;;
    status)
      shift
      script="$SCRIPT_DIR/ticket-status"
      ;;
    workingset)
      shift
      script="$SCRIPT_DIR/ticket-workingset"
      ;;
    fetch-jars)
      shift
      script="$SCRIPT_DIR/ticket-fetch-jars"
      ;;
    sync-plugins)
      shift
      script="$SCRIPT_DIR/ticket-sync-plugins"
      ;;
    plugins)
      shift
      script="$SCRIPT_DIR/ticket-plugins"
      uses_fzf=true
      ;;
    plugins-delete)
      shift
      script="$SCRIPT_DIR/ticket-plugins-delete"
      uses_fzf=true
      ;;
    repo-delete)
      shift
      script="$SCRIPT_DIR/ticket-repo-delete"
      uses_fzf=true
      ;;
    jira)
      shift
      script="$SCRIPT_DIR/ticket-jira"
      if [ $# -eq 0 ]; then
        uses_fzf=true
      fi
      ;;
    done|delete)
      shift
      script="$SCRIPT_DIR/ticket-done"
      ;;
    pr)
      shift
      script="$SCRIPT_DIR/ticket-pr"
      uses_fzf=true
      ;;
    pull)
      shift
      script="$SCRIPT_DIR/ticket-pull"
      ;;
    eclipse)
      shift
      # Refuse if the terminal's active ticket doesn't match the global one
      local global_ticket=""
      [ -f ~/.active-ticket ] && global_ticket=$(cat ~/.active-ticket)
      if [ "${ACTIVE_TICKET:-}" != "$global_ticket" ]; then
        echo "Error: terminal ticket ($ACTIVE_TICKET) != global ticket ($global_ticket)" >&2
        echo "Run 'T' to switch globally first, or 'T $ACTIVE_TICKET' to set it." >&2
        return 1
      fi
      _ticket_impl sync-plugins "$@"
      _ticket_impl fetch-jars "$@"
      _ticket_impl workingset "$@"
      return
      ;;
    repo)
      shift
      script="$SCRIPT_DIR/ticket-repo"
      uses_fzf=true
      ;;
    switch)
      shift
      script="$SCRIPT_DIR/ticket-switch"
      uses_fzf=true
      ;;
    "")
      script="$SCRIPT_DIR/ticket-switch"
      uses_fzf=true
      ;;
    *)
      script="$SCRIPT_DIR/ticket"
      ;;
  esac

  if $uses_fzf; then
    # fzf needs stdout for its UI, so scripts write eval commands to a temp file
    local eval_file=$(mktemp)
    TICKET_EVAL_FILE="$eval_file" TICKET_GLOBAL="${TICKET_GLOBAL:-0}" "$script" "$@"
    local rc=$?
    if [ $rc -eq 0 ] && [ -f "$eval_file" ] && [ -s "$eval_file" ]; then
      eval "$(cat "$eval_file")"
      # If switch couldn't find a matching worktree, trigger repo picker
      # Preserve TICKET_GLOBAL so uppercase T flows through to repo picker
      if [ "${TICKET_NEEDS_REPO:-}" = "1" ]; then
        unset TICKET_NEEDS_REPO
        TICKET_GLOBAL="${TICKET_GLOBAL}" _ticket_impl repo
      fi
      if [ "${TICKET_NEEDS_ADD_REPO:-}" = "1" ]; then
        unset TICKET_NEEDS_ADD_REPO
        TICKET_GLOBAL="${TICKET_GLOBAL}" _ticket_impl add-repo
      fi
    fi
    rm -f "$eval_file"
    return $rc
  else
    local output
    output=$(TICKET_GLOBAL="${TICKET_GLOBAL:-0}" "$script" "$@")
    local rc=$?
    if [ $rc -eq 0 ] && [ -n "$output" ]; then
      eval "$output"
      if [ "${TICKET_NEEDS_ADD_REPO:-}" = "1" ]; then
        unset TICKET_NEEDS_ADD_REPO
        TICKET_GLOBAL="${TICKET_GLOBAL}" _ticket_impl add-repo
      fi
    fi
    return $rc
  fi
}

ticket() { TICKET_GLOBAL=0 _ticket_impl "$@"; }
Ticket() { TICKET_GLOBAL=1 _ticket_impl "$@"; }
alias t=ticket
alias T=Ticket
alias tws='ticket workingset'
alias tfj='ticket fetch-jars'
alias tsp='ticket sync-plugins'
alias td='ticket done'
alias te='ticket eclipse'
alias tp='ticket plugins'
alias tpd='ticket plugins-delete'
alias trd='ticket repo-delete'
alias tj='ticket jira'
alias Tj='Ticket jira'

# TST — show status for ALL tickets
TST() {
  local orig_ticket="${ACTIVE_TICKET:-}"
  local script_dir="/Users/paulbaernreuther/ai/framework/commands/ticket"
  for yaml in ~/.tickets/*.yaml; do
    [ -f "$yaml" ] || continue
    local ticket_name=$(basename "$yaml" .yaml)
    ACTIVE_TICKET="$ticket_name" "$script_dir/ticket-status"
    echo "" >&2
  done
  ACTIVE_TICKET="$orig_ticket"
}
alias tpU='ticket pull'
alias tpr='ticket pr'

# Ticket-aware Claude launcher
# Uses $ACTIVE_TICKET (per-terminal), launches claude from the ticket's notes dir
# with --add-dir for all worktrees. Falls back to plain claude if no active ticket.
tc() {
  if [ -z "${ACTIVE_TICKET:-}" ]; then
    claude "$@"
    return
  fi

  local SCRIPT_DIR="/Users/paulbaernreuther/ai/framework/commands/ticket"
  local yaml="$HOME/.tickets/$ACTIVE_TICKET.yaml"
  if [ ! -f "$yaml" ]; then
    claude "$@"
    return
  fi

  local branch=$(grep -E '^\s{2}([a-z]+/)?[A-Z]+-[0-9]+-' "$yaml" | head -1 | sed 's/://;s/^[[:space:]]*//')
  local ticket_dir="$HOME/knime/tickets/$branch"
  local repos_dir="$HOME/knime/repos"

  # Collect worktree paths
  local add_dirs=()
  while IFS= read -r repo; do
    local wt="$repos_dir/$repo.git/branches/$branch"
    [ -d "$wt" ] && add_dirs+=("$wt")
  done < <("$SCRIPT_DIR/parse-ticket-repos" "$yaml" "$branch")

  # Ensure notes dir exists (used as main workspace)
  mkdir -p "$ticket_dir"

  # Write project-level settings with only ticket worktrees
  # (overrides global additionalDirectories so ~/knime/repos isn't included)
  mkdir -p "$ticket_dir/.claude"
  local dirs_json="["
  local first=true
  for d in "${add_dirs[@]}"; do
    $first || dirs_json+=","
    dirs_json+="\"$d\""
    first=false
  done
  dirs_json+="]"
  cat > "$ticket_dir/.claude/settings.json" <<SETTINGS
{
  "permissions": {
    "additionalDirectories": $dirs_json
  }
}
SETTINGS

  # Write project-level CLAUDE.md with ticket context instructions + Jira description
  {
    cat <<'CLAUDEMD'
# Ticket Context

The additional directories provided to this session are worktrees of all repos currently added to this ticket. These are the **only** directories you should search and modify for project code.

If you need code from a repo that is not among the provided directories, **do not** attempt to locate or access it yourself. Instead, ask the user to add the repo to the ticket first (via `ticket add-repo <repo>` / `ta <repo>`) and restart the session.
CLAUDEMD
    if [ -f "$ticket_dir/JIRA.md" ]; then
      echo ""
      cat "$ticket_dir/JIRA.md"
    fi
  } > "$ticket_dir/CLAUDE.md"

  (cd "$ticket_dir" && claude "$@")
}
