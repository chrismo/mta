#!/usr/bin/env bash
# mta-context.sh - MTA context management via SuperDB
#
# Manages multi-ticket assistance context storage using .sup files.
# See: ai-agents/claude/skills/mta/sup-refactor.md for spec.
#
# Usage: mta-context.sh <command> [args]

set -euo pipefail

# Default contexts directory, overridable for testing
CONTEXTS_DIR="${MTA_CONTEXTS_DIR:-$HOME/.claude/contexts}"

# Ensure contexts directory exists
ensure_dir() {
  mkdir -p "$CONTEXTS_DIR"
}

# Get current ISO timestamp
now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Append a record to a .sup file
append_record() {
  local file="$1"
  local record="$2"
  echo "$record" >> "$CONTEXTS_DIR/$file"
}

# Check if super CLI is available
require_super() {
  if ! command -v super &>/dev/null; then
    echo "Error: 'super' CLI not found. Install SuperDB first." >&2
    exit 1
  fi
}

# ==============================================================================
# Commands
# ==============================================================================

cmd_create_context() {
  local ticket="${1:-}"
  local title="${2:-}"

  if [[ -z "$ticket" || -z "$title" ]]; then
    echo "Usage: mta-context.sh create-context <ticket> <title> [--linear-url=...] [--branch=...] [--worktree=...]" >&2
    exit 1
  fi

  shift 2

  # Parse optional flags
  local linear_url="" branch="" worktree=""
  for arg in "$@"; do
    case "$arg" in
      --linear-url=*) linear_url="${arg#*=}" ;;
      --branch=*) branch="${arg#*=}" ;;
      --worktree=*) worktree="${arg#*=}" ;;
    esac
  done

  ensure_dir

  # Build record - always include archived_at:null for consistent schema
  local record="{ticket:\"$ticket\",title:\"$title\",created:\"$(now)\",archived_at:null"
  [[ -n "$linear_url" ]] && record="$record,linear_url:\"$linear_url\""
  [[ -n "$branch" ]] && record="$record,branch:\"$branch\""
  [[ -n "$worktree" ]] && record="$record,worktree:\"$worktree\""
  record="$record}"

  append_record "contexts.sup" "$record"
  echo "Created context: $ticket"
}

cmd_list_contexts() {
  ensure_dir
  if [[ ! -f "$CONTEXTS_DIR/contexts.sup" ]]; then
    echo "No contexts found."
    return 0
  fi
  require_super
  super -f table -c "from '$CONTEXTS_DIR/contexts.sup' | where archived_at is null | sort created desc"
}

cmd_get_context() {
  local ticket="${1:-}"
  if [[ -z "$ticket" ]]; then
    echo "Usage: mta-context.sh get-context <ticket>" >&2
    exit 1
  fi

  ensure_dir
  require_super

  if [[ ! -f "$CONTEXTS_DIR/contexts.sup" ]]; then
    echo "Error: No contexts found" >&2
    exit 1
  fi

  local result
  result=$(super -f table -c "from '$CONTEXTS_DIR/contexts.sup' | where ticket = '$ticket'" 2>/dev/null)

  if [[ -z "$result" ]]; then
    echo "Error: Context not found: $ticket" >&2
    exit 1
  fi

  echo "$result"
}

cmd_join() {
  local ticket="${1:-}"
  local session_id="${2:-}"

  if [[ -z "$ticket" || -z "$session_id" ]]; then
    echo "Usage: mta-context.sh join <ticket> <session-id>" >&2
    exit 1
  fi

  ensure_dir

  # Verify context exists
  if [[ -f "$CONTEXTS_DIR/contexts.sup" ]]; then
    require_super
    local exists
    exists=$(super -f text -c "from '$CONTEXTS_DIR/contexts.sup' | where ticket = '$ticket' | count()" 2>/dev/null || echo "0")
    if [[ "$exists" == "0" ]]; then
      echo "Error: Context not found: $ticket" >&2
      exit 1
    fi
  else
    echo "Error: No contexts exist. Create one first." >&2
    exit 1
  fi

  local record="{ticket:\"$ticket\",session_id:\"$session_id\",joined_at:\"$(now)\",left_at:null}"
  append_record "sessions.sup" "$record"
  echo "Joined: $session_id -> $ticket"
}

cmd_leave() {
  local ticket="${1:-}"
  local session_id="${2:-}"
  local status="${3:-}"
  local note="${4:-}"

  if [[ -z "$ticket" || -z "$session_id" || -z "$status" ]]; then
    echo "Usage: mta-context.sh leave <ticket> <session-id> <status> [note]" >&2
    exit 1
  fi

  ensure_dir
  require_super

  # This is tricky - SuperDB append-only means we need to update in place
  # For now, we'll rewrite the file (or use a different strategy)
  # TODO: Implement proper update logic

  local sessions_file="$CONTEXTS_DIR/sessions.sup"
  if [[ ! -f "$sessions_file" ]]; then
    echo "Error: No sessions found" >&2
    exit 1
  fi

  local temp_file
  temp_file=$(mktemp)
  local found=false
  local now_ts
  now_ts=$(now)

  while IFS= read -r line; do
    if [[ "$line" == *"session_id:\"$session_id\""* && "$line" == *"left_at:null"* ]]; then
      # Update this record
      local new_line
      new_line=$(echo "$line" | sed "s/left_at:null/left_at:\"$now_ts\",status:\"$status\",note:\"$note\"/")
      echo "$new_line" >> "$temp_file"
      found=true
    else
      echo "$line" >> "$temp_file"
    fi
  done < "$sessions_file"

  if [[ "$found" == "false" ]]; then
    rm "$temp_file"
    echo "Error: Active session not found: $session_id" >&2
    exit 1
  fi

  mv "$temp_file" "$sessions_file"
  echo "Left: $session_id ($status)"
}

cmd_list_sessions() {
  local ticket="${1:-}"

  ensure_dir
  if [[ ! -f "$CONTEXTS_DIR/sessions.sup" ]]; then
    echo "No sessions found."
    return 0
  fi

  require_super

  if [[ -n "$ticket" ]]; then
    super -f table -c "from '$CONTEXTS_DIR/sessions.sup' | where ticket = '$ticket' | sort joined_at desc"
  else
    super -f table -c "from '$CONTEXTS_DIR/sessions.sup' | sort joined_at desc"
  fi
}

cmd_add_decision() {
  local ticket="${1:-}"
  local text="${2:-}"

  if [[ -z "$ticket" || -z "$text" ]]; then
    echo "Usage: mta-context.sh add-decision <ticket> <text>" >&2
    exit 1
  fi

  ensure_dir
  local record="{ticket:\"$ticket\",ts:\"$(now)\",text:\"$text\"}"
  append_record "decisions.sup" "$record"
  echo "Decision recorded."
}

cmd_list_decisions() {
  local ticket="${1:-}"

  if [[ -z "$ticket" ]]; then
    echo "Usage: mta-context.sh list-decisions <ticket>" >&2
    exit 1
  fi

  ensure_dir
  if [[ ! -f "$CONTEXTS_DIR/decisions.sup" ]]; then
    echo "No decisions found."
    return 0
  fi

  require_super
  super -f table -c "from '$CONTEXTS_DIR/decisions.sup' | where ticket = '$ticket' | sort ts desc"
}

cmd_add_task() {
  local ticket="${1:-}"
  local text="${2:-}"

  if [[ -z "$ticket" || -z "$text" ]]; then
    echo "Usage: mta-context.sh add-task <ticket> <text>" >&2
    exit 1
  fi

  ensure_dir
  local record="{ticket:\"$ticket\",ts:\"$(now)\",text:\"$text\",status:\"pending\"}"
  append_record "tasks.sup" "$record"
  echo "Task added."
}

cmd_complete_task() {
  local ticket="${1:-}"
  local pattern="${2:-}"

  if [[ -z "$ticket" || -z "$pattern" ]]; then
    echo "Usage: mta-context.sh complete-task <ticket> <task-text-pattern>" >&2
    exit 1
  fi

  ensure_dir

  local tasks_file="$CONTEXTS_DIR/tasks.sup"
  if [[ ! -f "$tasks_file" ]]; then
    echo "Error: No tasks found" >&2
    exit 1
  fi

  local temp_file
  temp_file=$(mktemp)
  local found=false

  while IFS= read -r line; do
    if [[ "$line" == *"$pattern"* && "$line" == *"status:\"pending\""* && "$found" == "false" ]]; then
      local new_line
      new_line=$(echo "$line" | sed 's/status:"pending"/status:"completed"/')
      echo "$new_line" >> "$temp_file"
      found=true
    else
      echo "$line" >> "$temp_file"
    fi
  done < "$tasks_file"

  if [[ "$found" == "false" ]]; then
    rm "$temp_file"
    echo "Error: Pending task not found matching: $pattern" >&2
    exit 1
  fi

  mv "$temp_file" "$tasks_file"
  echo "Task completed."
}

cmd_list_tasks() {
  local ticket="${1:-}"
  local pending_only=false

  # Parse args
  for arg in "$@"; do
    case "$arg" in
      --pending) pending_only=true ;;
      *) ticket="$arg" ;;
    esac
  done

  ensure_dir
  if [[ ! -f "$CONTEXTS_DIR/tasks.sup" ]]; then
    echo "No tasks found."
    return 0
  fi

  require_super

  local query="from '$CONTEXTS_DIR/tasks.sup'"
  [[ -n "$ticket" ]] && query="$query | where ticket = '$ticket'"
  [[ "$pending_only" == "true" ]] && query="$query | where status = 'pending'"
  query="$query | sort ts desc"

  super -f table -c "$query"
}

cmd_add_blocker() {
  local ticket="${1:-}"
  local text="${2:-}"

  if [[ -z "$ticket" || -z "$text" ]]; then
    echo "Usage: mta-context.sh add-blocker <ticket> <text>" >&2
    exit 1
  fi

  ensure_dir
  local record="{ticket:\"$ticket\",ts:\"$(now)\",text:\"$text\",resolved:null}"
  append_record "blockers.sup" "$record"
  echo "Blocker added."
}

cmd_resolve_blocker() {
  local ticket="${1:-}"
  local pattern="${2:-}"

  if [[ -z "$ticket" || -z "$pattern" ]]; then
    echo "Usage: mta-context.sh resolve-blocker <ticket> <blocker-text-pattern>" >&2
    exit 1
  fi

  ensure_dir

  local blockers_file="$CONTEXTS_DIR/blockers.sup"
  if [[ ! -f "$blockers_file" ]]; then
    echo "Error: No blockers found" >&2
    exit 1
  fi

  local temp_file
  temp_file=$(mktemp)
  local found=false
  local now_ts
  now_ts=$(now)

  while IFS= read -r line; do
    if [[ "$line" == *"$pattern"* && "$line" == *"resolved:null"* && "$found" == "false" ]]; then
      local new_line
      new_line=$(echo "$line" | sed "s/resolved:null/resolved:\"$now_ts\"/")
      echo "$new_line" >> "$temp_file"
      found=true
    else
      echo "$line" >> "$temp_file"
    fi
  done < "$blockers_file"

  if [[ "$found" == "false" ]]; then
    rm "$temp_file"
    echo "Error: Unresolved blocker not found matching: $pattern" >&2
    exit 1
  fi

  mv "$temp_file" "$blockers_file"
  echo "Blocker resolved."
}

cmd_list_blockers() {
  local unresolved_only=false

  for arg in "$@"; do
    case "$arg" in
      --unresolved) unresolved_only=true ;;
    esac
  done

  ensure_dir
  if [[ ! -f "$CONTEXTS_DIR/blockers.sup" ]]; then
    echo "No blockers found."
    return 0
  fi

  require_super

  local query="from '$CONTEXTS_DIR/blockers.sup'"
  [[ "$unresolved_only" == "true" ]] && query="$query | where resolved is null"
  query="$query | sort ts desc"

  super -f table -c "$query"
}

cmd_status() {
  local ticket="${1:-}"

  ensure_dir
  require_super

  if [[ -n "$ticket" ]]; then
    # Single ticket status
    echo "=== $ticket ==="
    cmd_get_context "$ticket" 2>/dev/null || true
    echo ""
    echo "Sessions:"
    cmd_list_sessions "$ticket" 2>/dev/null || echo "  (none)"
    echo ""
    echo "Decisions:"
    cmd_list_decisions "$ticket" 2>/dev/null || echo "  (none)"
    echo ""
    echo "Tasks:"
    cmd_list_tasks "$ticket" --pending 2>/dev/null || echo "  (none)"
    echo ""
    echo "Blockers:"
    cmd_list_blockers --unresolved 2>/dev/null || echo "  (none)"
  else
    # All contexts overview
    cmd_list_contexts
  fi
}

cmd_archive() {
  local ticket="${1:-}"

  if [[ -z "$ticket" ]]; then
    echo "Usage: mta-context.sh archive <ticket>" >&2
    exit 1
  fi

  ensure_dir

  local contexts_file="$CONTEXTS_DIR/contexts.sup"
  if [[ ! -f "$contexts_file" ]]; then
    echo "Error: No contexts found" >&2
    exit 1
  fi

  local temp_file
  temp_file=$(mktemp)
  local found=false
  local now_ts
  now_ts=$(now)

  while IFS= read -r line; do
    if [[ "$line" == *"ticket:\"$ticket\""* && "$line" == *"archived_at:null"* ]]; then
      # Update archived_at from null to timestamp
      local new_line
      new_line=$(echo "$line" | sed "s/archived_at:null/archived_at:\"$now_ts\"/")
      echo "$new_line" >> "$temp_file"
      found=true
    else
      echo "$line" >> "$temp_file"
    fi
  done < "$contexts_file"

  if [[ "$found" == "false" ]]; then
    rm "$temp_file"
    echo "Error: Context not found or already archived: $ticket" >&2
    exit 1
  fi

  mv "$temp_file" "$contexts_file"
  echo "Archived: $ticket"
}

cmd_help() {
  cat <<EOF
mta-context.sh - MTA context management via SuperDB

Usage: mta-context.sh <command> [args]

Context Management:
  create-context <ticket> <title> [--linear-url=...] [--branch=...] [--worktree=...]
  list-contexts
  get-context <ticket>

Session Management:
  join <ticket> <session-id>
  leave <ticket> <session-id> <status> [note]
  list-sessions [ticket]

Decisions:
  add-decision <ticket> <text>
  list-decisions <ticket>

Tasks:
  add-task <ticket> <text>
  complete-task <ticket> <task-text-pattern>
  list-tasks [ticket] [--pending]

Blockers:
  add-blocker <ticket> <text>
  resolve-blocker <ticket> <blocker-text-pattern>
  list-blockers [--unresolved]

Status & Archive:
  status [ticket]
  archive <ticket>

Environment:
  MTA_CONTEXTS_DIR  Override contexts directory (default: ~/.claude/contexts)
EOF
}

# ==============================================================================
# Main dispatch
# ==============================================================================

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    create-context) cmd_create_context "$@" ;;
    list-contexts) cmd_list_contexts "$@" ;;
    get-context) cmd_get_context "$@" ;;
    join) cmd_join "$@" ;;
    leave) cmd_leave "$@" ;;
    list-sessions) cmd_list_sessions "$@" ;;
    add-decision) cmd_add_decision "$@" ;;
    list-decisions) cmd_list_decisions "$@" ;;
    add-task) cmd_add_task "$@" ;;
    complete-task) cmd_complete_task "$@" ;;
    list-tasks) cmd_list_tasks "$@" ;;
    add-blocker) cmd_add_blocker "$@" ;;
    resolve-blocker) cmd_resolve_blocker "$@" ;;
    list-blockers) cmd_list_blockers "$@" ;;
    status) cmd_status "$@" ;;
    archive) cmd_archive "$@" ;;
    help|--help|-h) cmd_help ;;
    *)
      echo "Unknown command: $cmd" >&2
      echo "Run 'mta-context.sh help' for usage." >&2
      exit 1
      ;;
  esac
}

main "$@"
