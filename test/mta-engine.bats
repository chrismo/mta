#!/usr/bin/env bats
# mta-engine.bats - Tests for mta-engine
#
# Run with: bats --jobs 8 test/mta-engine.bats
# Install bats: brew install bats-core (macOS) or apt install bats (linux)
#
# Tests marked with require_super will be skipped if super CLI is not installed.
# This allows running write-operation tests even without super.

load test_helper

# ==============================================================================
# Context Management
# ==============================================================================

@test "create-context creates contexts.sup if it doesn't exist" {
  run mta create-context PROJ-1641 "Upgrade auth service"
  assert_success
  assert_file_exists "contexts.sup"
}

@test "create-context adds record with required fields" {
  run mta create-context PROJ-1641 "Upgrade auth service"
  assert_success
  assert_file_contains "contexts.sup" "ticket:\"PROJ-1641\""
  assert_file_contains "contexts.sup" "title:\"Upgrade auth service\""
}

@test "create-context accepts optional flags" {
  run mta create-context PROJ-1641 "Upgrade auth service" \
    --ticket-url="https://tracker.example.com/PROJ-1641" \
    --branch="proj-101-auth" \
    --worktree="ds5"
  assert_success
  assert_file_contains "contexts.sup" "ticket_url:\"https://tracker.example.com/PROJ-1641\""
  assert_file_contains "contexts.sup" "branch:\"proj-101-auth\""
  assert_file_contains "contexts.sup" "worktree:\"ds5\""
}

@test "create-context sets created timestamp" {
  run mta create-context PROJ-1641 "Upgrade auth service"
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
  mta create-context PROJ-1641 "Upgrade auth service"
  mta create-context PROJ-1670 "CI experiment"

  run mta list-contexts
  assert_success
  [[ "$output" == *"PROJ-1641"* ]]
  [[ "$output" == *"PROJ-1670"* ]]
}

@test "get-context returns specific context" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service" --worktree=ds5
  mta create-context PROJ-1670 "CI experiment"

  run mta get-context PROJ-1641
  assert_success
  [[ "$output" == *"PROJ-1641"* ]]
  [[ "$output" == *"ds5"* ]]
  [[ "$output" != *"PROJ-1670"* ]]
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
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta join PROJ-1641 ds5/abc123
  assert_success
  assert_file_exists "sessions.sup"
}

@test "join creates session record with correct fields" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta join PROJ-1641 ds5/abc123
  assert_success
  assert_file_contains "sessions.sup" "ticket:\"PROJ-1641\""
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
  mta create-context PROJ-1641 "Upgrade auth service"
  mta join PROJ-1641 ds5/abc123

  run mta leave PROJ-1641 ds5/abc123 handoff "diagnosed the issue"
  assert_success
  # left_at should no longer be null
  ! grep -q "session_id:\"ds5/abc123\".*left_at:null" "$TEST_CONTEXTS_DIR/sessions.sup"
}

@test "leave records status and note" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta join PROJ-1641 ds5/abc123

  run mta leave PROJ-1641 ds5/abc123 handoff "diagnosed the issue"
  assert_success
  assert_file_contains "sessions.sup" "status:\"handoff\""
  assert_file_contains "sessions.sup" "note:\"diagnosed the issue\""
}

@test "list-sessions shows all sessions" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta join PROJ-1641 ds5/session1
  mta join PROJ-1641 ds5/session2

  run mta list-sessions
  assert_success
  [[ "$output" == *"ds5/session1"* ]]
  [[ "$output" == *"ds5/session2"* ]]
}

@test "list-sessions filters by ticket" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta create-context PROJ-1670 "CI experiment"
  mta join PROJ-1641 ds5/session1
  mta join PROJ-1670 ds9/session2

  run mta list-sessions PROJ-1641
  assert_success
  [[ "$output" == *"ds5/session1"* ]]
  [[ "$output" != *"ds9/session2"* ]]
}

# ==============================================================================
# Decisions
# ==============================================================================

@test "add-decision creates decisions.sup" {
  run mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-decision PROJ-1641 "AUTH MIGRATION E2E VERIFIED"
  assert_success
  assert_file_exists "decisions.sup"
}

@test "add-decision records decision with timestamp" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-decision PROJ-1641 "AUTH MIGRATION E2E VERIFIED"
  assert_success
  assert_file_contains "decisions.sup" "ticket:\"PROJ-1641\""
  assert_file_contains "decisions.sup" "text:\"AUTH MIGRATION E2E VERIFIED\""
  assert_file_contains "decisions.sup" "ts:\""
}

@test "list-decisions shows decisions for ticket" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-decision PROJ-1641 "Decision one"
  mta add-decision PROJ-1641 "Decision two"

  run mta list-decisions PROJ-1641
  assert_success
  [[ "$output" == *"Decision one"* ]]
  [[ "$output" == *"Decision two"* ]]
}

# ==============================================================================
# Tasks
# ==============================================================================

@test "add-task creates tasks.sup" {
  run mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-task PROJ-1641 "Add deploy permission"
  assert_success
  assert_file_exists "tasks.sup"
}

@test "add-task creates pending task" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-task PROJ-1641 "Add deploy permission"
  assert_success
  assert_file_contains "tasks.sup" "status:\"pending\""
  assert_file_contains "tasks.sup" "text:\"Add deploy permission\""
}

@test "complete-task marks task as completed" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-task PROJ-1641 "Add deploy permission"

  run mta complete-task PROJ-1641 "deploy permission"
  assert_success
  # Should have status:completed (or similar)
  assert_file_contains "tasks.sup" "status:\"completed\""
}

@test "list-tasks shows all tasks" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-task PROJ-1641 "Task one"
  mta add-task PROJ-1641 "Task two"

  run mta list-tasks PROJ-1641
  assert_success
  [[ "$output" == *"Task one"* ]]
  [[ "$output" == *"Task two"* ]]
}

@test "list-tasks --pending filters to pending only" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-task PROJ-1641 "Task one"
  mta add-task PROJ-1641 "Task two"
  mta complete-task PROJ-1641 "Task one"

  run mta list-tasks PROJ-1641 --pending
  assert_success
  [[ "$output" != *"Task one"* ]]
  [[ "$output" == *"Task two"* ]]
}

# ==============================================================================
# Blockers
# ==============================================================================

@test "add-blocker creates blockers.sup" {
  run mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-blocker PROJ-1641 "Wiki page requires auth"
  assert_success
  assert_file_exists "blockers.sup"
}

@test "add-blocker creates unresolved blocker" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-blocker PROJ-1641 "Wiki page requires auth"
  assert_success
  assert_file_contains "blockers.sup" "resolved:null"
  assert_file_contains "blockers.sup" "text:\"Wiki page requires auth\""
}

@test "resolve-blocker marks blocker as resolved" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-blocker PROJ-1641 "Wiki page requires auth"

  run mta resolve-blocker PROJ-1641 "Wiki"
  assert_success
  # resolved should no longer be null
  ! grep -q 'text:"Wiki page requires auth".*resolved:null' "$TEST_CONTEXTS_DIR/blockers.sup"
}

@test "list-blockers --unresolved shows only unresolved" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-blocker PROJ-1641 "Blocker one"
  mta add-blocker PROJ-1641 "Blocker two"
  mta resolve-blocker PROJ-1641 "Blocker one"

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
  mta create-context PROJ-1641 "Upgrade auth service"
  mta join PROJ-1641 ds5/abc123
  mta add-decision PROJ-1641 "Key decision"
  mta add-task PROJ-1641 "Remaining work"
  mta add-blocker PROJ-1641 "Something blocking"

  run mta status PROJ-1641
  assert_success
  [[ "$output" == *"PROJ-1641"* ]]
}

@test "archive moves context to archived state" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta archive PROJ-1641
  assert_success

  # Context should be marked archived
  assert_file_contains "contexts.sup" "archived_at:\""
}

@test "unarchive restores archived context" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta archive PROJ-1641

  run mta unarchive PROJ-1641
  assert_success
  [[ "$output" == *"Unarchived: PROJ-1641"* ]]

  # Context should have archived_at:null again
  assert_file_contains "contexts.sup" "archived_at:null"
}

@test "unarchive fails on non-archived context" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta unarchive PROJ-1641
  assert_failure
  [[ "$output" == *"not archived"* ]]
}

@test "unarchive fails on missing context" {
  run mta unarchive NONEXISTENT
  assert_failure
}

# ==============================================================================
# Edge Cases & Error Handling
# ==============================================================================

@test "handles special characters in titles" {
  run mta create-context PROJ-1641 "Fix \"quoted\" and 'apostrophe' issues"
  assert_success
}

@test "handles special characters in notes" {
  require_super
  mta create-context PROJ-1641 "Test"
  mta join PROJ-1641 ds5/abc123

  run mta leave PROJ-1641 ds5/abc123 handoff "Note with \"quotes\" and newline\ncharacter"
  assert_success
}

@test "handles slashes in notes" {
  require_super
  mta create-context PROJ-1641 "Test"
  mta join PROJ-1641 ds5/abc123

  run mta leave PROJ-1641 ds5/abc123 handoff "Fixed path/to/file and used s/old/new/ pattern"
  assert_success
  assert_file_contains "sessions.sup" "Fixed path/to/file"
}

@test "concurrent sessions for same ticket" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta join PROJ-1641 ds5/session1
  mta join PROJ-1641 ds8/session2

  # Both should be active
  run mta list-sessions PROJ-1641
  assert_success
  [[ "$output" == *"ds5/session1"* ]]
  [[ "$output" == *"ds8/session2"* ]]
}

# ==============================================================================
# Import
# ==============================================================================

@test "import extracts ticket and title from markdown heading" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-1234.md" <<'MDEOF'
# PROJ-1234: Fix the widget

## Summary
Some work on widgets.

Branch: proj-1234-fix-widget
Worktree: ds5
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-1234.md"
  assert_success
  assert_file_contains "contexts.sup" "ticket:\"PROJ-1234\""
  assert_file_contains "contexts.sup" "title:\"Fix the widget\""
  assert_file_contains "contexts.sup" "branch:\"proj-1234-fix-widget\""
  assert_file_contains "contexts.sup" "worktree:\"ds5\""
}

@test "import extracts github issues url from markdown body" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-5678.md" <<'MDEOF'
# PROJ-5678 - Some ticket

URL: https://github.com/acme/project/issues/5678
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-5678.md"
  assert_success
  assert_file_contains "contexts.sup" "ticket_url:\"https://github.com/acme/project/issues/5678\""
}

@test "import existing context imports data without duplicating metadata" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-9999.md" <<'MDEOF'
# PROJ-9999: Already here

## Decisions
- 2026-02-06: Some new decision
MDEOF

  mta create-context PROJ-9999 "Already here"
  run mta import "$TEST_CONTEXTS_DIR/PROJ-9999.md"
  assert_success
  [[ "$output" == *"Imported data for existing context"* ]]
  # Should still have only one entry in contexts.sup
  local ctx_count
  ctx_count=$(grep -c "PROJ-9999" "$TEST_CONTEXTS_DIR/contexts.sup")
  [[ "$ctx_count" == "1" ]]
}

@test "import resolves filename from contexts dir" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-4321.md" <<'MDEOF'
# PROJ-4321: Lookup by name
MDEOF

  run mta import PROJ-4321.md
  assert_success
  assert_file_contains "contexts.sup" "ticket:\"PROJ-4321\""
}

# ==============================================================================
# Import Data Parsers
# ==============================================================================

@test "import sessions from Format A (session ID first)" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2001.md" <<'MDEOF'
# PROJ-2001: Session test A

## Linked Worktrees
- ds8/3fc75ec2: left 2026-01-29 (done) - Fixed VA reference
- ds8/59e9fe35: left 2026-01-30 (done) - No-Docker deploy
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2001.md"
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
  cat > "$TEST_CONTEXTS_DIR/PROJ-2002.md" <<'MDEOF'
# PROJ-2002: Session test B

## Departure Log
- 2026-02-06 16:30: ds5/38555de5 left (status: done) - gradual scale-in deployed
- 2026-02-05 16:30: ds5/f2262467 left (status: done) - fixed throttling alert
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2002.md"
  assert_success
  assert_file_exists "sessions.sup"
  assert_file_contains "sessions.sup" "session_id:\"ds5/38555de5\""
  assert_file_contains "sessions.sup" "session_id:\"ds5/f2262467\""
  assert_file_contains "sessions.sup" "left_at:\"2026-02-06T16:30:00Z\""
  [[ "$output" == *"Sessions:  2"* ]]
}

@test "import sessions — joined-only gets left_at: null" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2003.md" <<'MDEOF'
# PROJ-2003: Joined only

## Linked Worktrees
- ds8/11f87c63: joined 2026-02-06
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2003.md"
  assert_success
  assert_file_contains "sessions.sup" "session_id:\"ds8/11f87c63\""
  assert_file_contains "sessions.sup" "joined_at:\"2026-02-06T00:00:00Z\""
  assert_file_contains "sessions.sup" "left_at:null"
}

@test "import sessions — left-only gets joined_at = left_at" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2004.md" <<'MDEOF'
# PROJ-2004: Left only

## Departure Log
- 2026-01-27 18:25: ds8 left (status: handoff) - diagnosed EnvType tag issue
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2004.md"
  assert_success
  # joined_at should equal left_at since only left was present
  assert_file_contains "sessions.sup" "joined_at:\"2026-01-27T18:25:00Z\""
  assert_file_contains "sessions.sup" "left_at:\"2026-01-27T18:25:00Z\""
}

@test "import decisions — bold with date + sub-bullets collapsed" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2005.md" <<'MDEOF'
# PROJ-2005: Decision test

## Recent Decisions
- **Direct API calls over MCP delegation** (2026-02-04)
  - Discussed whether devtools should connect to a metrics MCP
  - Decided against: MCP client adds complexity
  - Direct API calls are simpler
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2005.md"
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
  cat > "$TEST_CONTEXTS_DIR/PROJ-2006.md" <<'MDEOF'
# PROJ-2006: Inline decisions

## Decisions
- 2026-02-06: Added 10.0.1.100 to security_allowlist
- 2026-02-06: Kept existing 10.0.1.200 in list
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2006.md"
  assert_success
  assert_file_contains "decisions.sup" "ts:\"2026-02-06T00:00:00Z\""
  assert_file_contains "decisions.sup" "Added 10.0.1.100"
  assert_file_contains "decisions.sup" "Kept existing"
  [[ "$output" == *"Decisions: 2"* ]]
}

@test "import work log entries into decisions.sup" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2007.md" <<'MDEOF'
# PROJ-2007: Work log test

## Work Log
- 2026-02-09: Fixed stale syntax in shell scripts
  - datadog-events.sh: yield to values
  - zombie-instances.sh: yield to values
- 2026-02-06: Switched ALB OIDC from IAM to Okta
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2007.md"
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
  cat > "$TEST_CONTEXTS_DIR/PROJ-2008.md" <<'MDEOF'
# PROJ-2008: Task checkbox test

## To-Do
- [ ] Generate Datadog JSON dashboard
- [x] Add deploy permission to dev profile
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2008.md"
  assert_success
  assert_file_exists "tasks.sup"
  assert_file_contains "tasks.sup" "text:\"Generate Datadog JSON dashboard\""
  assert_file_contains "tasks.sup" "status:\"pending\""
  assert_file_contains "tasks.sup" "text:\"Add deploy permission to dev profile\""
  assert_file_contains "tasks.sup" "status:\"completed\""
  [[ "$output" == *"Tasks:     2"* ]]
}

@test "import tasks — strikethrough as completed" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2009.md" <<'MDEOF'
# PROJ-2009: Task strikethrough test

## Outstanding Tasks
- ~~Push app-base 1.3.0~~ DONE for staging
- Roll out to ALL stagings
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2009.md"
  assert_success
  assert_file_contains "tasks.sup" "text:\"Push app-base 1.3.0\""
  assert_file_contains "tasks.sup" "status:\"completed\""
  assert_file_contains "tasks.sup" "text:\"Roll out to ALL stagings\""
  assert_file_contains "tasks.sup" "status:\"pending\""
}

@test "import tasks — plain bullets as pending" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2010.md" <<'MDEOF'
# PROJ-2010: Plain task test

## Next Steps
- Update dashboards
- Consider warm pools
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2010.md"
  assert_success
  assert_file_contains "tasks.sup" "status:\"pending\""
  assert_file_contains "tasks.sup" "text:\"Update dashboards\""
  assert_file_contains "tasks.sup" "text:\"Consider warm pools\""
}

@test "import blockers — none indicators produce zero records" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2011.md" <<'MDEOF'
# PROJ-2011: No blockers test

## Blockers
None currently - ALB approach is straightforward
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2011.md"
  assert_success
  [[ "$output" == *"Blockers:  0"* ]]
  # blockers.sup should not exist or be empty
  [[ ! -f "$TEST_CONTEXTS_DIR/blockers.sup" ]]
}

@test "import blockers — strikethrough as resolved" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2012.md" <<'MDEOF'
# PROJ-2012: Resolved blockers test

## Blockers
- ~~2026-01-28 18:32: Lambda not evaluating ASG~~
  - FIXED 2026-01-28 18:40: Published Lambda v5
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2012.md"
  assert_success
  assert_file_exists "blockers.sup"
  assert_file_contains "blockers.sup" "text:\"Lambda not evaluating ASG\""
  # Should not have resolved:null
  ! grep -q "resolved:null" "$TEST_CONTEXTS_DIR/blockers.sup"
}

@test "import blockers — plain text as unresolved" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2013.md" <<'MDEOF'
# PROJ-2013: Unresolved blockers test

## Blockers
- Queue metrics not appearing on staging-15
- AMI confirmed via reports.sh
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2013.md"
  assert_success
  assert_file_contains "blockers.sup" "resolved:null"
  assert_file_contains "blockers.sup" "Queue metrics not appearing"
  assert_file_contains "blockers.sup" "AMI confirmed"
  [[ "$output" == *"Blockers:  2"* ]]
}

@test "import handles special characters (quotes, backticks)" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2014.md" <<'MDEOF'
# PROJ-2014: Special chars test

## Decisions
- 2026-02-06: Used "targeted" terraform apply with `--target` flag
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2014.md"
  assert_success
  assert_file_exists "decisions.sup"
  # Quotes should be escaped
  assert_file_contains "decisions.sup" 'targeted'
}

@test "import handles empty sections gracefully" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2015.md" <<'MDEOF'
# PROJ-2015: Empty sections test

## Decisions

## Blockers

## Outstanding Tasks
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2015.md"
  assert_success
  [[ "$output" == *"Decisions: 0"* ]]
  [[ "$output" == *"Blockers:  0"* ]]
  [[ "$output" == *"Tasks:     0"* ]]
}

@test "import reports counts in output" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2016.md" <<'MDEOF'
# PROJ-2016: Counts test

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

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2016.md"
  assert_success
  [[ "$output" == *"Sessions:  1"* ]]
  [[ "$output" == *"Decisions: 2"* ]]
  [[ "$output" == *"Work log:  1"* ]]
  [[ "$output" == *"Tasks:     1"* ]]
  [[ "$output" == *"Blockers:  1"* ]]
}

@test "re-import existing context imports data without duplicating metadata" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2017.md" <<'MDEOF'
# PROJ-2017: Re-import test

## Decisions
- 2026-02-06: Important decision

## Blockers
- A real blocker
MDEOF

  # First import creates context + data
  run mta import "$TEST_CONTEXTS_DIR/PROJ-2017.md"
  assert_success
  [[ "$output" == *"Imported: PROJ-2017"* ]]

  # Second import should still succeed (imports data, skips metadata)
  run mta import "$TEST_CONTEXTS_DIR/PROJ-2017.md"
  assert_success
  [[ "$output" == *"Imported data for existing context: PROJ-2017"* ]]
  [[ "$output" == *"Decisions: 1"* ]]
  [[ "$output" == *"Blockers:  1"* ]]

  # contexts.sup should have only ONE entry for this ticket
  local ctx_count
  ctx_count=$(grep -c "PROJ-2017" "$TEST_CONTEXTS_DIR/contexts.sup")
  [[ "$ctx_count" == "1" ]]
}

@test "import blockers — (none) indicator produces zero records" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2018.md" <<'MDEOF'
# PROJ-2018: None blocker test

## Blockers
(none)
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2018.md"
  assert_success
  [[ "$output" == *"Blockers:  0"* ]]
}

@test "import sessions from joined+left combo format" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2019.md" <<'MDEOF'
# PROJ-2019: Combo session test

## Linked Worktrees
- repo/289d54ae: joined 2026-01-29, left 2026-01-29
- ds4/312d5cd3: joined 2026-02-06T16:00:00Z, left 2026-02-06
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2019.md"
  assert_success
  assert_file_contains "sessions.sup" "session_id:\"repo/289d54ae\""
  assert_file_contains "sessions.sup" "session_id:\"ds4/312d5cd3\""
  assert_file_contains "sessions.sup" "joined_at:\"2026-01-29T00:00:00Z\""
  [[ "$output" == *"Sessions:  2"* ]]
}

@test "import tasks — numbered items as pending" {
  require_super
  cat > "$TEST_CONTEXTS_DIR/PROJ-2020.md" <<'MDEOF'
# PROJ-2020: Numbered tasks test

## Next Steps
1. Update dashboards
2. Consider warm pools
3. Review PR
MDEOF

  run mta import "$TEST_CONTEXTS_DIR/PROJ-2020.md"
  assert_success
  assert_file_contains "tasks.sup" "status:\"pending\""
  assert_file_contains "tasks.sup" "Update dashboards"
  assert_file_contains "tasks.sup" "Consider warm pools"
  assert_file_contains "tasks.sup" "Review PR"
  [[ "$output" == *"Tasks:     3"* ]]
}

# ==============================================================================
# Chunks (RISC grading)
# ==============================================================================

@test "add-chunk creates chunks.sup" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "ceiling calc utility using bc" 3
  assert_success
  assert_file_exists "chunks.sup"
}

@test "add-chunk records chunk with required fields" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "ceiling calc utility" 3
  assert_success
  assert_file_contains "chunks.sup" "ticket:\"PROJ-1641\""
  assert_file_contains "chunks.sup" "commit:\"a3f7e2b\""
  assert_file_contains "chunks.sup" "summary:\"ceiling calc utility\""
  assert_file_contains "chunks.sup" "risc:3"
  assert_file_contains "chunks.sup" "reviewed_at:null"
}

@test "add-chunk accepts optional files and risc-reason flags" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "ceiling calc" 3 \
    --files="src/math.sh,src/util.sh" \
    --risc-reason="pure function, isolated"
  assert_success
  assert_file_contains "chunks.sup" "files:\"src/math.sh,src/util.sh\""
  assert_file_contains "chunks.sup" "risc_reason:\"pure function, isolated\""
}

@test "add-chunk sets timestamp" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "some change" 5
  assert_success
  assert_file_contains "chunks.sup" "ts:\"20"
}

@test "add-chunk fails without required args" {
  run mta add-chunk PROJ-1641 a3f7e2b
  assert_failure
}

@test "add-chunk handles special characters in summary" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "Fix \"quoted\" path/to/file" 4
  assert_success
  assert_file_contains "chunks.sup" "path/to/file"
}

@test "add-chunk allows multiple chunks for same commit" {
  mta create-context PROJ-1641 "Upgrade auth service"

  mta add-chunk PROJ-1641 a3f7e2b "retry backoff logic" 8 --files="src/sync.sh,src/async.sh"
  mta add-chunk PROJ-1641 a3f7e2b "test scaffolding" 1 --files="test/retry.test.sh"

  local chunk_count
  chunk_count=$(grep -c "commit:\"a3f7e2b\"" "$TEST_CONTEXTS_DIR/chunks.sup")
  [[ "$chunk_count" == "2" ]]
}

# ==============================================================================
# List Chunks
# ==============================================================================

@test "list-chunks shows chunks for a ticket" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing" 2

  run mta list-chunks PROJ-1641
  assert_success
  [[ "$output" == *"retry logic"* ]]
  [[ "$output" == *"config plumbing"* ]]
}

@test "list-chunks --unreviewed shows only unreviewed chunks" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing" 2
  mta review-chunk PROJ-1641 "config plumbing"

  run mta list-chunks PROJ-1641 --unreviewed
  assert_success
  [[ "$output" == *"retry logic"* ]]
  [[ "$output" != *"config plumbing"* ]]
}

@test "list-chunks filters by ticket" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta create-context PROJ-1670 "CI experiment"
  mta add-chunk PROJ-1641 a3f7e2b "auth change" 7
  mta add-chunk PROJ-1670 c5d6e7f "ci tweak" 2

  run mta list-chunks PROJ-1641
  assert_success
  [[ "$output" == *"auth change"* ]]
  [[ "$output" != *"ci tweak"* ]]
}

# ==============================================================================
# Review Chunk
# ==============================================================================

@test "review-chunk marks chunk as reviewed" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta review-chunk PROJ-1641 "retry logic"
  assert_success
  # reviewed_at should no longer be null for this chunk
  ! grep -q 'summary:"retry logic".*reviewed_at:null' "$TEST_CONTEXTS_DIR/chunks.sup"
}

@test "review-chunk sets reviewed_at timestamp" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta review-chunk PROJ-1641 "retry logic"
  assert_success
  assert_file_contains "chunks.sup" "reviewed_at:\"20"
}

@test "review-chunk fails for nonexistent chunk" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta review-chunk PROJ-1641 "nonexistent"
  assert_failure
}

@test "review-chunk only marks first matching unreviewed chunk" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing" 2

  mta review-chunk PROJ-1641 "retry logic"

  # config plumbing should still be unreviewed
  grep -q 'summary:"config plumbing".*reviewed_at:null' "$TEST_CONTEXTS_DIR/chunks.sup"
}

@test "review-chunk scopes to ticket — same summary in different tickets" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta create-context PROJ-1670 "CI experiment"
  mta add-chunk PROJ-1641 a3f7e2b "config plumbing" 5
  mta add-chunk PROJ-1670 c5d6e7f "config plumbing" 2

  mta review-chunk PROJ-1670 "config plumbing"

  # PROJ-1641's chunk should still be unreviewed
  grep -q 'ticket:"PROJ-1641".*summary:"config plumbing".*reviewed_at:null' "$TEST_CONTEXTS_DIR/chunks.sup"
  # PROJ-1670's chunk should be reviewed
  ! grep -q 'ticket:"PROJ-1670".*summary:"config plumbing".*reviewed_at:null' "$TEST_CONTEXTS_DIR/chunks.sup"
}

# ==============================================================================
# Add-chunk validation
# ==============================================================================

@test "add-chunk rejects non-integer risc" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "some change" "abc"
  assert_failure
}

@test "add-chunk rejects risc below 1" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "some change" 0
  assert_failure
}

@test "add-chunk rejects risc above 10" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "some change" 11
  assert_failure
}

@test "add-chunk accepts risc at boundaries" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "low end" 1
  assert_success
  run mta add-chunk PROJ-1641 b8c1d4e "high end" 10
  assert_success
}

# ==============================================================================
# Flexible chunk granularity (multi-commit, line ranges)
# ==============================================================================

@test "add-chunk accepts multi-commit SHAs" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 "a3f7e2b,b8c1d4e" "IAM workaround" 7
  assert_success
  assert_file_contains "chunks.sup" "commit:\"a3f7e2b,b8c1d4e\""
}

@test "add-chunk accepts --lines flag" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "timer activation fix" 6 \
    --files="update-sources.sh" --lines="update-sources.sh:42-58"
  assert_success
  assert_file_contains "chunks.sup" "lines:\"update-sources.sh:42-58\""
}

@test "add-chunk accepts multi-file line ranges" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 "a3f7e2b,b8c1d4e" "IAM workaround" 7 \
    --files="export-data.sh,rescue-chunks.sh" \
    --lines="export-data.sh:120-135,rescue-chunks.sh:1-40"
  assert_success
  assert_file_contains "chunks.sup" "lines:\"export-data.sh:120-135,rescue-chunks.sh:1-40\""
  assert_file_contains "chunks.sup" "commit:\"a3f7e2b,b8c1d4e\""
}

@test "add-chunk without --lines omits lines field" {
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta add-chunk PROJ-1641 a3f7e2b "config cleanup" 2 \
    --files="config-a.sh,config-b.sh"
  assert_success
  ! grep -q "lines:" "$TEST_CONTEXTS_DIR/chunks.sup"
}

@test "list-chunks shows chunks with lines field" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "timer fix" 6 \
    --files="update-sources.sh" --lines="update-sources.sh:42-58"

  run mta list-chunks PROJ-1641
  assert_success
  [[ "$output" == *"timer fix"* ]]
}

@test "review-chunk works with multi-commit chunks" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 "a3f7e2b,b8c1d4e" "IAM workaround" 7

  run mta review-chunk PROJ-1641 "IAM workaround"
  assert_success
  ! grep -q 'summary:"IAM workaround".*reviewed_at:null' "$TEST_CONTEXTS_DIR/chunks.sup"
}

@test "review-chunk works with chunks that have lines" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "timer fix" 6 \
    --files="update-sources.sh" --lines="update-sources.sh:42-58"

  run mta review-chunk PROJ-1641 "timer fix"
  assert_success
  ! grep -q 'summary:"timer fix".*reviewed_at:null' "$TEST_CONTEXTS_DIR/chunks.sup"
}

# ==============================================================================
# Update Chunk
# ==============================================================================

@test "update-chunk fails without required args" {
  run mta update-chunk
  assert_failure

  run mta update-chunk PROJ-1641
  assert_failure
}

@test "update-chunk fails without any update flag" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta update-chunk PROJ-1641 "retry logic"
  assert_failure
}

@test "update-chunk updates risc score" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta update-chunk PROJ-1641 "retry logic" --risc=3
  assert_success
  assert_file_contains "chunks.sup" "risc:3"
  assert_file_not_contains "chunks.sup" "risc:8"
}

@test "update-chunk updates summary" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta update-chunk PROJ-1641 "retry logic" --summary="retry backoff logic"
  assert_success
  assert_file_contains "chunks.sup" "summary:\"retry backoff logic\""
  assert_file_not_contains "chunks.sup" "summary:\"retry logic\""
}

@test "update-chunk updates files, lines, risc-reason" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8 \
    --files="old.sh" --lines="old.sh:1-10" --risc-reason="old reason"

  run mta update-chunk PROJ-1641 "retry logic" \
    --files="new.sh" --lines="new.sh:5-20" --risc-reason="new reason"
  assert_success
  assert_file_contains "chunks.sup" "files:\"new.sh\""
  assert_file_contains "chunks.sup" "lines:\"new.sh:5-20\""
  assert_file_contains "chunks.sup" "risc_reason:\"new reason\""
}

@test "update-chunk rejects invalid risc" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta update-chunk PROJ-1641 "retry logic" --risc=0
  assert_failure

  run mta update-chunk PROJ-1641 "retry logic" --risc=11
  assert_failure

  run mta update-chunk PROJ-1641 "retry logic" --risc=abc
  assert_failure
}

@test "update-chunk fails for nonexistent chunk" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta update-chunk PROJ-1641 "nonexistent" --risc=5
  assert_failure
}

@test "update-chunk only updates first match" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "config plumbing" 5
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing v2" 3

  mta update-chunk PROJ-1641 "config plumbing" --risc=1

  # First match updated to risc:1, second still risc:3
  assert_file_contains "chunks.sup" "risc:1"
  assert_file_contains "chunks.sup" "risc:3"
}

@test "update-chunk preserves unmodified fields" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8 \
    --files="src/sync.sh" --risc-reason="complex retry"

  run mta update-chunk PROJ-1641 "retry logic" --risc=3
  assert_success
  # risc changed
  assert_file_contains "chunks.sup" "risc:3"
  # other fields preserved
  assert_file_contains "chunks.sup" "summary:\"retry logic\""
  assert_file_contains "chunks.sup" "files:\"src/sync.sh\""
  assert_file_contains "chunks.sup" "risc_reason:\"complex retry\""
  assert_file_contains "chunks.sup" "commit:\"a3f7e2b\""
}

# ==============================================================================
# Delete Chunk
# ==============================================================================

@test "delete-chunk fails without required args" {
  run mta delete-chunk
  assert_failure

  run mta delete-chunk PROJ-1641
  assert_failure
}

@test "delete-chunk deletes chunk by pattern" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing" 2

  run mta delete-chunk PROJ-1641 "retry logic"
  assert_success
  assert_file_not_contains "chunks.sup" "retry logic"
  assert_file_contains "chunks.sup" "config plumbing"
}

@test "delete-chunk fails for nonexistent chunk" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta delete-chunk PROJ-1641 "nonexistent"
  assert_failure
}

@test "delete-chunk only deletes first match" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "config plumbing" 5
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing v2" 3

  mta delete-chunk PROJ-1641 "config plumbing"

  # First match deleted, second still present
  assert_file_contains "chunks.sup" "config plumbing"
  # Only one line should remain with "config plumbing"
  local count
  count=$(grep -c "config plumbing" "$TEST_CONTEXTS_DIR/chunks.sup")
  [[ "$count" == "1" ]]
}

@test "delete-chunk record no longer in file" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "only chunk" 5

  mta delete-chunk PROJ-1641 "only chunk"

  assert_file_not_contains "chunks.sup" "only chunk"
}

# ==============================================================================
# Debt
# ==============================================================================

@test "debt shows unreviewed chunk summary for a ticket" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing" 2

  run mta debt PROJ-1641
  assert_success
  [[ "$output" == *"2 unreviewed"* ]]
}

@test "debt shows weighted score" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing" 2

  run mta debt PROJ-1641
  assert_success
  # weighted debt = sum of risc scores of unreviewed chunks = 8 + 2 = 10
  [[ "$output" == *"weighted: 10"* ]]
}

@test "debt decreases after review" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing" 2
  mta review-chunk PROJ-1641 "config plumbing"

  run mta debt PROJ-1641
  assert_success
  [[ "$output" == *"1 unreviewed"* ]]
  [[ "$output" == *"weighted: 8"* ]]
}

@test "debt shows zero when all reviewed" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8
  mta review-chunk PROJ-1641 "retry logic"

  run mta debt PROJ-1641
  assert_success
  [[ "$output" == *"0 unreviewed"* ]]
  [[ "$output" == *"weighted: 0"* ]]
}

@test "debt with no ticket shows all active contexts" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta create-context PROJ-1670 "CI experiment"
  mta add-chunk PROJ-1641 a3f7e2b "auth change" 7
  mta add-chunk PROJ-1670 c5d6e7f "ci tweak" 2

  run mta debt
  assert_success
  [[ "$output" == *"PROJ-1641"* ]]
  [[ "$output" == *"PROJ-1670"* ]]
}

@test "debt highlights high-RISC count" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing" 2
  mta add-chunk PROJ-1641 c9d0e1f "auth refactor" 9

  run mta debt PROJ-1641
  assert_success
  # chunks with risc >= 7 are "high-RISC"
  [[ "$output" == *"2 high-RISC"* ]]
}

# ==============================================================================
# RISC Component Scoring
# ==============================================================================

@test "add-chunk with component flags stores all four components and computed risc" {
  mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-chunk PROJ-1641 a3f7e2b "component chunk" 1 \
    --reach=2 --irrev=3 --subtle=1 --conseq=2
  assert_success
  assert_file_contains "chunks.sup" "reach:2"
  assert_file_contains "chunks.sup" "irrev:3"
  assert_file_contains "chunks.sup" "subtle:1"
  assert_file_contains "chunks.sup" "conseq:2"
  assert_file_contains "chunks.sup" "risc:8"
}

@test "add-chunk component mode caps combined risc at 10" {
  mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-chunk PROJ-1641 a3f7e2b "high risk chunk" 1 \
    --reach=4 --irrev=4 --subtle=4 --conseq=4
  assert_success
  assert_file_contains "chunks.sup" "risc:10"
  # Should NOT contain risc:16
  ! grep -q "risc:16" "$MTA_CONTEXTS_DIR/chunks.sup"
}

@test "add-chunk component mode boundary: all 1s gives risc 4" {
  mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-chunk PROJ-1641 a3f7e2b "low risk chunk" 1 \
    --reach=1 --irrev=1 --subtle=1 --conseq=1
  assert_success
  assert_file_contains "chunks.sup" "risc:4"
}

@test "add-chunk component mode boundary: 3+3+3+3 caps at 10" {
  mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-chunk PROJ-1641 a3f7e2b "boundary chunk" 1 \
    --reach=3 --irrev=3 --subtle=3 --conseq=3
  assert_success
  assert_file_contains "chunks.sup" "risc:10"
}

@test "add-chunk rejects component outside 1-10" {
  mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-chunk PROJ-1641 a3f7e2b "bad component" 1 \
    --reach=0 --irrev=3 --subtle=1 --conseq=2
  assert_failure
  [[ "$output" == *"must be an integer between 1 and 10"* ]]
}

@test "add-chunk rejects partial components" {
  mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-chunk PROJ-1641 a3f7e2b "partial components" 1 \
    --reach=2 --irrev=3
  assert_failure
  [[ "$output" == *"All four component flags required"* ]]
}

@test "add-chunk legacy positional risc still works" {
  mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-chunk PROJ-1641 a3f7e2b "legacy chunk" 5
  assert_success
  assert_file_contains "chunks.sup" "risc:5"
  # Should NOT contain component fields
  ! grep -q "reach:" "$MTA_CONTEXTS_DIR/chunks.sup"
  ! grep -q "irrev:" "$MTA_CONTEXTS_DIR/chunks.sup"
}

@test "add-chunk component and legacy chunks coexist in same file" {
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "legacy chunk" 5
  mta add-chunk PROJ-1641 b8c1d4e "component chunk" 1 \
    --reach=2 --irrev=3 --subtle=1 --conseq=2
  # Both should be present
  assert_file_contains "chunks.sup" "summary:\"legacy chunk\""
  assert_file_contains "chunks.sup" "summary:\"component chunk\""
  assert_file_contains "chunks.sup" "reach:2"
}

@test "update-chunk updates single component and recomputes risc" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "component chunk" 1 \
    --reach=2 --irrev=3 --subtle=1 --conseq=2
  # Original risc = 8, update reach to 1 → risc = min(1+3+1+2,10) = 7
  run mta update-chunk PROJ-1641 "component chunk" --reach=1
  assert_success
  local content
  content=$(cat "$MTA_CONTEXTS_DIR/chunks.sup")
  [[ "$content" == *"reach:1"* ]]
  [[ "$content" == *"irrev:3"* ]]
  [[ "$content" == *"risc:7"* ]]
}

@test "update-chunk errors when updating components on legacy chunk" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "legacy chunk" 5
  run mta update-chunk PROJ-1641 "legacy chunk" --reach=2
  assert_failure
  [[ "$output" == *"Cannot update components on legacy chunk"* ]]
}

@test "update-chunk errors when using --risc on component chunk" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "component chunk" 1 \
    --reach=2 --irrev=3 --subtle=1 --conseq=2
  run mta update-chunk PROJ-1641 "component chunk" --risc=5
  assert_failure
  [[ "$output" == *"Use component flags instead"* ]]
}

# ==============================================================================
# Branch field on chunks
# ==============================================================================

@test "add-chunk stores branch when --branch passed" {
  mta create-context PROJ-1641 "Upgrade auth service"
  run mta add-chunk PROJ-1641 a3f7e2b "branch test chunk" 3 --branch=feature/foo
  assert_success
  assert_file_contains "chunks.sup" 'branch:"feature/foo"'
}

@test "add-chunk auto-detects branch from git" {
  mta create-context PROJ-1641 "Upgrade auth service"

  # Create a git repo and branch in a temp dir
  local git_dir
  git_dir="$(mktemp -d)"
  git -C "$git_dir" init -b main >/dev/null 2>&1
  git -C "$git_dir" commit --allow-empty -m "init" >/dev/null 2>&1
  git -C "$git_dir" checkout -b feature/auto-detect >/dev/null 2>&1

  # Run add-chunk from inside the git repo (no --branch flag)
  (cd "$git_dir" && mta add-chunk PROJ-1641 a3f7e2b "auto branch chunk" 3)
  assert_file_contains "chunks.sup" 'branch:"feature/auto-detect"'

  rm -rf "$git_dir"
}

@test "add-chunk without git or --branch omits branch" {
  mta create-context PROJ-1641 "Upgrade auth service"

  # Run from a non-git temp dir
  local nogit_dir
  nogit_dir="$(mktemp -d)"
  (cd "$nogit_dir" && mta add-chunk PROJ-1641 a3f7e2b "no branch chunk" 3)
  assert_file_not_contains "chunks.sup" "branch:"

  rm -rf "$nogit_dir"
}

@test "list-chunks --branch filters by branch" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "chunk on main" 3 --branch=main
  mta add-chunk PROJ-1641 b8c1d4e "chunk on feature" 5 --branch=feature/foo

  run mta list-chunks PROJ-1641 --branch=main
  assert_success
  [[ "$output" == *"chunk on main"* ]]
  [[ "$output" != *"chunk on feature"* ]]
}

@test "list-chunks without --branch returns all" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "chunk on main" 3 --branch=main
  mta add-chunk PROJ-1641 b8c1d4e "chunk on feature" 5 --branch=feature/foo

  run mta list-chunks PROJ-1641
  assert_success
  [[ "$output" == *"chunk on main"* ]]
  [[ "$output" == *"chunk on feature"* ]]
}

@test "update-chunk --branch updates branch field" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "branch update chunk" 3 --branch=old-branch

  run mta update-chunk PROJ-1641 "branch update chunk" --branch=new-branch
  assert_success
  assert_file_contains "chunks.sup" 'branch:"new-branch"'
  assert_file_not_contains "chunks.sup" 'branch:"old-branch"'
}

@test "debt --branch filters by branch" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "main chunk" 8 --branch=main
  mta add-chunk PROJ-1641 b8c1d4e "feature chunk" 2 --branch=feature/foo

  run mta debt PROJ-1641 --branch=main
  assert_success
  # Should show 1 unreviewed with weighted 8 (only main chunk)
  [[ "$output" == *"1 unreviewed"* ]]
  [[ "$output" == *"weighted: 8"* ]]
}

@test "debt without --branch shows all" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "main chunk" 8 --branch=main
  mta add-chunk PROJ-1641 b8c1d4e "feature chunk" 2 --branch=feature/foo

  run mta debt PROJ-1641
  assert_success
  # Should show 2 unreviewed with weighted 10 (both chunks)
  [[ "$output" == *"2 unreviewed"* ]]
  [[ "$output" == *"weighted: 10"* ]]
}

@test "debt flags context with sessions but no chunks" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta join PROJ-1641 sess-001

  run mta debt PROJ-1641
  assert_success
  [[ "$output" == *"no chunks"* ]]
  [[ "$output" == *"/mta:chunk"* ]]
}

@test "debt flags unchunked contexts alongside chunked ones" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta create-context PROJ-1670 "CI experiment"
  mta join PROJ-1641 sess-001
  mta add-chunk PROJ-1670 c5d6e7f "ci tweak" 2

  run mta debt
  assert_success
  # PROJ-1641 has a session but no chunks — should be flagged
  [[ "$output" == *"PROJ-1641"* ]]
  [[ "$output" == *"no chunks"* ]]
  # PROJ-1670 has chunks — should show normal debt info
  [[ "$output" == *"PROJ-1670"* ]]
  [[ "$output" == *"1 unreviewed"* ]]
}

@test "debt does not flag context with no sessions and no chunks" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta debt PROJ-1641
  assert_success
  # No sessions, no chunks — nothing to flag
  [[ "$output" != *"no chunks"* ]]
  [[ "$output" == *"0 unreviewed"* ]]
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

# ==============================================================================
# --format flag on list commands
# ==============================================================================

@test "list-chunks --format=json outputs valid JSON" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta list-chunks PROJ-1641 --format=json
  assert_success
  # Should contain JSON object markers
  [[ "$output" == *"{"* ]]
  [[ "$output" == *"retry logic"* ]]
  # Should NOT contain box-drawing characters (table output)
  [[ "$output" != *"─"* ]]
  [[ "$output" != *"│"* ]]
}

@test "list-chunks --format=csv outputs CSV" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta list-chunks PROJ-1641 --format=csv
  assert_success
  # Should have header row with field names
  [[ "$output" == *"ticket"* ]]
  [[ "$output" == *"retry logic"* ]]
  # Should NOT contain box-drawing characters
  [[ "$output" != *"─"* ]]
  [[ "$output" != *"│"* ]]
}

@test "list-chunks --format=commits outputs one SHA per line" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8
  mta add-chunk PROJ-1641 b8c1d4e "config plumbing" 2

  run mta list-chunks PROJ-1641 --format=commits
  assert_success
  [[ "$output" == *"a3f7e2b"* ]]
  [[ "$output" == *"b8c1d4e"* ]]
  # Should be just SHAs, no table or JSON markers
  [[ "$output" != *"{"* ]]
  [[ "$output" != *"─"* ]]
}

@test "list-chunks --format=commits splits multi-commit SHAs" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 "abc1234,def5678" "cross-commit change" 5

  run mta list-chunks PROJ-1641 --format=commits
  assert_success
  # Each SHA should be on its own line
  local line_count
  line_count=$(echo "$output" | grep -c .)
  [[ "$line_count" -eq 2 ]]
  [[ "$output" == *"abc1234"* ]]
  [[ "$output" == *"def5678"* ]]
}

@test "list-chunks default format outputs table" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta list-chunks PROJ-1641
  assert_success
  # Should contain box-drawing characters (grdy table)
  [[ "$output" == *"─"* ]] || [[ "$output" == *"│"* ]] || [[ "$output" == *"|"* ]]
}

@test "list-chunks --format=invalid errors" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-chunk PROJ-1641 a3f7e2b "retry logic" 8

  run mta list-chunks PROJ-1641 --format=invalid
  assert_failure
  [[ "$output" == *"Unknown format"* ]]
}

@test "list-contexts --format=json outputs JSON" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"

  run mta list-contexts --format=json
  assert_success
  [[ "$output" == *"{"* ]]
  [[ "$output" == *"PROJ-1641"* ]]
  [[ "$output" != *"─"* ]]
}

# ==============================================================================
# Chunk Diff
# ==============================================================================

# Helper: create a git repo with a commit, returns the repo dir and commit SHA
# Sets CHUNK_DIFF_REPO and CHUNK_DIFF_SHA variables
setup_git_repo_with_commit() {
  CHUNK_DIFF_REPO="$(mktemp -d)"
  (
    cd "$CHUNK_DIFF_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git config commit.gpgsign false
    echo "original" > file1.sh
    echo "other" > file2.sh
    git add .
    git commit -q -m "initial"
    echo "modified" > file1.sh
    echo "also modified" > file2.sh
    git add .
    git commit -q -m "change both files"
  )
  CHUNK_DIFF_SHA=$(cd "$CHUNK_DIFF_REPO" && git rev-parse HEAD)
}

cleanup_git_repo() {
  [[ -n "${CHUNK_DIFF_REPO:-}" && -d "${CHUNK_DIFF_REPO:-}" ]] && rm -rf "$CHUNK_DIFF_REPO"
}

@test "chunk-diff fails without required args" {
  run mta chunk-diff
  assert_failure

  run mta chunk-diff PROJ-1641
  assert_failure
}

@test "chunk-diff fails when no chunks file exists" {
  run mta chunk-diff PROJ-1641 "nonexistent"
  assert_failure
}

@test "chunk-diff fails for nonexistent chunk" {
  # Write a chunk record directly (no super needed)
  echo '{ticket:"PROJ-1641",commit:"a3f7e2b",summary:"retry logic",risc:8,ts:"2025-01-01T00:00:00Z",reviewed_at:null}' \
    > "$TEST_CONTEXTS_DIR/chunks.sup"
  run mta chunk-diff PROJ-1641 "nonexistent"
  assert_failure
}

@test "chunk-diff shows full commit diff when no files recorded" {
  setup_git_repo_with_commit
  echo "{ticket:\"PROJ-1641\",commit:\"$CHUNK_DIFF_SHA\",summary:\"change both files\",risc:5,ts:\"2025-01-01T00:00:00Z\",reviewed_at:null}" \
    > "$TEST_CONTEXTS_DIR/chunks.sup"

  run bash -c "cd '$CHUNK_DIFF_REPO' && MTA_CONTEXTS_DIR='$MTA_CONTEXTS_DIR' '$MTA_CONTEXT' chunk-diff PROJ-1641 'change both files'"
  assert_success
  [[ "$output" == *"file1.sh"* ]]
  [[ "$output" == *"file2.sh"* ]]
  [[ "$output" == *"modified"* ]]
  cleanup_git_repo
}

@test "chunk-diff scopes to recorded files" {
  setup_git_repo_with_commit
  echo "{ticket:\"PROJ-1641\",commit:\"$CHUNK_DIFF_SHA\",summary:\"file1 only\",risc:3,ts:\"2025-01-01T00:00:00Z\",reviewed_at:null,files:\"file1.sh\"}" \
    > "$TEST_CONTEXTS_DIR/chunks.sup"

  run bash -c "cd '$CHUNK_DIFF_REPO' && MTA_CONTEXTS_DIR='$MTA_CONTEXTS_DIR' '$MTA_CONTEXT' chunk-diff PROJ-1641 'file1 only'"
  assert_success
  [[ "$output" == *"file1.sh"* ]]
  [[ "$output" != *"file2.sh"* ]]
  cleanup_git_repo
}

@test "chunk-diff handles multi-commit chunks" {
  CHUNK_DIFF_REPO="$(mktemp -d)"
  (
    cd "$CHUNK_DIFF_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git config commit.gpgsign false
    echo "v0" > a.sh
    git add . && git commit -q -m "init"
    echo "v1" > a.sh
    git add . && git commit -q -m "first change"
    echo "v2" > a.sh
    git add . && git commit -q -m "second change"
  )
  local sha1 sha2
  sha1=$(cd "$CHUNK_DIFF_REPO" && git rev-parse HEAD~1)
  sha2=$(cd "$CHUNK_DIFF_REPO" && git rev-parse HEAD)
  echo "{ticket:\"PROJ-1641\",commit:\"$sha1,$sha2\",summary:\"two-commit change\",risc:6,ts:\"2025-01-01T00:00:00Z\",reviewed_at:null}" \
    > "$TEST_CONTEXTS_DIR/chunks.sup"

  run bash -c "cd '$CHUNK_DIFF_REPO' && MTA_CONTEXTS_DIR='$MTA_CONTEXTS_DIR' '$MTA_CONTEXT' chunk-diff PROJ-1641 'two-commit change'"
  assert_success
  # Should contain output from both commits
  [[ "$output" == *"first change"* ]]
  [[ "$output" == *"second change"* ]]
  cleanup_git_repo
}

@test "chunk-diff scopes multi-commit chunk to files" {
  CHUNK_DIFF_REPO="$(mktemp -d)"
  (
    cd "$CHUNK_DIFF_REPO"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git config commit.gpgsign false
    echo "v0" > a.sh
    echo "v0" > b.sh
    git add . && git commit -q -m "init"
    echo "v1" > a.sh
    echo "v1" > b.sh
    git add . && git commit -q -m "change both"
  )
  local sha
  sha=$(cd "$CHUNK_DIFF_REPO" && git rev-parse HEAD)
  echo "{ticket:\"PROJ-1641\",commit:\"$sha\",summary:\"only a\",risc:3,ts:\"2025-01-01T00:00:00Z\",reviewed_at:null,files:\"a.sh\"}" \
    > "$TEST_CONTEXTS_DIR/chunks.sup"

  run bash -c "cd '$CHUNK_DIFF_REPO' && MTA_CONTEXTS_DIR='$MTA_CONTEXTS_DIR' '$MTA_CONTEXT' chunk-diff PROJ-1641 'only a'"
  assert_success
  [[ "$output" == *"a.sh"* ]]
  [[ "$output" != *"b.sh"* ]]
  cleanup_git_repo
}

@test "list-tasks --format=json outputs JSON" {
  require_super
  mta create-context PROJ-1641 "Upgrade auth service"
  mta add-task PROJ-1641 "Write tests"

  run mta list-tasks PROJ-1641 --format=json
  assert_success
  [[ "$output" == *"{"* ]]
  [[ "$output" == *"Write tests"* ]]
  [[ "$output" != *"─"* ]]
}

# ==============================================================================
# Journal
# ==============================================================================

@test "journal adds entry to journal.sup" {
  run mta journal "Incident response consumed the day"
  assert_success
  assert_file_exists "journal.sup"
  assert_file_contains "journal.sup" "Incident response consumed the day"
}

@test "journal entry has ts and text fields" {
  run mta journal "Planning meeting notes"
  assert_success
  assert_file_contains "journal.sup" 'ts:"20'
  assert_file_contains "journal.sup" 'text:"Planning meeting notes"'
}

@test "journal escapes special characters in text" {
  run mta journal 'He said "hello" and used a \backslash'
  assert_success
  # Should not break the sup file - entry should be queryable
  assert_file_exists "journal.sup"
  # The escaped text should be in the file
  assert_file_contains "journal.sup" 'text:"He said'
}

@test "journal --list shows entries in reverse chronological order" {
  require_super
  # Write entries with known timestamps
  echo '{ts:"2026-03-19T10:00:00Z",text:"First entry"}' > "$TEST_CONTEXTS_DIR/journal.sup"
  echo '{ts:"2026-03-19T11:00:00Z",text:"Second entry"}' >> "$TEST_CONTEXTS_DIR/journal.sup"
  echo '{ts:"2026-03-19T12:00:00Z",text:"Third entry"}' >> "$TEST_CONTEXTS_DIR/journal.sup"

  run mta journal --list --format=json
  assert_success
  # In JSON output, Third should appear before First
  local third_pos first_pos
  third_pos=$(echo "$output" | grep -n "Third" | head -1 | cut -d: -f1)
  first_pos=$(echo "$output" | grep -n "First" | head -1 | cut -d: -f1)
  [[ "$third_pos" -lt "$first_pos" ]]
}

@test "journal --list N limits to N entries" {
  require_super
  echo '{ts:"2026-03-19T10:00:00Z",text:"Entry one"}' > "$TEST_CONTEXTS_DIR/journal.sup"
  echo '{ts:"2026-03-19T11:00:00Z",text:"Entry two"}' >> "$TEST_CONTEXTS_DIR/journal.sup"
  echo '{ts:"2026-03-19T12:00:00Z",text:"Entry three"}' >> "$TEST_CONTEXTS_DIR/journal.sup"

  run mta journal --list 2 --format=json
  assert_success
  [[ "$output" == *"Entry three"* ]]
  [[ "$output" == *"Entry two"* ]]
  [[ "$output" != *"Entry one"* ]]
}

@test "journal --list defaults to 10" {
  require_super
  # Create 12 entries
  for i in $(seq -w 1 12); do
    echo "{ts:\"2026-03-19T${i}:00:00Z\",text:\"Entry $i\"}" >> "$TEST_CONTEXTS_DIR/journal.sup"
  done

  run mta journal --list --format=json
  assert_success
  # Should have entries 03-12, not 01-02
  [[ "$output" == *"Entry 12"* ]]
  [[ "$output" == *"Entry 03"* ]]
  [[ "$output" != *"Entry 01"* ]]
  [[ "$output" != *"Entry 02"* ]]
}

@test "journal --today shows only today entries" {
  require_super
  local today
  today=$(date -u +"%Y-%m-%d")
  echo "{ts:\"${today}T10:00:00Z\",text:\"Today entry\"}" > "$TEST_CONTEXTS_DIR/journal.sup"
  echo '{ts:"2025-01-01T10:00:00Z",text:"Old entry"}' >> "$TEST_CONTEXTS_DIR/journal.sup"

  run mta journal --today --format=json
  assert_success
  [[ "$output" == *"Today entry"* ]]
  [[ "$output" != *"Old entry"* ]]
}

@test "journal --today shows nothing when no entries today" {
  require_super
  echo '{ts:"2025-01-01T10:00:00Z",text:"Old entry"}' > "$TEST_CONTEXTS_DIR/journal.sup"

  run mta journal --today --format=json
  assert_success
  [[ "$output" != *"Old entry"* ]]
}

@test "journal with no args and no entries shows empty message" {
  run mta journal
  assert_success
  [[ "$output" == *"No journal entries"* ]]
}

@test "journal with no args shows last 10 entries" {
  require_super
  for i in $(seq -w 1 12); do
    echo "{ts:\"2026-03-19T${i}:00:00Z\",text:\"Entry $i\"}" >> "$TEST_CONTEXTS_DIR/journal.sup"
  done

  run mta journal --format=json
  assert_success
  [[ "$output" == *"Entry 12"* ]]
  [[ "$output" == *"Entry 03"* ]]
  [[ "$output" != *"Entry 01"* ]]
}

# ==============================================================================
# Priority
# ==============================================================================

@test "set-priority sets priority on existing context" {
  require_super
  mta create-context PROJ-100 "Auth upgrade"

  run mta set-priority PROJ-100 "high"
  assert_success
  assert_file_contains "contexts.sup" 'priority:"high"'
}

@test "set-priority errors on non-existent ticket" {
  run mta set-priority NOPE-999 "high"
  assert_failure
  [[ "$output" == *"not found"* ]]
}

@test "set-priority errors on archived ticket" {
  require_super
  mta create-context PROJ-100 "Auth upgrade"
  mta archive PROJ-100

  run mta set-priority PROJ-100 "high"
  assert_failure
  [[ "$output" == *"archived"* ]]
}

@test "set-priority --clear removes priority" {
  require_super
  mta create-context PROJ-100 "Auth upgrade"
  mta set-priority PROJ-100 "high"
  assert_file_contains "contexts.sup" 'priority:"high"'

  run mta set-priority PROJ-100 --clear
  assert_success
  assert_file_not_contains "contexts.sup" 'priority:"high"'
}

@test "set-priority overwrites existing priority" {
  require_super
  mta create-context PROJ-100 "Auth upgrade"
  mta set-priority PROJ-100 "low"
  assert_file_contains "contexts.sup" 'priority:"low"'

  run mta set-priority PROJ-100 "critical"
  assert_success
  assert_file_contains "contexts.sup" 'priority:"critical"'
  assert_file_not_contains "contexts.sup" 'priority:"low"'
}

@test "list-contexts shows priority field" {
  require_super
  mta create-context PROJ-100 "Auth upgrade"
  mta set-priority PROJ-100 "high"

  run mta list-contexts --format=json
  assert_success
  [[ "$output" == *"priority"* ]]
  [[ "$output" == *"high"* ]]
}

@test "set-priority with free-form text works" {
  require_super
  mta create-context PROJ-100 "Auth upgrade"

  run mta set-priority PROJ-100 "urgent - stakeholder deadline Friday"
  assert_success
  assert_file_contains "contexts.sup" 'priority:"urgent - stakeholder deadline Friday"'
}
