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

# Append a record to a .sup file (validates as SUP first)
append_record() {
  local file="$1"
  local record="$2"
  echo "$record" | super -s -c 'values this' - >> "$CONTEXTS_DIR/$file"
}

# Escape text for ZSON string embedding (backslash and double quotes)
escape_sup_text() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  echo "$text"
}

# Normalize various date formats to YYYY-MM-DDTHH:MM:SSZ
# Handles: "2026-02-06", "2026-02-06 16:30", "2026-02-06T16:30:00Z", etc.
normalize_date() {
  local d="$1"
  # Already ISO format
  if [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    echo "$d"
    return
  fi
  # Date + time: "2026-02-06 16:30" or "2026-02-06 16:30:00"
  if [[ "$d" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+([0-9]{2}:[0-9]{2})(:[0-9]{2})?$ ]]; then
    local date_part="${BASH_REMATCH[1]}"
    local time_part="${BASH_REMATCH[2]}"
    local sec_part="${BASH_REMATCH[3]}"
    [[ -z "$sec_part" ]] && sec_part=":00"
    echo "${date_part}T${time_part}${sec_part}Z"
    return
  fi
  # Date only: "2026-02-06"
  if [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "${d}T00:00:00Z"
    return
  fi
  # ISO with T but missing seconds or Z
  if [[ "$d" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2}:[0-9]{2})(:[0-9]{2})?(Z)?$ ]]; then
    local date_part="${BASH_REMATCH[1]}"
    local time_part="${BASH_REMATCH[2]}"
    local sec_part="${BASH_REMATCH[3]}"
    [[ -z "$sec_part" ]] && sec_part=":00"
    echo "${date_part}T${time_part}${sec_part}Z"
    return
  fi
  # Fallback: return as-is
  echo "$d"
}

# Extract all lines between matching ## headings and the next ## heading.
# Accumulates across multiple matching sections.
# Args: $1 = file, $2 = extended regex pattern for section heading
extract_section() {
  local file="$1"
  local pattern="$2"
  local in_section=false
  local result=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]] ]]; then
      # Check if this heading matches the pattern (case-insensitive)
      local heading_lower
      heading_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')
      local pattern_lower
      pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
      # Test each alternative in the pipe-separated pattern
      local matched=false
      local IFS_save="$IFS"
      IFS='|'
      for alt in $pattern_lower; do
        # Trim whitespace
        alt="${alt#"${alt%%[![:space:]]*}"}"
        alt="${alt%"${alt##*[![:space:]]}"}"
        if [[ "$heading_lower" == *"$alt"* ]]; then
          matched=true
          break
        fi
      done
      IFS="$IFS_save"
      if [[ "$matched" == "true" ]]; then
        in_section=true
        continue
      else
        in_section=false
        continue
      fi
    fi
    if [[ "$in_section" == "true" ]]; then
      result+="$line"$'\n'
    fi
  done < "$file"

  echo "$result"
}

# Check if super CLI is available
require_super() {
  if ! command -v super &>/dev/null; then
    echo "Error: 'super' CLI not found. Install SuperDB first." >&2
    exit 1
  fi
}

# Detect session ID from Claude Code conversation files.
# Finds the most recently modified .jsonl in the project's conversation dir.
detect_session_id() {
  local project_dir
  project_dir=$(pwd | sed 's|^/||; s|/|-|g')
  local conv_dir="$HOME/.claude/projects/-${project_dir}"

  if [[ -d "$conv_dir" ]]; then
    local latest
    latest=$(ls -t "$conv_dir"/*.jsonl 2>/dev/null | head -1)
    if [[ -n "$latest" ]]; then
      # Extract UUID from filename (strip path and .jsonl)
      local uuid
      uuid=$(basename "$latest" .jsonl)
      echo "${uuid:0:8}"
      return 0
    fi
  fi

  # Fallback: random 8-char hex
  head -c 4 /dev/urandom | xxd -p
}

# ==============================================================================
# Commands
# ==============================================================================

cmd_create_context() {
  local ticket="${1:-}"
  local title="${2:-}"

  if [[ -z "$ticket" || -z "$title" ]]; then
    echo "Usage: mta-context.sh create-context <ticket> <title> [--ticket-url=...] [--branch=...] [--worktree=...]" >&2
    exit 1
  fi

  shift 2

  # Parse optional flags
  local ticket_url="" branch="" worktree=""
  for arg in "$@"; do
    case "$arg" in
      --ticket-url=*) ticket_url="${arg#*=}" ;;
      --branch=*) branch="${arg#*=}" ;;
      --worktree=*) worktree="${arg#*=}" ;;
    esac
  done

  ensure_dir

  # Build record - always include archived_at:null for consistent schema
  title=$(escape_sup_text "$title")
  local record="{ticket:\"$ticket\",title:\"$title\",created:\"$(now)\",archived_at:null"
  [[ -n "$ticket_url" ]] && record="$record,ticket_url:\"$(escape_sup_text "$ticket_url")\""
  [[ -n "$branch" ]] && record="$record,branch:\"$(escape_sup_text "$branch")\""
  [[ -n "$worktree" ]] && record="$record,worktree:\"$(escape_sup_text "$worktree")\""
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
  super -j -c "from '$CONTEXTS_DIR/contexts.sup' | where archived_at is null | sort created desc | cut ticket, title" | grdy
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
  result=$(super -j -c "from '$CONTEXTS_DIR/contexts.sup' | where ticket = '$ticket'" 2>/dev/null)

  if [[ -z "$result" ]]; then
    echo "Error: Context not found: $ticket" >&2
    exit 1
  fi

  echo "$result"
}

cmd_session_id() {
  local worktree
  worktree=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
  local short_id
  short_id=$(detect_session_id)
  echo "$worktree/$short_id"
}

cmd_join() {
  local ticket="${1:-}"
  local session_id="${2:-}"

  if [[ -z "$ticket" ]]; then
    echo "Usage: mta-context.sh join <ticket> [session-id]" >&2
    exit 1
  fi

  # Auto-detect session ID if not provided
  if [[ -z "$session_id" ]]; then
    session_id=$(cmd_session_id)
  fi

  ensure_dir

  # Verify context exists
  if [[ -f "$CONTEXTS_DIR/contexts.sup" ]]; then
    require_super
    local exists
    exists=$(super -f text -c "from '$CONTEXTS_DIR/contexts.sup' | where ticket = '$ticket' | count()" 2>/dev/null || echo "0")
    exists="${exists:-0}"
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
  note=$(escape_sup_text "$note")

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
    super -j -c "from '$CONTEXTS_DIR/sessions.sup' | where ticket = '$ticket' | sort joined_at desc" | grdy
  else
    super -j -c "from '$CONTEXTS_DIR/sessions.sup' | sort joined_at desc" | grdy
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
  text=$(escape_sup_text "$text")
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
  super -j -c "from '$CONTEXTS_DIR/decisions.sup' | where ticket = '$ticket' | sort ts desc" | grdy
}

cmd_add_task() {
  local ticket="${1:-}"
  local text="${2:-}"

  if [[ -z "$ticket" || -z "$text" ]]; then
    echo "Usage: mta-context.sh add-task <ticket> <text>" >&2
    exit 1
  fi

  ensure_dir
  text=$(escape_sup_text "$text")
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

  super -j -c "$query" | grdy
}

cmd_add_blocker() {
  local ticket="${1:-}"
  local text="${2:-}"

  if [[ -z "$ticket" || -z "$text" ]]; then
    echo "Usage: mta-context.sh add-blocker <ticket> <text>" >&2
    exit 1
  fi

  ensure_dir
  text=$(escape_sup_text "$text")
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

  super -j -c "$query" | grdy
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

# ==============================================================================
# Import Parsers
# ==============================================================================

# Import sessions from markdown sections matching session/departure patterns.
# Handles two formats:
#   Format A: "- ds8/3fc75ec2: left 2026-01-29 (done) - note"
#   Format B: "- 2026-02-06 16:30: ds5/38555de5 left (status: done) - note"
import_sessions() {
  local ticket="$1"
  local md_file="$2"
  local count=0

  # Regex patterns stored in variables to avoid bash parsing issues with ()
  local re_status_full='[(]status:[[:space:]]*([^)]+)[)]'
  local re_status_short='[(]([a-z]+)[)]'
  local re_joined='joined[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}([T[:space:]][0-9]{2}:[0-9]{2}(:[0-9]{2})?Z?)?)'
  local re_left='left[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}([T[:space:]][0-9]{2}:[0-9]{2}(:[0-9]{2})?Z?)?)'
  local re_none='[(]none[)]'

  local section
  section=$(extract_section "$md_file" "linked worktrees|linked sessions|session history|departure log")
  [[ -z "$section" ]] && echo "$count" && return

  while IFS= read -r line; do
    # Skip blank, placeholder, comment lines
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ $re_none ]] && continue
    [[ "$line" =~ ^\<\!-- ]] && continue
    # Skip indented sub-bullets (lines starting with spaces after -)
    [[ "$line" =~ ^[[:space:]]{2,} ]] && continue
    # Must start with "- "
    [[ ! "$line" =~ ^-[[:space:]] ]] && continue

    local content="${line#- }"
    local session_id="" joined_at="" left_at="" status="" note=""

    # Format A: "ds8/3fc75ec2: left 2026-01-29 (done) - note"
    # or: "ds8/3fc75ec2: joined 2026-01-29, left 2026-02-06"
    if [[ "$content" =~ ^([a-zA-Z0-9_]+/[a-zA-Z0-9]+):[[:space:]]*(.*) ]]; then
      session_id="${BASH_REMATCH[1]}"
      local rest="${BASH_REMATCH[2]}"

      # Extract joined date if present
      if [[ "$rest" =~ $re_joined ]]; then
        joined_at=$(normalize_date "${BASH_REMATCH[1]}")
      fi

      # Extract left date if present
      if [[ "$rest" =~ $re_left ]]; then
        left_at=$(normalize_date "${BASH_REMATCH[1]}")
      fi

      # Extract status from "(done)" or "(status: done)" or "(paused)" etc.
      if [[ "$rest" =~ $re_status_full ]]; then
        status="${BASH_REMATCH[1]}"
      elif [[ "$rest" =~ $re_status_short ]]; then
        status="${BASH_REMATCH[1]}"
      fi

      # Extract note after " - "
      if [[ "$rest" =~ [[:space:]]-[[:space:]]+(.*) ]]; then
        note="${BASH_REMATCH[1]}"
      fi

    # Format B: "2026-02-06 16:30: ds5/38555de5 left (status: done) - note"
    # Session ID can be "ds5/38555de5" or just "ds8"
    elif [[ "$content" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]][0-9]{2}:[0-9]{2})?)[::][[:space:]]+([a-zA-Z0-9_]+(/[a-zA-Z0-9]+)?)[[:space:]]+(.*) ]]; then
      local date_str="${BASH_REMATCH[1]}"
      session_id="${BASH_REMATCH[3]}"
      local rest="${BASH_REMATCH[5]}"

      local norm_date
      norm_date=$(normalize_date "$date_str")

      if [[ "$rest" =~ ^left ]]; then
        left_at="$norm_date"
      elif [[ "$rest" =~ ^joined ]]; then
        joined_at="$norm_date"
      fi

      # Extract status
      if [[ "$rest" =~ $re_status_full ]]; then
        status="${BASH_REMATCH[1]}"
      elif [[ "$rest" =~ $re_status_short ]]; then
        status="${BASH_REMATCH[1]}"
      fi

      # Extract note after " - "
      if [[ "$rest" =~ [[:space:]]-[[:space:]]+(.*) ]]; then
        note="${BASH_REMATCH[1]}"
      fi
    else
      continue
    fi

    # If only left, set joined = left
    if [[ -n "$left_at" && -z "$joined_at" ]]; then
      joined_at="$left_at"
    fi
    # If only joined, left_at stays null
    [[ -z "$joined_at" ]] && continue  # No usable date at all

    note=$(escape_sup_text "$note")

    local record="{ticket:\"$ticket\",session_id:\"$session_id\",joined_at:\"$joined_at\""
    if [[ -n "$left_at" ]]; then
      record="$record,left_at:\"$left_at\""
    else
      record="$record,left_at:null"
    fi
    [[ -n "$status" ]] && record="$record,status:\"$status\""
    [[ -n "$note" ]] && record="$record,note:\"$note\""
    record="$record}"

    append_record "sessions.sup" "$record"
    ((count++))
  done <<< "$section"

  echo "$count"
}

# Import decisions from markdown. Handles:
#   - **Bold title** (2026-02-04) with indented sub-bullets
#   - 2026-02-06 16:30: inline text
#   - Simple bullet text (uses fallback_ts)
import_decisions() {
  local ticket="$1"
  local md_file="$2"
  local fallback_ts="$3"
  local count=0

  local section
  section=$(extract_section "$md_file" "decisions|recent decisions|active decisions|decisions & progress")
  [[ -z "$section" ]] && echo "$count" && return

  local current_text="" current_ts=""

  _flush_decision() {
    if [[ -n "$current_text" ]]; then
      local escaped
      escaped=$(escape_sup_text "$current_text")
      local ts="${current_ts:-$fallback_ts}"
      append_record "decisions.sup" "{ticket:\"$ticket\",ts:\"$ts\",text:\"$escaped\"}"
      ((count++))
    fi
    current_text=""
    current_ts=""
  }

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^\<\!-- ]] && continue

    # Indented sub-bullet: append to current decision
    if [[ "$line" =~ ^[[:space:]]{2,}-[[:space:]]+(.*) ]]; then
      local sub="${BASH_REMATCH[1]}"
      if [[ -n "$current_text" ]]; then
        current_text="$current_text; $sub"
      fi
      continue
    fi

    # Top-level bullet
    if [[ "$line" =~ ^-[[:space:]]+(.*) ]]; then
      # Flush previous
      _flush_decision

      local content="${BASH_REMATCH[1]}"

      # Format: **Bold title** (2026-02-04)
      local re_bold_date='^\*\*([^*]+)\*\*[[:space:]]*[(]([0-9]{4}-[0-9]{2}-[0-9]{2})[)]'
      if [[ "$content" =~ $re_bold_date ]]; then
        current_text="${BASH_REMATCH[1]}"
        current_ts=$(normalize_date "${BASH_REMATCH[2]}")
      # Format: 2026-02-06 16:30: text or 2026-02-06: text
      elif [[ "$content" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]][0-9]{2}:[0-9]{2})?)[::][[:space:]]*(.*) ]]; then
        current_ts=$(normalize_date "${BASH_REMATCH[1]}")
        current_text="${BASH_REMATCH[3]}"
      else
        # Simple bullet, no date
        current_text="$content"
        current_ts="$fallback_ts"
      fi
    fi
  done <<< "$section"

  # Flush last
  _flush_decision

  echo "$count"
}

# Import work log entries as decisions.
import_worklog() {
  local ticket="$1"
  local md_file="$2"
  local fallback_ts="$3"
  local count=0

  local section
  section=$(extract_section "$md_file" "work log|updates|progress$|work completed")
  [[ -z "$section" ]] && echo "$count" && return

  local current_text="" current_ts=""

  _flush_worklog() {
    if [[ -n "$current_text" ]]; then
      local escaped
      escaped=$(escape_sup_text "$current_text")
      local ts="${current_ts:-$fallback_ts}"
      append_record "decisions.sup" "{ticket:\"$ticket\",ts:\"$ts\",text:\"$escaped\"}"
      ((count++))
    fi
    current_text=""
    current_ts=""
  }

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^\<\!-- ]] && continue

    # Indented sub-bullet: append to current entry
    if [[ "$line" =~ ^[[:space:]]{2,}-?[[:space:]]*(.*) ]]; then
      local sub="${BASH_REMATCH[1]}"
      # Strip leading "- " from sub-bullets
      sub="${sub#- }"
      if [[ -n "$current_text" ]]; then
        current_text="$current_text; $sub"
      fi
      continue
    fi

    # Top-level bullet
    if [[ "$line" =~ ^-[[:space:]]+(.*) ]]; then
      _flush_worklog

      local content="${BASH_REMATCH[1]}"

      # Format: 2026-02-06 session_id: text or 2026-02-06: text
      local re_session_date='^\S+[[:space:]]+[(]([0-9]{4}-[0-9]{2}-[0-9]{2})[)][::][[:space:]]*(.*)'
      if [[ "$content" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]][0-9]{2}:[0-9]{2})?)[::][[:space:]]*(.*) ]]; then
        current_ts=$(normalize_date "${BASH_REMATCH[1]}")
        current_text="${BASH_REMATCH[3]}"
      # Format: session_id (2026-01-30): text
      elif [[ "$content" =~ $re_session_date ]]; then
        current_ts=$(normalize_date "${BASH_REMATCH[1]}")
        current_text="${BASH_REMATCH[2]}"
      else
        current_text="$content"
        current_ts="$fallback_ts"
      fi
    fi
  done <<< "$section"

  _flush_worklog

  echo "$count"
}

# Import tasks from markdown checkbox/bullet lists.
import_tasks() {
  local ticket="$1"
  local md_file="$2"
  local import_ts="$3"
  local count=0

  local section
  section=$(extract_section "$md_file" "to-do|outstanding tasks|pending tasks|remaining|pending \(follow|follow-up|next steps")
  [[ -z "$section" ]] && echo "$count" && return

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^\<\!-- ]] && continue
    # Skip indented sub-bullets
    [[ "$line" =~ ^[[:space:]]{2,} ]] && continue

    local text="" task_status="pending"

    # "- [ ] text" → pending
    if [[ "$line" =~ ^-[[:space:]]+\[[[:space:]]\][[:space:]]+(.*) ]]; then
      text="${BASH_REMATCH[1]}"
      task_status="pending"
    # "- [x] text" or "- [X] text" → completed
    elif [[ "$line" =~ ^-[[:space:]]+\[[xX]\][[:space:]]+(.*) ]]; then
      text="${BASH_REMATCH[1]}"
      task_status="completed"
    # "- ~~text~~ DONE" or "- ~~text~~" → completed
    elif [[ "$line" =~ ^-[[:space:]]+~~(.+)~~(.*)$ ]]; then
      text="${BASH_REMATCH[1]}"
      task_status="completed"
    # "1. text" numbered → pending
    elif [[ "$line" =~ ^[0-9]+\.[[:space:]]+(.*) ]]; then
      text="${BASH_REMATCH[1]}"
      task_status="pending"
    # "- text" plain bullet → pending
    elif [[ "$line" =~ ^-[[:space:]]+(.*) ]]; then
      text="${BASH_REMATCH[1]}"
      # Check for "None" indicators
      if [[ "$text" =~ ^[Nn]one ]]; then
        continue
      fi
      task_status="pending"
    else
      continue
    fi

    [[ -z "$text" ]] && continue

    text=$(escape_sup_text "$text")
    append_record "tasks.sup" "{ticket:\"$ticket\",ts:\"$import_ts\",text:\"$text\",status:\"$task_status\"}"
    ((count++))
  done <<< "$section"

  echo "$count"
}

# Import blockers from markdown.
import_blockers() {
  local ticket="$1"
  local md_file="$2"
  local import_ts="$3"
  local count=0

  local section
  section=$(extract_section "$md_file" "blockers")
  [[ -z "$section" ]] && echo "$count" && return

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^\<\!-- ]] && continue
    # Skip indented sub-bullets (collect for resolved date detection)
    [[ "$line" =~ ^[[:space:]]{2,} ]] && continue

    # Skip none indicators
    local re_paren_none='^[(][Nn]one[)]'
    if [[ "$line" =~ ^[Nn]one ]] || [[ "$line" =~ $re_paren_none ]] || [[ "$line" =~ ^-[[:space:]]+[Nn]one ]]; then
      continue
    fi

    # Must start with "- "
    [[ ! "$line" =~ ^-[[:space:]]+(.*) ]] && continue
    local content="${BASH_REMATCH[1]}"

    local text="" resolved="null"

    # Strikethrough: "~~text~~" → resolved
    if [[ "$content" =~ ^~~(.+)~~(.*)$ ]]; then
      text="${BASH_REMATCH[1]}"
      resolved="\"$import_ts\""
    else
      text="$content"
      resolved="null"
    fi

    [[ -z "$text" ]] && continue

    # Strip leading date prefix if present: "2026-01-28 18:32: CONFIRMED: ..."
    if [[ "$text" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]][0-9]{2}:[0-9]{2})?:[[:space:]]*(.*) ]]; then
      text="${BASH_REMATCH[2]}"
    fi

    text=$(escape_sup_text "$text")
    append_record "blockers.sup" "{ticket:\"$ticket\",ts:\"$import_ts\",text:\"$text\",resolved:$resolved}"
    ((count++))
  done <<< "$section"

  echo "$count"
}

cmd_import() {
  local md_file="${1:-}"

  if [[ -z "$md_file" ]]; then
    echo "Usage: mta-context.sh import <context.md>" >&2
    echo "  Import an old markdown context file into SuperDB." >&2
    echo "  Looks in \$MTA_CONTEXTS_DIR (or ~/.claude/contexts/) by default." >&2
    exit 1
  fi

  # Resolve file path - check as-is, then in contexts dir
  if [[ ! -f "$md_file" ]]; then
    local try="$CONTEXTS_DIR/$md_file"
    if [[ -f "$try" ]]; then
      md_file="$try"
    else
      echo "Error: File not found: $md_file" >&2
      exit 1
    fi
  fi

  ensure_dir

  # Extract ticket from first heading: "# PROJ-1709: Title" or "# PROJ-1641 - Title"
  local heading
  heading=$(grep -m1 '^# ' "$md_file" | sed 's/^# //')

  # Extract ticket ID: try LETTERS-DIGITS pattern first, fall back to heading text
  local ticket
  ticket=$(echo "$heading" | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)
  if [[ -z "$ticket" ]]; then
    # Use heading as ticket, lowercased with spaces/punctuation replaced by dashes
    ticket=$(echo "$heading" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  fi
  if [[ -z "$ticket" ]]; then
    echo "Error: Could not extract ticket ID from heading: $heading" >&2
    exit 1
  fi

  # Check if already imported — skip contexts.sup insert but still import data
  local already_exists=false
  if [[ -f "$CONTEXTS_DIR/contexts.sup" ]]; then
    require_super
    local exists
    exists=$(super -f text -c "from '$CONTEXTS_DIR/contexts.sup' | where ticket = '$ticket' | count()" 2>/dev/null || echo "0")
    exists="${exists:-0}"
    if [[ "$exists" != "0" ]]; then
      already_exists=true
    fi
  fi

  local import_ts
  import_ts=$(now)

  if [[ "$already_exists" == "false" ]]; then
    # Extract title (everything after "TICKET: " or "TICKET - ")
    local title
    title=$(echo "$heading" | sed -E 's/^[A-Z]+-[0-9]+[: -]+//')
    # Fallback: try bold line after heading
    if [[ -z "$title" || "$title" == "$heading" ]]; then
      title=$(grep -m1 '^\*\*' "$md_file" | sed 's/\*\*//g' || true)
    fi
    [[ -z "$title" ]] && title="(imported)"

    # Extract ticket URL (GitHub Issues or other tracker)
    local ticket_url
    ticket_url=$(grep -oE 'https://github\.com/[^ )*]+/issues/[0-9]+' "$md_file" | head -1 || true)

    # Extract branch
    local branch
    branch=$(grep -iE '^Branch:' "$md_file" | head -1 | sed 's/^[Bb]ranch:[[:space:]]*//' || true)
    # Fallback: try to find branch from worktree section or filename
    if [[ -z "$branch" ]]; then
      local base
      base=$(basename "$md_file" .md)
      # If filename looks like a branch name (lowercase with dashes), use it
      if [[ "$base" =~ ^[a-z]+-[0-9]+-.*$ ]]; then
        branch="$base"
      fi
    fi

    # Extract worktree
    local worktree
    worktree=$(grep -iE '^Worktree:' "$md_file" | head -1 | sed 's/^[Ww]orktree:[[:space:]]*//' || true)

    # Build record
    local record="{ticket:\"$ticket\",title:\"$title\",created:\"$import_ts\",archived_at:null"
    [[ -n "$ticket_url" ]] && record="$record,ticket_url:\"$ticket_url\""
    [[ -n "$branch" ]] && record="$record,branch:\"$branch\""
    [[ -n "$worktree" ]] && record="$record,worktree:\"$worktree\""
    record="$record}"

    append_record "contexts.sup" "$record"

    echo "Imported: $ticket"
    echo "  Title:  $title"
    [[ -n "$ticket_url" ]] && echo "  URL:    $ticket_url"
    [[ -n "$branch" ]] && echo "  Branch: $branch"
    [[ -n "$worktree" ]] && echo "  Worktree: $worktree"
  else
    echo "Imported data for existing context: $ticket"
  fi

  # Use file mtime as fallback timestamp for undated entries
  local fallback_ts
  if stat -f %Sm -t "%Y-%m-%dT%H:%M:%SZ" "$md_file" &>/dev/null; then
    fallback_ts=$(stat -f %Sm -t "%Y-%m-%dT%H:%M:%SZ" "$md_file")
  else
    # Linux stat fallback
    fallback_ts=$(date -r "$md_file" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$import_ts")
  fi

  # Run all data parsers
  local n_sessions n_decisions n_worklog n_tasks n_blockers
  n_sessions=$(import_sessions "$ticket" "$md_file")
  n_decisions=$(import_decisions "$ticket" "$md_file" "$fallback_ts")
  n_worklog=$(import_worklog "$ticket" "$md_file" "$fallback_ts")
  n_tasks=$(import_tasks "$ticket" "$md_file" "$import_ts")
  n_blockers=$(import_blockers "$ticket" "$md_file" "$import_ts")

  echo "  Sessions:  $n_sessions"
  echo "  Decisions: $n_decisions"
  echo "  Work log:  $n_worklog"
  echo "  Tasks:     $n_tasks"
  echo "  Blockers:  $n_blockers"
  echo ""
  echo "Source: $md_file (kept as-is)"
}

cmd_help() {
  less -FX <<EOF
mta-context.sh - MTA context management via SuperDB

Usage: mta-context.sh <command> [args]

Context Management:
  create-context <ticket> <title> [--ticket-url=...] [--branch=...] [--worktree=...]
  list-contexts
  get-context <ticket>

Session Management:
  session-id                          Auto-detect session identifier
  join <ticket> [session-id]          Session ID auto-detected if omitted
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

Migration:
  import <context.md>              Import old markdown context into SuperDB

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
    session-id) cmd_session_id "$@" ;;
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
    import) cmd_import "$@" ;;
    help|--help|-h) cmd_help ;;
    *)
      echo "Unknown command: $cmd" >&2
      echo "Run 'mta-context.sh help' for usage." >&2
      exit 1
      ;;
  esac
}

main "$@"
