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
# Import
# ==============================================================================

@test "import extracts ticket and title from markdown heading" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-1234.md" <<'MDEOF'
# DEVOPS-1234: Fix the widget

## Summary
Some work on widgets.

Branch: devops-1234-fix-widget
Worktree: ds5
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-1234.md"
  assert_success
  assert_file_contains "contexts.sup" "ticket:\"DEVOPS-1234\""
  assert_file_contains "contexts.sup" "title:\"Fix the widget\""
  assert_file_contains "contexts.sup" "branch:\"devops-1234-fix-widget\""
  assert_file_contains "contexts.sup" "worktree:\"ds5\""
}

@test "import extracts linear url from markdown body" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-5678.md" <<'MDEOF'
# DEVOPS-5678 - Some ticket

Linear: https://linear.app/team/issue/DEVOPS-5678/some-ticket
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-5678.md"
  assert_success
  assert_file_contains "contexts.sup" "ticket_url:\"https://linear.app/team/issue/DEVOPS-5678/some-ticket\""
}

@test "import existing context imports data without duplicating metadata" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-9999.md" <<'MDEOF'
# DEVOPS-9999: Already here

## Decisions
- 2026-02-06: Some new decision
MDEOF

  mta create-context DEVOPS-9999 "Already here"
  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-9999.md"
  assert_success
  [[ "$output" == *"Imported data for existing context"* ]]
  # Should still have only one entry in contexts.sup
  local ctx_count
  ctx_count=$(grep -c "DEVOPS-9999" "$TEST_CONTEXTS_DIR/contexts.sup")
  [[ "$ctx_count" == "1" ]]
}

@test "import resolves filename from contexts dir" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-4321.md" <<'MDEOF'
# DEVOPS-4321: Lookup by name
MDEOF

  run mta import DEVOPS-4321.md
  assert_success
  assert_file_contains "contexts.sup" "ticket:\"DEVOPS-4321\""
}

# ==============================================================================
# Import Data Parsers
# ==============================================================================

@test "import sessions from Format A (session ID first)" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2001.md" <<'MDEOF'
# DEVOPS-2001: Session test A

## Linked Worktrees
- ds8/3fc75ec2: left 2026-01-29 (done) - Fixed VA reference
- ds8/59e9fe35: left 2026-01-30 (done) - No-Docker deploy
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2001.md"
  assert_success
  assert_file_exists "sessions.sup"
  assert_file_contains "sessions.sup" "session_id:\"ds8/3fc75ec2\""
  assert_file_contains "sessions.sup" "session_id:\"ds8/59e9fe35\""
  assert_file_contains "sessions.sup" "status:\"done\""
  assert_file_contains "sessions.sup" "note:\"Fixed VA reference\""
  [[ "$output" == *"Sessions:  2"* ]]
}

@test "import sessions from Format B (date first / departure log)" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2002.md" <<'MDEOF'
# DEVOPS-2002: Session test B

## Departure Log
- 2026-02-06 16:30: ds5/38555de5 left (status: done) - gradual scale-in deployed
- 2026-02-05 16:30: ds5/f2262467 left (status: done) - fixed throttling alert
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2002.md"
  assert_success
  assert_file_exists "sessions.sup"
  assert_file_contains "sessions.sup" "session_id:\"ds5/38555de5\""
  assert_file_contains "sessions.sup" "session_id:\"ds5/f2262467\""
  assert_file_contains "sessions.sup" "left_at:\"2026-02-06T16:30:00Z\""
  [[ "$output" == *"Sessions:  2"* ]]
}

@test "import sessions — joined-only gets left_at: null" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2003.md" <<'MDEOF'
# DEVOPS-2003: Joined only

## Linked Worktrees
- ds8/11f87c63: joined 2026-02-06
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2003.md"
  assert_success
  assert_file_contains "sessions.sup" "session_id:\"ds8/11f87c63\""
  assert_file_contains "sessions.sup" "joined_at:\"2026-02-06T00:00:00Z\""
  assert_file_contains "sessions.sup" "left_at:null"
}

@test "import sessions — left-only gets joined_at = left_at" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2004.md" <<'MDEOF'
# DEVOPS-2004: Left only

## Departure Log
- 2026-01-27 18:25: ds8 left (status: handoff) - diagnosed EnvType tag issue
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2004.md"
  assert_success
  # joined_at should equal left_at since only left was present
  assert_file_contains "sessions.sup" "joined_at:\"2026-01-27T18:25:00Z\""
  assert_file_contains "sessions.sup" "left_at:\"2026-01-27T18:25:00Z\""
}

@test "import decisions — bold with date + sub-bullets collapsed" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2005.md" <<'MDEOF'
# DEVOPS-2005: Decision test

## Recent Decisions
- **Direct API calls over MCP delegation** (2026-02-04)
  - Discussed whether dscops should connect to a Datadog MCP
  - Decided against: MCP client adds complexity
  - Direct API calls are simpler
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2005.md"
  assert_success
  assert_file_exists "decisions.sup"
  assert_file_contains "decisions.sup" "ts:\"2026-02-04T00:00:00Z\""
  assert_file_contains "decisions.sup" "Direct API calls over MCP delegation"
  # Sub-bullets should be collapsed with "; "
  assert_file_contains "decisions.sup" "Discussed whether"
  assert_file_contains "decisions.sup" "; Decided against"
  [[ "$output" == *"Decisions: 1"* ]]
}

@test "import decisions — timestamped inline" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2006.md" <<'MDEOF'
# DEVOPS-2006: Inline decisions

## Decisions
- 2026-02-06: Added 34.86.171.240 to cobalt_pentest_ips
- 2026-02-06: Kept existing 139.84.169.244 in list
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2006.md"
  assert_success
  assert_file_contains "decisions.sup" "ts:\"2026-02-06T00:00:00Z\""
  assert_file_contains "decisions.sup" "Added 34.86.171.240"
  assert_file_contains "decisions.sup" "Kept existing"
  [[ "$output" == *"Decisions: 2"* ]]
}

@test "import work log entries into decisions.sup" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2007.md" <<'MDEOF'
# DEVOPS-2007: Work log test

## Work Log
- 2026-02-09: Fixed stale syntax in shell scripts
  - datadog-events.sh: yield to values
  - zombie-instances.sh: yield to values
- 2026-02-06: Switched ALB OIDC from IAM to Okta
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2007.md"
  assert_success
  assert_file_exists "decisions.sup"
  assert_file_contains "decisions.sup" "Fixed stale syntax"
  assert_file_contains "decisions.sup" "Switched ALB"
  # Sub-bullets collapsed
  assert_file_contains "decisions.sup" "datadog-events.sh"
  [[ "$output" == *"Work log:  2"* ]]
}

@test "import tasks — checkbox format" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2008.md" <<'MDEOF'
# DEVOPS-2008: Task checkbox test

## To-Do
- [ ] Generate Datadog JSON dashboard
- [x] Add SSM permission to dev profile
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2008.md"
  assert_success
  assert_file_exists "tasks.sup"
  assert_file_contains "tasks.sup" "text:\"Generate Datadog JSON dashboard\""
  assert_file_contains "tasks.sup" "status:\"pending\""
  assert_file_contains "tasks.sup" "text:\"Add SSM permission to dev profile\""
  assert_file_contains "tasks.sup" "status:\"completed\""
  [[ "$output" == *"Tasks:     2"* ]]
}

@test "import tasks — strikethrough as completed" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2009.md" <<'MDEOF'
# DEVOPS-2009: Task strikethrough test

## Outstanding Tasks
- ~~Push app-base 1.3.0~~ DONE for staging
- Roll out to ALL stagings
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2009.md"
  assert_success
  assert_file_contains "tasks.sup" "text:\"Push app-base 1.3.0\""
  assert_file_contains "tasks.sup" "status:\"completed\""
  assert_file_contains "tasks.sup" "text:\"Roll out to ALL stagings\""
  assert_file_contains "tasks.sup" "status:\"pending\""
}

@test "import tasks — plain bullets as pending" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2010.md" <<'MDEOF'
# DEVOPS-2010: Plain task test

## Next Steps
- Update dashboards
- Consider warm pools
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2010.md"
  assert_success
  assert_file_contains "tasks.sup" "status:\"pending\""
  assert_file_contains "tasks.sup" "text:\"Update dashboards\""
  assert_file_contains "tasks.sup" "text:\"Consider warm pools\""
}

@test "import blockers — none indicators produce zero records" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2011.md" <<'MDEOF'
# DEVOPS-2011: No blockers test

## Blockers
None currently - ALB approach is straightforward
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2011.md"
  assert_success
  [[ "$output" == *"Blockers:  0"* ]]
  # blockers.sup should not exist or be empty
  [[ ! -f "$TEST_CONTEXTS_DIR/blockers.sup" ]]
}

@test "import blockers — strikethrough as resolved" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2012.md" <<'MDEOF'
# DEVOPS-2012: Resolved blockers test

## Blockers
- ~~2026-01-28 18:32: Lambda not evaluating ASG~~
  - FIXED 2026-01-28 18:40: Published Lambda v5
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2012.md"
  assert_success
  assert_file_exists "blockers.sup"
  assert_file_contains "blockers.sup" "text:\"Lambda not evaluating ASG\""
  # Should not have resolved:null
  ! grep -q "resolved:null" "$TEST_CONTEXTS_DIR/blockers.sup"
}

@test "import blockers — plain text as unresolved" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2013.md" <<'MDEOF'
# DEVOPS-2013: Unresolved blockers test

## Blockers
- Queue metrics not appearing on staging-15
- AMI confirmed via reports.sh
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2013.md"
  assert_success
  assert_file_contains "blockers.sup" "resolved:null"
  assert_file_contains "blockers.sup" "Queue metrics not appearing"
  assert_file_contains "blockers.sup" "AMI confirmed"
  [[ "$output" == *"Blockers:  2"* ]]
}

@test "import handles special characters (quotes, backticks)" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2014.md" <<'MDEOF'
# DEVOPS-2014: Special chars test

## Decisions
- 2026-02-06: Used "targeted" terraform apply with `--target` flag
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2014.md"
  assert_success
  assert_file_exists "decisions.sup"
  # Quotes should be escaped
  assert_file_contains "decisions.sup" 'targeted'
}

@test "import handles empty sections gracefully" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2015.md" <<'MDEOF'
# DEVOPS-2015: Empty sections test

## Decisions

## Blockers

## Outstanding Tasks
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2015.md"
  assert_success
  [[ "$output" == *"Decisions: 0"* ]]
  [[ "$output" == *"Blockers:  0"* ]]
  [[ "$output" == *"Tasks:     0"* ]]
}

@test "import reports counts in output" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2016.md" <<'MDEOF'
# DEVOPS-2016: Counts test

## Linked Worktrees
- ds8/abc12345: left 2026-01-29 (done) - test note

## Decisions
- 2026-02-06: Decision one
- 2026-02-06: Decision two

## Work Log
- 2026-02-09: Did some work

## To-Do
- [ ] Task one

## Blockers
- Something blocking
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2016.md"
  assert_success
  [[ "$output" == *"Sessions:  1"* ]]
  [[ "$output" == *"Decisions: 2"* ]]
  [[ "$output" == *"Work log:  1"* ]]
  [[ "$output" == *"Tasks:     1"* ]]
  [[ "$output" == *"Blockers:  1"* ]]
}

@test "re-import existing context imports data without duplicating metadata" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2017.md" <<'MDEOF'
# DEVOPS-2017: Re-import test

## Decisions
- 2026-02-06: Important decision

## Blockers
- A real blocker
MDEOF

  # First import creates context + data
  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2017.md"
  assert_success
  [[ "$output" == *"Imported: DEVOPS-2017"* ]]

  # Second import should still succeed (imports data, skips metadata)
  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2017.md"
  assert_success
  [[ "$output" == *"Imported data for existing context: DEVOPS-2017"* ]]
  [[ "$output" == *"Decisions: 1"* ]]
  [[ "$output" == *"Blockers:  1"* ]]

  # contexts.sup should have only ONE entry for this ticket
  local ctx_count
  ctx_count=$(grep -c "DEVOPS-2017" "$TEST_CONTEXTS_DIR/contexts.sup")
  [[ "$ctx_count" == "1" ]]
}

@test "import blockers — (none) indicator produces zero records" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2018.md" <<'MDEOF'
# DEVOPS-2018: None blocker test

## Blockers
(none)
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2018.md"
  assert_success
  [[ "$output" == *"Blockers:  0"* ]]
}

@test "import sessions from joined+left combo format" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2019.md" <<'MDEOF'
# DEVOPS-2019: Combo session test

## Linked Worktrees
- dscout/289d54ae: joined 2026-01-29, left 2026-01-29
- ds4/312d5cd3: joined 2026-02-06T16:00:00Z, left 2026-02-06
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2019.md"
  assert_success
  assert_file_contains "sessions.sup" "session_id:\"dscout/289d54ae\""
  assert_file_contains "sessions.sup" "session_id:\"ds4/312d5cd3\""
  assert_file_contains "sessions.sup" "joined_at:\"2026-01-29T00:00:00Z\""
  [[ "$output" == *"Sessions:  2"* ]]
}

@test "import tasks — numbered items as pending" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/DEVOPS-2020.md" <<'MDEOF'
# DEVOPS-2020: Numbered tasks test

## Next Steps
1. Update dashboards
2. Consider warm pools
3. Review PR
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/DEVOPS-2020.md"
  assert_success
  assert_file_contains "tasks.sup" "status:\"pending\""
  assert_file_contains "tasks.sup" "Update dashboards"
  assert_file_contains "tasks.sup" "Consider warm pools"
  assert_file_contains "tasks.sup" "Review PR"
  [[ "$output" == *"Tasks:     3"* ]]
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
