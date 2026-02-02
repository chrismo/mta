#!/usr/bin/env bash
# test_helper.bash - Common setup/teardown for mta-context tests

# Path to the script under test
export MTA_CONTEXT="${BATS_TEST_DIRNAME}/../bin/mta-context.sh"

# Temporary test directory - isolated per test run
export TEST_CONTEXTS_DIR=""

# Check if super CLI is available
export SUPER_AVAILABLE=""
if command -v super &>/dev/null; then
  SUPER_AVAILABLE="true"
fi

# Setup: create isolated temp directory for each test
setup() {
  TEST_CONTEXTS_DIR="$(mktemp -d)"
  export MTA_CONTEXTS_DIR="$TEST_CONTEXTS_DIR"

  # Ensure the script exists and is executable
  if [[ ! -x "$MTA_CONTEXT" ]]; then
    skip "mta-context.sh not found or not executable"
  fi
}

# Helper: skip test if super is not available
require_super() {
  if [[ -z "$SUPER_AVAILABLE" ]]; then
    skip "super CLI not installed"
  fi
}

# Teardown: clean up temp directory
teardown() {
  if [[ -n "$TEST_CONTEXTS_DIR" && -d "$TEST_CONTEXTS_DIR" ]]; then
    rm -rf "$TEST_CONTEXTS_DIR"
  fi
}

# Helper: run mta-context.sh with test environment
mta() {
  "$MTA_CONTEXT" "$@"
}

# Helper: query a .sup file with super
sup_query() {
  local file="$1"
  shift
  super -c "$*" "$TEST_CONTEXTS_DIR/$file"
}

# Helper: count records in a .sup file matching a condition
sup_count() {
  local file="$1"
  local where_clause="$2"

  if [[ -n "$where_clause" ]]; then
    super -c "from '$TEST_CONTEXTS_DIR/$file' | where $where_clause | count()" 2>/dev/null || echo "0"
  else
    super -c "from '$TEST_CONTEXTS_DIR/$file' | count()" 2>/dev/null || echo "0"
  fi
}

# Helper: assert file exists
assert_file_exists() {
  local file="$1"
  [[ -f "$TEST_CONTEXTS_DIR/$file" ]] || {
    echo "Expected file to exist: $file"
    return 1
  }
}

# Helper: assert file contains pattern
assert_file_contains() {
  local file="$1"
  local pattern="$2"
  grep -q "$pattern" "$TEST_CONTEXTS_DIR/$file" || {
    echo "Expected $file to contain: $pattern"
    echo "Actual contents:"
    cat "$TEST_CONTEXTS_DIR/$file"
    return 1
  }
}

# Helper: get current ISO timestamp (for comparisons)
now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}
