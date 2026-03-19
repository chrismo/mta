#!/usr/bin/env bats
# mta.bats - Tests for the mta launcher
#
# Run with: bats test/mta.bats

MTA_BIN="${BATS_TEST_DIRNAME}/../bin/mta"
MTA_ENGINE="${BATS_TEST_DIRNAME}/../bin/mta-engine"

setup() {
  TEST_CONTEXTS_DIR="$(mktemp -d)"
  export MTA_CONTEXTS_DIR="$TEST_CONTEXTS_DIR"
  export MTA_DRY_RUN=1

  if [[ ! -x "$MTA_BIN" ]]; then
    skip "bin/mta not found or not executable"
  fi
}

teardown() {
  if [[ -n "$TEST_CONTEXTS_DIR" && -d "$TEST_CONTEXTS_DIR" ]]; then
    rm -rf "$TEST_CONTEXTS_DIR"
  fi
}

@test "mta <ticket> with no existing context creates it and launches" {
  run "$MTA_BIN" PROJ-123
  [[ "$status" -eq 0 ]]
  # Should have created the context
  [[ -f "$TEST_CONTEXTS_DIR/contexts.sup" ]]
  # Dry run output should show the claude launch command
  [[ "$output" == *'claude /mta:join PROJ-123'* ]]
}

@test "mta <ticket> with existing context skips creation and launches" {
  # Pre-create the context
  "$MTA_ENGINE" create-context PROJ-456 "Existing ticket"
  run "$MTA_BIN" PROJ-456
  [[ "$status" -eq 0 ]]
  [[ "$output" == *'claude /mta:join PROJ-456'* ]]
  # Should NOT contain "Created context" since it already existed
  [[ "$output" != *"Created context"* ]]
}

@test "mta <ticket> <wd> launches with claude-slot" {
  run "$MTA_BIN" PROJ-789 /tmp/myproject
  [[ "$status" -eq 0 ]]
  [[ "$output" == *'claude-slot /tmp/myproject /mta:join PROJ-789'* ]]
}

@test "mta interactive picks context via grdy+fzf" {
  if ! command -v grdy &>/dev/null || ! command -v fzf &>/dev/null; then
    skip "grdy or fzf not installed"
  fi

  "$MTA_ENGINE" create-context PROJ-100 "First ticket"
  "$MTA_ENGINE" create-context PROJ-200 "Second ticket"

  # Use fzf --filter for non-interactive selection (matches "First")
  export MTA_FZF_CMD="fzf --filter=First"
  run "$MTA_BIN"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *'claude /mta:join PROJ-100'* ]]
}

@test "mta with no contexts shows error" {
  # No fzf interaction possible in test, but with no contexts it should error
  run "$MTA_BIN"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"No contexts found"* ]]
}

@test "mta with too many args shows usage" {
  run "$MTA_BIN" a b c
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Usage"* ]]
}

@test "mta help shows mta-engine help" {
  run "$MTA_BIN" help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"mta-engine"* ]]
  [[ "$output" == *"command"* ]]
  # Should NOT create a context called "help"
  [[ ! -f "$TEST_CONTEXTS_DIR/contexts.sup" ]] || ! grep -q 'ticket:"help"' "$TEST_CONTEXTS_DIR/contexts.sup"
}

@test "mta --help shows mta-engine help" {
  run "$MTA_BIN" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"mta-engine"* ]]
}

@test "mta -h shows mta-engine help" {
  run "$MTA_BIN" -h
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"mta-engine"* ]]
}
