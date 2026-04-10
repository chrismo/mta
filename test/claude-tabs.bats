#!/usr/bin/env bats
# claude-tabs.bats - Tests for claude-tabs save/restore
#
# Run with: bats test/claude-tabs.bats

CLAUDE_TABS="${BATS_TEST_DIRNAME}/../bin/claude-tabs"
CLAUDE_SLOT="${BATS_TEST_DIRNAME}/../bin/claude-slot"

setup() {
  TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-tabs-test.XXXXXX")"
  export CLAUDE_TABS_PROJECTS_DIR="$TEST_DIR/projects"
  export CLAUDE_TABS_MANIFEST="$TEST_DIR/tab-state.json"

  mkdir -p "$CLAUDE_TABS_PROJECTS_DIR"
}

teardown() {
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# encode_project_path
# ─────────────────────────────────────────────────────────────────────────────

@test "encode_project_path replaces slashes with dashes" {
  source "$CLAUDE_TABS"
  run encode_project_path "/Users/chrismo/dev/ds5"
  [[ "$output" == "-Users-chrismo-dev-ds5" ]]
}

@test "encode_project_path handles trailing slash" {
  source "$CLAUDE_TABS"
  run encode_project_path "/Users/chrismo/dev/ds5/"
  [[ "$output" == "-Users-chrismo-dev-ds5" ]]
}

@test "encode_project_path handles path with spaces" {
  source "$CLAUDE_TABS"
  run encode_project_path "/Users/chrismo/Google Drive/work-rig/dev/ds5"
  [[ "$output" == "-Users-chrismo-Google Drive-work-rig-dev-ds5" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# detect_sessions (from mock lsof output)
# ─────────────────────────────────────────────────────────────────────────────

@test "detect_sessions finds Claude session from lsof output" {
  source "$CLAUDE_TABS"

  # Create mock projects dir with JSONL
  mkdir -p "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5"
  touch "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5/abc-123-def.jsonl"

  # Mock lsof output: pid line then cwd line
  lsof_output="$(printf 'p925\nn/Users/chrismo/dev/ds5\np3616\nn/Users/chrismo/dev/not-a-claude-project\n')"

  run detect_sessions "$lsof_output"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *'"path": "/Users/chrismo/dev/ds5"'* ]]
  [[ "$output" == *'"session_id": "abc-123-def"'* ]]
  [[ "$output" == *'"name": "ds5"'* ]]
}

@test "detect_sessions skips non-Claude node processes" {
  source "$CLAUDE_TABS"

  # No projects dir for this path
  lsof_output="$(printf 'p3616\nn/Users/chrismo/dev/not-a-claude-project\n')"

  run detect_sessions "$lsof_output"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "[]" ]]
}

@test "detect_sessions deduplicates cwds" {
  source "$CLAUDE_TABS"

  mkdir -p "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5"
  touch "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5/abc-123.jsonl"

  # Same cwd from two different PIDs
  lsof_output="$(printf 'p925\nn/Users/chrismo/dev/ds5\np926\nn/Users/chrismo/dev/ds5\n')"

  run detect_sessions "$lsof_output"
  [[ "$status" -eq 0 ]]
  # Should only appear once — count occurrences of "ds5" path entries
  local count
  count=$(echo "$output" | grep -c '"path": "/Users/chrismo/dev/ds5"')
  [[ "$count" -eq 1 ]]
}

@test "detect_sessions picks most recent JSONL as session ID" {
  source "$CLAUDE_TABS"

  mkdir -p "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5"
  # Create two JSONLs with different mtimes
  touch -t 202601010000 "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5/old-session.jsonl"
  sleep 0.1
  touch "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5/new-session.jsonl"

  lsof_output="$(printf 'p925\nn/Users/chrismo/dev/ds5\n')"

  run detect_sessions "$lsof_output"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *'"session_id": "new-session"'* ]]
}

@test "detect_sessions handles multiple Claude sessions" {
  source "$CLAUDE_TABS"

  mkdir -p "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5"
  touch "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5/abc-123.jsonl"
  mkdir -p "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-mta"
  touch "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-mta/def-456.jsonl"

  lsof_output="$(printf 'p925\nn/Users/chrismo/dev/ds5\np3616\nn/Users/chrismo/dev/mta\n')"

  run detect_sessions "$lsof_output"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *'"name": "ds5"'* ]]
  [[ "$output" == *'"name": "mta"'* ]]
  [[ "$output" == *'"session_id": "abc-123"'* ]]
  [[ "$output" == *'"session_id": "def-456"'* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Manifest write/read round-trip (save + list)
# ─────────────────────────────────────────────────────────────────────────────

@test "save writes manifest and list reads it back" {
  source "$CLAUDE_TABS"

  mkdir -p "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5"
  touch "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5/abc-123.jsonl"

  mock_lsof="$(printf 'p925\nn/Users/chrismo/dev/ds5\n')"
  export CLAUDE_TABS_LSOF_OUTPUT="$mock_lsof"

  # Save
  run cmd_save
  [[ "$status" -eq 0 ]]
  [[ -f "$CLAUDE_TABS_MANIFEST" ]]

  # Verify manifest content
  run cat "$CLAUDE_TABS_MANIFEST"
  [[ "$output" == *'"path": "/Users/chrismo/dev/ds5"'* ]]
  [[ "$output" == *'"session_id": "abc-123"'* ]]
}

@test "save reports count of sessions saved" {
  source "$CLAUDE_TABS"

  mkdir -p "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5"
  touch "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5/abc-123.jsonl"
  mkdir -p "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-mta"
  touch "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-mta/def-456.jsonl"

  mock_lsof="$(printf 'p925\nn/Users/chrismo/dev/ds5\np3616\nn/Users/chrismo/dev/mta\n')"
  export CLAUDE_TABS_LSOF_OUTPUT="$mock_lsof"

  run cmd_save
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Saved 2 sessions"* ]]
}

@test "list shows sessions without writing manifest" {
  source "$CLAUDE_TABS"

  mkdir -p "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5"
  touch "$CLAUDE_TABS_PROJECTS_DIR/-Users-chrismo-dev-ds5/abc-123.jsonl"

  mock_lsof="$(printf 'p925\nn/Users/chrismo/dev/ds5\n')"
  export CLAUDE_TABS_LSOF_OUTPUT="$mock_lsof"

  run cmd_list
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ds5"* ]]
  # Manifest should NOT be written
  [[ ! -f "$CLAUDE_TABS_MANIFEST" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# restore
# ─────────────────────────────────────────────────────────────────────────────

@test "restore generates claude-slot commands from manifest" {
  source "$CLAUDE_TABS"

  # Write a manifest directly
  cat > "$CLAUDE_TABS_MANIFEST" <<'MANIFEST'
[
  {"name": "ds5", "path": "/Users/chrismo/dev/ds5", "session_id": "abc-123"},
  {"name": "mta", "path": "/Users/chrismo/dev/mta", "session_id": "def-456"}
]
MANIFEST

  export CLAUDE_TABS_DRY_RUN=1
  run cmd_restore
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"claude-slot /Users/chrismo/dev/ds5 --resume abc-123"* ]]
  [[ "$output" == *"claude-slot /Users/chrismo/dev/mta --resume def-456"* ]]
}

@test "restore fails gracefully with missing manifest" {
  source "$CLAUDE_TABS"

  export CLAUDE_TABS_MANIFEST="$TEST_DIR/nonexistent.json"
  run cmd_restore
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"not found"* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# claude-slot --resume flag parsing
# ─────────────────────────────────────────────────────────────────────────────

@test "claude-slot builds resume command" {
  # claude-slot writes cmd to /tmp/claude-slot/cmd.txt before AppleScript
  # We can test that by checking the file content (but AppleScript will fail in CI).
  # Instead, test the command construction logic sourced from claude-slot.
  # Since claude-slot calls osascript, we need to mock it or just check the cmd file.

  # For now, test that --resume flag is parsed correctly by running with
  # a mock osascript that just exits
  export PATH="$TEST_DIR/bin:$PATH"
  mkdir -p "$TEST_DIR/bin"
  printf '#!/bin/bash\nexit 0\n' > "$TEST_DIR/bin/osascript"
  chmod +x "$TEST_DIR/bin/osascript"

  # Need a valid worktree path
  mkdir -p "$TEST_DIR/worktree"
  run "$CLAUDE_SLOT" "$TEST_DIR/worktree" --resume abc-123-def
  [[ "$status" -eq 0 ]]

  # Check the command that was written
  cmd=$(cat /tmp/claude-slot/cmd.txt)
  [[ "$cmd" == *"claude --resume abc-123-def"* ]]
}

@test "claude-slot resume flag does not include prompt" {
  export PATH="$TEST_DIR/bin:$PATH"
  mkdir -p "$TEST_DIR/bin"
  printf '#!/bin/bash\nexit 0\n' > "$TEST_DIR/bin/osascript"
  chmod +x "$TEST_DIR/bin/osascript"

  mkdir -p "$TEST_DIR/worktree"
  run "$CLAUDE_SLOT" "$TEST_DIR/worktree" --resume abc-123
  [[ "$status" -eq 0 ]]

  cmd=$(cat /tmp/claude-slot/cmd.txt)
  # Should have --resume, should NOT have a prompt after it
  [[ "$cmd" == *"claude --resume abc-123"* ]]
  [[ "$cmd" != *"claude --resume abc-123 \""* ]]
}

@test "claude-slot without --resume still works with prompt" {
  export PATH="$TEST_DIR/bin:$PATH"
  mkdir -p "$TEST_DIR/bin"
  printf '#!/bin/bash\nexit 0\n' > "$TEST_DIR/bin/osascript"
  chmod +x "$TEST_DIR/bin/osascript"

  mkdir -p "$TEST_DIR/worktree"
  run "$CLAUDE_SLOT" "$TEST_DIR/worktree" /mta:join PROJ-123
  [[ "$status" -eq 0 ]]

  cmd=$(cat /tmp/claude-slot/cmd.txt)
  [[ "$cmd" == *'claude "/mta:join PROJ-123"'* ]]
}

@test "claude-slot without --resume and no prompt starts plain claude" {
  export PATH="$TEST_DIR/bin:$PATH"
  mkdir -p "$TEST_DIR/bin"
  printf '#!/bin/bash\nexit 0\n' > "$TEST_DIR/bin/osascript"
  chmod +x "$TEST_DIR/bin/osascript"

  mkdir -p "$TEST_DIR/worktree"
  run "$CLAUDE_SLOT" "$TEST_DIR/worktree"
  [[ "$status" -eq 0 ]]

  cmd=$(cat /tmp/claude-slot/cmd.txt)
  # Should end with just "claude" (no quotes, no prompt)
  [[ "$cmd" == *"&& claude" ]]
}
