#!/usr/bin/env bash
# ticket-lib.sh — shared constants and functions for ticket scripts.
# Source this file at the top of each script:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ticket-lib.sh"

TICKET_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TICKETS_DIR="$HOME/.tickets"
REPOS_DIR="$HOME/knime/repos"
REMOTE_BASE="git@github.com:knime"

# ticket_yaml_file <ticket>
#   Echoes the path to the ticket's YAML file.
ticket_yaml_file() {
  echo "$TICKETS_DIR/$1.yaml"
}

# ticket_dir <branch>
#   Echoes the ticket notes directory path and ensures it exists.
ticket_dir() {
  local dir="$HOME/knime/tickets/$1"
  mkdir -p "$dir"
  echo "$dir"
}

# set_active_ticket <ticket> [--global]
#   Updates MRU, and if --global: writes ~/.active-ticket + updates symlinks.
set_active_ticket() {
  local ticket="$1"
  local global=false
  if [ "${2:-}" = "--global" ] || [ "${TICKET_GLOBAL:-0}" = "1" ]; then
    global=true
  fi

  if $global; then
    echo "$ticket" > ~/.active-ticket
    "$TICKET_LIB_DIR/update-symlinks" "$ticket"
  fi
  "$TICKET_LIB_DIR/update-recent" "$ticket"
}

# clear_active_ticket
#   Removes ~/.active-ticket.
clear_active_ticket() {
  rm -f ~/.active-ticket
}

# require_eval_file
#   Guards that TICKET_EVAL_FILE is set. Call at the top of fzf-based scripts.
require_eval_file() {
  if [ -z "${TICKET_EVAL_FILE:-}" ]; then
    echo "Error: TICKET_EVAL_FILE not set (should be called via ticket shell function)" >&2
    exit 1
  fi
}

# ticket_ansi_color <chrome-color-name>
#   Returns an ANSI escape code for the given Chrome tab group color name.
#   Outputs the reset code for unknown/missing colors.
ticket_ansi_color() {
  case "${1:-}" in
    blue)   printf '\033[94m' ;;
    red)    printf '\033[91m' ;;
    yellow) printf '\033[93m' ;;
    green)  printf '\033[92m' ;;
    pink)   printf '\033[95m' ;;
    purple) printf '\033[95m' ;;
    cyan)   printf '\033[96m' ;;
    orange) printf '\033[33m' ;;
    *)      printf '\033[0m'  ;;
  esac
}

# ticket_tab_color <ticket>
#   Returns the color for the ticket. New tickets store their color in the ticket YAML.
#   Falls back to ~/.tickets/.color-assignments for legacy tickets that predate YAML color support.
ticket_tab_color() {
  local ticket="$1"
  local yaml_file
  yaml_file=$(ticket_yaml_file "$ticket")

  # Check YAML first (new tickets have color stored there)
  if [ -f "$yaml_file" ]; then
    local yaml_color
    yaml_color=$(grep -E '^color:' "$yaml_file" | head -1 | sed 's/^color:[[:space:]]*//' | command tr -d '"' || true)
    if [ -n "$yaml_color" ]; then
      echo "$yaml_color"
      return
    fi
  fi

  # Fall back to .color-assignments for legacy tickets
  local colors=(blue red yellow green pink purple cyan orange)
  local assignments_file="$TICKETS_DIR/.color-assignments"

  if [ -f "$assignments_file" ]; then
    local existing
    existing=$(grep "^${ticket}=" "$assignments_file" 2>/dev/null | cut -d= -f2 || true)
    if [ -n "$existing" ]; then
      echo "$existing"
      return
    fi
  fi

  # Count existing assignments to get next index
  local count=0
  if [ -f "$assignments_file" ]; then
    count=$(grep -c '=' "$assignments_file" 2>/dev/null || true)
  fi

  local color="${colors[$(( count % 8 ))]}"
  mkdir -p "$TICKETS_DIR"
  echo "${ticket}=${color}" >> "$assignments_file"
  echo "$color"
}

# create_ticket_yaml <yaml_file> <ticket> <name> <branch> [<repo>...]
#   Creates a ticket YAML with color assigned. Repos are optional.
create_ticket_yaml() {
  local yaml_file="$1" ticket="$2" name="$3" branch="$4"
  shift 4
  local repos=("$@")

  local color
  color=$(ticket_tab_color "$ticket")

  local repos_block
  if [ ${#repos[@]} -eq 0 ]; then
    repos_block="    repos: {}"
  else
    repos_block="    repos:"
    for repo in "${repos[@]}"; do
      repos_block+="
      ${repo}:
        plugins: []"
    done
  fi

  mkdir -p "$(dirname "$yaml_file")"
  cat > "$yaml_file" <<EOF
ticket: $ticket
name: "$name"
color: $color
branches:
  $branch:
$repos_block
EOF
}

# ticket_tab_group <ticket> <yaml_file>
#   Echoes the tab group name: "<TICKET> <human name from YAML>"
ticket_tab_group() {
  local ticket="$1"
  local yaml_file="$2"
  local name
  name=$(grep -E '^name:' "$yaml_file" | head -1 | sed 's/^name:[[:space:]]*//' | sed 's/^"//;s/"$//')
  echo "$ticket $name"
}

# ensure_bare_repo <repo>
#   Clones bare repo if it doesn't exist, fixes fetch refspec, copies shared hooks.
ensure_bare_repo() {
  local repo="$1"
  local bare_repo="$REPOS_DIR/$repo.git"

  if [ ! -d "$bare_repo" ]; then
    echo "Cloning bare repo: $repo..." >&2
    git clone --bare "$REMOTE_BASE/$repo.git" "$bare_repo" >&2
    git -C "$bare_repo" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    local shared_hooks="$REPOS_DIR/remember-local/hooks"
    if [ -d "$shared_hooks" ]; then
      cp -a "$shared_hooks"/. "$bare_repo/hooks" >&2
      echo "Copied git hooks from $shared_hooks" >&2
    fi
  fi
}

# ensure_worktree <repo> <branch> [--skip-on-missing|--create-from-master]
#   Fetches origin, creates worktree if missing, sets upstream tracking.
#   --skip-on-missing: returns 1 if branch not found anywhere (ticket-jira behavior)
#   --create-from-master: creates branch from origin/master if not found (default)
#   Returns 0 on success, 1 if skipped.
#   Sets WORKTREE_PATH as a side effect.
ensure_worktree() {
  local repo="$1"
  local branch="$2"
  local mode="${3:---create-from-master}"
  local bare_repo="$REPOS_DIR/$repo.git"
  WORKTREE_PATH="$bare_repo/branches/$branch"

  if [ -d "$WORKTREE_PATH" ]; then
    echo "  Worktree exists: $repo" >&2
    return 0
  fi

  git -C "$bare_repo" fetch origin >&2 2>&1 || true

  if git -C "$bare_repo" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    git -C "$bare_repo" worktree add "$WORKTREE_PATH" "$branch" >&2
  elif git -C "$bare_repo" show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
    git -C "$bare_repo" worktree add "$WORKTREE_PATH" "$branch" >&2
  elif [ "$mode" = "--create-from-master" ]; then
    git -C "$bare_repo" worktree add --no-track -b "$branch" "$WORKTREE_PATH" origin/master >&2
  else
    echo "  Warning: branch $branch not found in $repo, skipping worktree" >&2
    return 1
  fi

  # Set upstream tracking if the branch exists remotely
  local current_upstream
  current_upstream=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null || echo "")
  if [ -z "$current_upstream" ]; then
    if git -C "$bare_repo" show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
      git -C "$WORKTREE_PATH" branch --set-upstream-to="origin/$branch" >&2
    fi
  fi

  echo "  Worktree created: $repo" >&2

  # Run post-worktree-create hook if present
  local hook="$bare_repo/hooks/post-worktree-create"
  if [ -x "$hook" ]; then
    echo "  Running post-worktree-create hook for $repo..." >&2
    (cd "$WORKTREE_PATH" && "$hook" 2>&1) >&2 || echo "  Warning: post-worktree-create hook failed (exit $?)" >&2
  fi

  return 0
}
