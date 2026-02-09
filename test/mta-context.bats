#!/usr/bin/env bats
# mta-context.bats - Tests for mta-context.sh
#
# Run with: bats test/mta-context.bats
# Install bats: brew install bats-core (macOS) or apt install bats (linux)
#
# Tests marked with require_super will be skipped if super CLI is not installed.
# This allows running write-operation tests even without super.

load test_helper

# ==============================================================================
# Context Management
# ==============================================================================

@test "create-context creates contexts.sup if it doesn't exist" {
  run mta create-context DEVOPS-1641 "Replace Oban scaler"
  assert_success
  assert_file_exists "contexts.sup"
}

@test "create-context adds record with required fields" {
  run mta create-context DEVOPS-1641 "Replace Oban scaler"
  assert_success
  assert_file_contains "contexts.sup" "ticket:\"DEVOPS-1641\""
  assert_file_contains "contexts.sup" "title:\"Replace Oban scaler\""
}

@test "create-context accepts optional flags" {
  run mta create-context DEVOPS-1641 "Replace Oban scaler" \
    --ticket-url="https://linear.app/team/DEVOPS-1641" \
    --branch="devops-1641-oban" \
    --worktree="ds5"
  assert_success
  assert_file_contains "contexts.sup" "ticket_url:\"https://linear.app/team/DEVOPS-1641\""
  assert_file_contains "contexts.sup" "branch:\"devops-1641-oban\""
  assert_file_contains "contexts.sup" "worktree:\"ds5\""
}

@test "create-context sets created timestamp" {
  run mta create-context DEVOPS-1641 "Replace Oban scaler"
  assert_success
  # Should have a created field with ISO timestamp pattern
  assert_file_contains "contexts.sup" "created:\"20"
}

@test "list-contexts returns empty for no contexts" {
  require_super
  run mta list-contexts
  assert_success
  [[ -z "$output" || "$output" == "[]" || "$output" == *"no contexts"* || "$output" == *"No contexts"* ]]
}

@test "list-contexts shows created contexts" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta create-context DEVOPS-1670 "CI experiment"

  run mta list-contexts
  assert_success
  [[ "$output" == *"DEVOPS-1641"* ]]
  [[ "$output" == *"DEVOPS-1670"* ]]
}

@test "get-context returns specific context" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler" --worktree=ds5
  mta create-context DEVOPS-1670 "CI experiment"

  run mta get-context DEVOPS-1641
  assert_success
  [[ "$output" == *"DEVOPS-1641"* ]]
  [[ "$output" == *"ds5"* ]]
  [[ "$output" != *"DEVOPS-1670"* ]]
}

@test "get-context fails for nonexistent ticket" {
  require_super
  run mta get-context NONEXISTENT-999
  assert_failure
}

# ==============================================================================
# Session Management
# ==============================================================================

@test "join creates sessions.sup if it doesn't exist" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"

  run mta join DEVOPS-1641 ds5/abc123
  assert_success
  assert_file_exists "sessions.sup"
}

@test "join creates session record with correct fields" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"

  run mta join DEVOPS-1641 ds5/abc123
  assert_success
  assert_file_contains "sessions.sup" "ticket:\"DEVOPS-1641\""
  assert_file_contains "sessions.sup" "session_id:\"ds5/abc123\""
  assert_file_contains "sessions.sup" "joined_at:\""
  assert_file_contains "sessions.sup" "left_at:null"
}

@test "join fails for nonexistent context" {
  require_super
  run mta join NONEXISTENT-999 ds5/abc123
  assert_failure
}

@test "leave updates session with departure info" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta join DEVOPS-1641 ds5/abc123

  run mta leave DEVOPS-1641 ds5/abc123 handoff "diagnosed the issue"
  assert_success
  # left_at should no longer be null
  ! grep -q "session_id:\"ds5/abc123\".*left_at:null" "$TEST_CONTEXTS_DIR/sessions.sup"
}

@test "leave records status and note" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta join DEVOPS-1641 ds5/abc123

  run mta leave DEVOPS-1641 ds5/abc123 handoff "diagnosed the issue"
  assert_success
  assert_file_contains "sessions.sup" "status:\"handoff\""
  assert_file_contains "sessions.sup" "note:\"diagnosed the issue\""
}

@test "list-sessions shows all sessions" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta join DEVOPS-1641 ds5/session1
  mta join DEVOPS-1641 ds5/session2

  run mta list-sessions
  assert_success
  [[ "$output" == *"ds5/session1"* ]]
  [[ "$output" == *"ds5/session2"* ]]
}

@test "list-sessions filters by ticket" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta create-context DEVOPS-1670 "CI experiment"
  mta join DEVOPS-1641 ds5/session1
  mta join DEVOPS-1670 ds9/session2

  run mta list-sessions DEVOPS-1641
  assert_success
  [[ "$output" == *"ds5/session1"* ]]
  [[ "$output" != *"ds9/session2"* ]]
}

# ==============================================================================
# Decisions
# ==============================================================================

@test "add-decision creates decisions.sup" {
  run mta create-context DEVOPS-1641 "Replace Oban scaler"
  run mta add-decision DEVOPS-1641 "QUEUE SCALING E2E VERIFIED"
  assert_success
  assert_file_exists "decisions.sup"
}

@test "add-decision records decision with timestamp" {
  mta create-context DEVOPS-1641 "Replace Oban scaler"

  run mta add-decision DEVOPS-1641 "QUEUE SCALING E2E VERIFIED"
  assert_success
  assert_file_contains "decisions.sup" "ticket:\"DEVOPS-1641\""
  assert_file_contains "decisions.sup" "text:\"QUEUE SCALING E2E VERIFIED\""
  assert_file_contains "decisions.sup" "ts:\""
}

@test "list-decisions shows decisions for ticket" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta add-decision DEVOPS-1641 "Decision one"
  mta add-decision DEVOPS-1641 "Decision two"

  run mta list-decisions DEVOPS-1641
  assert_success
  [[ "$output" == *"Decision one"* ]]
  [[ "$output" == *"Decision two"* ]]
}

# ==============================================================================
# Tasks
# ==============================================================================

@test "add-task creates tasks.sup" {
  run mta create-context DEVOPS-1641 "Replace Oban scaler"
  run mta add-task DEVOPS-1641 "Add SSM permission"
  assert_success
  assert_file_exists "tasks.sup"
}

@test "add-task creates pending task" {
  mta create-context DEVOPS-1641 "Replace Oban scaler"

  run mta add-task DEVOPS-1641 "Add SSM permission"
  assert_success
  assert_file_contains "tasks.sup" "status:\"pending\""
  assert_file_contains "tasks.sup" "text:\"Add SSM permission\""
}

@test "complete-task marks task as completed" {
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta add-task DEVOPS-1641 "Add SSM permission"

  run mta complete-task DEVOPS-1641 "SSM permission"
  assert_success
  # Should have status:completed (or similar)
  assert_file_contains "tasks.sup" "status:\"completed\""
}

@test "list-tasks shows all tasks" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta add-task DEVOPS-1641 "Task one"
  mta add-task DEVOPS-1641 "Task two"

  run mta list-tasks DEVOPS-1641
  assert_success
  [[ "$output" == *"Task one"* ]]
  [[ "$output" == *"Task two"* ]]
}

@test "list-tasks --pending filters to pending only" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta add-task DEVOPS-1641 "Task one"
  mta add-task DEVOPS-1641 "Task two"
  mta complete-task DEVOPS-1641 "Task one"

  run mta list-tasks DEVOPS-1641 --pending
  assert_success
  [[ "$output" != *"Task one"* ]]
  [[ "$output" == *"Task two"* ]]
}

# ==============================================================================
# Blockers
# ==============================================================================

@test "add-blocker creates blockers.sup" {
  run mta create-context DEVOPS-1641 "Replace Oban scaler"
  run mta add-blocker DEVOPS-1641 "Notion page requires auth"
  assert_success
  assert_file_exists "blockers.sup"
}

@test "add-blocker creates unresolved blocker" {
  mta create-context DEVOPS-1641 "Replace Oban scaler"

  run mta add-blocker DEVOPS-1641 "Notion page requires auth"
  assert_success
  assert_file_contains "blockers.sup" "resolved:null"
  assert_file_contains "blockers.sup" "text:\"Notion page requires auth\""
}

@test "resolve-blocker marks blocker as resolved" {
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta add-blocker DEVOPS-1641 "Notion page requires auth"

  run mta resolve-blocker DEVOPS-1641 "Notion"
  assert_success
  # resolved should no longer be null
  ! grep -q "text:\"Notion page requires auth\".*resolved:null" "$TEST_CONTEXTS_DIR/blockers.sup"
}

@test "list-blockers --unresolved shows only unresolved" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta add-blocker DEVOPS-1641 "Blocker one"
  mta add-blocker DEVOPS-1641 "Blocker two"
  mta resolve-blocker DEVOPS-1641 "Blocker one"

  run mta list-blockers --unresolved
  assert_success
  [[ "$output" != *"Blocker one"* ]]
  [[ "$output" == *"Blocker two"* ]]
}

# ==============================================================================
# Status & Archive
# ==============================================================================

@test "status shows formatted context overview" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta join DEVOPS-1641 ds5/abc123
  mta add-decision DEVOPS-1641 "Key decision"
  mta add-task DEVOPS-1641 "Remaining work"
  mta add-blocker DEVOPS-1641 "Something blocking"

  run mta status DEVOPS-1641
  assert_success
  [[ "$output" == *"DEVOPS-1641"* ]]
}

@test "archive moves context to archived state" {
  mta create-context DEVOPS-1641 "Replace Oban scaler"

  run mta archive DEVOPS-1641
  assert_success

  # Context should be marked archived
  assert_file_contains "contexts.sup" "archived_at:\""
}

# ==============================================================================
# Edge Cases & Error Handling
# ==============================================================================

@test "handles special characters in titles" {
  run mta create-context DEVOPS-1641 "Fix \"quoted\" and 'apostrophe' issues"
  assert_success
}

@test "handles special characters in notes" {
  require_super
  mta create-context DEVOPS-1641 "Test"
  mta join DEVOPS-1641 ds5/abc123

  run mta leave DEVOPS-1641 ds5/abc123 handoff "Note with \"quotes\" and newline\ncharacter"
  assert_success
}

@test "concurrent sessions for same ticket" {
  require_super
  mta create-context DEVOPS-1641 "Replace Oban scaler"
  mta join DEVOPS-1641 ds5/session1
  mta join DEVOPS-1641 ds8/session2

  # Both should be active
  run mta list-sessions DEVOPS-1641
  assert_success
  [[ "$output" == *"ds5/session1"* ]]
  [[ "$output" == *"ds8/session2"* ]]
}

# ==============================================================================
# Assertion Helpers (bats-assert compatibility)
# ==============================================================================

assert_success() {
  if [[ "$status" -ne 0 ]]; then
    echo "Expected success (exit 0), got exit $status"
    echo "Output: $output"
    return 1
  fi
}

assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    echo "Expected failure (non-zero exit), got exit 0"
    echo "Output: $output"
    return 1
  fi
}
