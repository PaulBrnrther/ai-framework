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
      if [ $# -eq 0 ] || [[ "${1:-}" == -* ]]; then
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
    snapshot-regen)
      shift
      script="$SCRIPT_DIR/ticket-snapshot-regen"
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
tJ() { TICKET_ALL_JIRA=1 ticket jira "$@"; }
TJ() { TICKET_ALL_JIRA=1 Ticket jira "$@"; }
tJb() { TICKET_ALL_JIRA=1 ticket jira -b "$@"; }
TJb() { TICKET_ALL_JIRA=1 Ticket jira -b "$@"; }
tjf() {
  if [ -z "${ACTIVE_TICKET:-}" ]; then
    echo "Error: no active ticket" >&2
    return 1
  fi
  TICKET_CONFIRMED=1 TICKET_FORCE_SYNC=1 ticket jira "$ACTIVE_TICKET" "$@"
}
tju() {
  local ticket="${1:-${ACTIVE_TICKET:-}}"
  if [ -z "$ticket" ]; then
    echo "Error: no active ticket (or pass one, e.g. tju UIEXT-1234)" >&2
    return 1
  fi
  if [ $# -gt 0 ]; then
    shift
  fi
  TICKET_CONFIRMED=1 ticket jira --update-files "$ticket" "$@"
}

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
alias cl='/Users/paulbaernreuther/ai/framework/commands/ticket/tab-clear'
CL() {
  cl "$@"

  # Auto-teardown tickets whose Jira status is Done or Closed
  if [ -z "${KNIME_ATLASSIAN_EMAIL:-}" ] || [ -z "${KNIME_ATLASSIAN_API_TOKEN:-}" ]; then
    return 0
  fi

  local yaml ticket jira_status
  for yaml in "$HOME"/.tickets/*.yaml; do
    [ -f "$yaml" ] || continue
    ticket=$(basename "$yaml" .yaml)
    jira_status=$(curl -s \
      -u "${KNIME_ATLASSIAN_EMAIL}:${KNIME_ATLASSIAN_API_TOKEN}" \
      -H "Accept: application/json" \
      "https://knime-com.atlassian.net/rest/api/3/issue/${ticket}?fields=status" \
      | jq -r '.fields.status.name // ""')
    if [[ "$jira_status" == "Done" || "$jira_status" == "Closed" ]]; then
      echo "Ticket $ticket is $status — tearing down..." >&2
      _ticket_impl done -y "$ticket"
    fi
  done
}
alias tsnap='ticket snapshot-regen'
alias tpU='ticket pull'
alias tpr='ticket pr'
alias j='/Users/paulbaernreuther/ai/framework/commands/ticket/ticket-open-jira'

# jj / jJ — browse Jira tickets NOT yet checked out locally, open in browser (no tab group)
# jj: tickets assigned to me
# jJ: all UIEXT tickets (lazy search like tJ)
_jira_browser() {
  local mode="${1:-assigned}"
  local script_dir="/Users/paulbaernreuther/ai/framework/commands/ticket"
  local jira_base="https://knime-com.atlassian.net/browse"
  local find_cmd prompt

  if [ "$mode" = "all" ]; then
    find_cmd="$script_dir/find-jira-tickets --all-project UIEXT"
    prompt="Jira UIEXT (new)> "
  else
    find_cmd="$script_dir/find-jira-tickets"
    prompt="Jira (new)> "
  fi

  # Build exclusion file: one ticket key per line for tickets already checked out
  local excl_file
  excl_file=$(mktemp)
  find "$HOME/.tickets" -maxdepth 1 -name "*.yaml" 2>/dev/null \
    | sed 's|.*/||;s|\.yaml$||' > "$excl_file"

  local results
  results=$($find_cmd 2>/dev/null | grep -vF -f "$excl_file" || true)

  if [ -z "$results" ]; then
    echo "No new tickets found (all already checked out locally)." >&2
    rm -f "$excl_file"
    return 1
  fi

  local reload_cmd="$find_cmd --search {q} 2>/dev/null | grep -vF -f '$excl_file' || true"

  local choice
  choice=$(echo "$results" | fzf \
    --prompt="$prompt" --height=~20 --reverse --no-sort \
    --delimiter=$'\t' --with-nth=1,2,3 \
    --bind "change:reload($reload_cmd)")

  rm -f "$excl_file"
  [ -z "$choice" ] && return 0

  local ticket
  ticket=$(echo "$choice" | cut -f1)
  open "$jira_base/$ticket"
}

jj() { _jira_browser assigned; }
jJ() { _jira_browser all; }

# Ticket-aware Claude/Copilot launcher
# Uses $ACTIVE_TICKET (per-terminal), launches claude (or copilot with --copilot flag)
# from the ticket's notes dir with relevant worktrees. Falls back to plain launcher if no active ticket.
tc() {
  # Check for --copilot flag
  local use_copilot=false
  local filtered_args=()
  for arg in "$@"; do
    if [ "$arg" = "--copilot" ]; then
      use_copilot=true
    else
      filtered_args+=("$arg")
    fi
  done
  set -- "${filtered_args[@]}"

  local launcher="claude"
  $use_copilot && launcher="copilot"

  if [ -z "${ACTIVE_TICKET:-}" ]; then
    "$launcher" "$@"
    return
  fi

  local SCRIPT_DIR="/Users/paulbaernreuther/ai/framework/commands/ticket"
  local yaml="$HOME/.tickets/$ACTIVE_TICKET.yaml"
  if [ ! -f "$yaml" ]; then
    "$launcher" "$@"
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

  local ticket_context
  ticket_context=$(cat <<'CONTEXT'
# Ticket Context

The additional directories provided to this session are worktrees of all repos currently added to this ticket. These are the **only** directories you should search and modify for project code.

If you need code from a repo that is not among the provided directories, **do not** attempt to locate or access it yourself. Instead, ask the user to add the repo to the ticket first (via `ticket add-repo <repo>` / `ta <repo>`) and restart the session.
CONTEXT
)

  if $use_copilot; then
    # Build --add-dir flags for each worktree
    local add_dir_flags=()
    for d in "${add_dirs[@]}"; do
      add_dir_flags+=(--add-dir "$d")
    done

    # Write .github/copilot-instructions.md with ticket context + explicit repo paths
    mkdir -p "$ticket_dir/.github"
    {
      echo "$ticket_context"
      if [ ${#add_dirs[@]} -gt 0 ]; then
        echo ""
        echo "## Accessible Repositories"
        echo ""
        echo "The following repo worktrees have been added to this session and are available for file access:"
        echo ""
        for d in "${add_dirs[@]}"; do
          echo "- \`$d\`"
        done
      fi
      if [ -f "$ticket_dir/JIRA.md" ]; then
        echo ""
        cat "$ticket_dir/JIRA.md"
      fi
    } > "$ticket_dir/.github/copilot-instructions.md"

    (cd "$ticket_dir" && copilot "${add_dir_flags[@]}" "$@")
  else
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
      echo "$ticket_context"
      if [ ${#add_dirs[@]} -gt 0 ]; then
        echo ""
        echo "## Accessible Repositories"
        echo ""
        echo "The following repo worktrees have been added to this session and are available for file access:"
        echo ""
        for d in "${add_dirs[@]}"; do
          echo "- \`$d\`"
        done
      fi
      if [ -f "$ticket_dir/JIRA.md" ]; then
        echo ""
        cat "$ticket_dir/JIRA.md"
      fi
    } > "$ticket_dir/CLAUDE.md"

    (cd "$ticket_dir" && claude --dangerously-skip-permissions "$@")
  fi
}

# _ticket_from_worktree
#   Resolves ticket from the current git worktree path by matching repo+branch in ~/.tickets/*.yaml.
_ticket_from_worktree() {
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1

  local repos_prefix="$HOME/knime/repos/"
  local rel="${repo_root#$repos_prefix}"
  [ "$rel" = "$repo_root" ] && return 1

  local repo="${rel%%.git/branches/*}"
  [ "$repo" = "$rel" ] && return 1

  local branch="${rel#*.git/branches/}"
  [ -z "$repo" ] && return 1
  [ -z "$branch" ] && return 1
  [ "$branch" = "$rel" ] && return 1

  local yaml ticket
  for yaml in "$HOME"/.tickets/*.yaml; do
    [ -f "$yaml" ] || continue
    if awk -v target_branch="$branch" -v target_repo="$repo" '
      /^branches:[[:space:]]*$/ { in_branches=1; next }
      in_branches && /^  [^[:space:]][^:]*:[[:space:]]*$/ {
        current=$0
        sub(/^  /, "", current)
        sub(/:[[:space:]]*$/, "", current)
        next
      }
      in_branches && current==target_branch && /^      [^[:space:]][^:]*:[[:space:]]*$/ {
        repo=$0
        sub(/^      /, "", repo)
        sub(/:[[:space:]]*$/, "", repo)
        if (repo==target_repo) {
          found=1
          exit 0
        }
      }
      END { exit(found ? 0 : 1) }
    ' "$yaml"; then
      ticket=$(basename "$yaml" .yaml)
      echo "$ticket"
      return 0
    fi
  done

  return 1
}

# _ticket_open_url <url> [ticket]
#   Opens a URL in the provided ticket's Chrome tab group, else active ticket's group, else default browser.
_ticket_open_url() {
  local url="$1"
  local ticket="${2:-${ACTIVE_TICKET:-}}"
  local script_dir="/Users/paulbaernreuther/ai/framework/commands/ticket"
  if [ -n "$ticket" ] && [ -f "$HOME/.tickets/$ticket.yaml" ]; then
    local yaml_file="$HOME/.tickets/$ticket.yaml"
    local color name group
    color=$(grep -E '^color:' "$yaml_file" | head -1 | sed 's/^color:[[:space:]]*//' | command tr -d '"')
    [ -z "$color" ] && color="blue"
    name=$(grep -E '^name:' "$yaml_file" | head -1 | sed 's/^name:[[:space:]]*//' | sed 's/^"//;s/"$//')
    group="$ticket $name"
    "$script_dir/tab-open" "$group" "$color" "$url"
  else
    open "$url"
  fi
}

# gP — git push, overriding the definition in .zshrc to auto-open GitHub PR URL after push.
#       Captures stderr (where git writes remote messages) and opens any "Create a pull request"
#       link in the tab group of the ticket that owns the current worktree path.
gP() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || { echo "Not in a git repo" >&2; return 1; }

  if [[ "$branch" == "master" || "$branch" == "main" ]]; then
    echo "Warning: You are about to force push to $branch!"
    echo "Press enter 3 times to confirm, or Ctrl+C to cancel."
    read -r
    echo "Press enter 2 more times..."
    read -r
    echo "Press enter 1 more time..."
    read -r
  fi

  local upstream
  upstream=$(git rev-parse --symbolic-full-name --abbrev-ref @{u} 2>/dev/null)

  local tmpfile rc=0
  tmpfile=$(mktemp)

  if [ -z "$upstream" ]; then
    echo "No upstream branch set for '$branch'."
    echo -n "Do you want to set and push to origin/$branch? (y/N) "
    local confirm
    read confirm
    if [[ -z "$confirm" || "$confirm" =~ ^[Yy]$ ]]; then
      git push --set-upstream origin "$branch" 2>"$tmpfile"
      rc=$?
    else
      echo "Push aborted."
      rm -f "$tmpfile"
      return 0
    fi
  else
    git push --force-with-lease 2>"$tmpfile"
    rc=$?
  fi

  cat "$tmpfile" >&2

  if [ $rc -eq 0 ]; then
    local url
    url=$(grep -oE 'https://github\.com/[^ ]+/pull/new/[^ ]+' "$tmpfile" | head -1 | command tr -d '\r')
    if [ -z "$url" ]; then
      url=$(gh pr view "$branch" --json url --jq .url 2>/dev/null || true)
    fi
    if [ -n "$url" ]; then
      local worktree_ticket
      worktree_ticket=$(_ticket_from_worktree || true)
      if [ -n "$worktree_ticket" ]; then
        _ticket_open_url "$url" "$worktree_ticket"
      else
        open "$url"
      fi
    fi
  fi

  rm -f "$tmpfile"
  return $rc
}
