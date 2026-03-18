# MTA Context Tests

Tests for `mta-engine` using [bats-core](https://github.com/bats-core/bats-core).

## Prerequisites

### Install bats-core

```bash
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt install bats

# From source (any system)
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Install SuperDB

The script requires the `super` CLI. See: https://github.com/brimdata/super

```bash
# macOS
brew install brimdata/tap/super

# Linux (download binary)
curl -L https://github.com/brimdata/super/releases/latest/download/super-linux-amd64.tar.gz | tar xz
sudo mv super /usr/local/bin/
```

## Running Tests

```bash
# From the test directory
cd ai-agents/claude/test
bats mta-engine.bats

# Or with verbose output
bats --verbose-run mta-engine.bats

# Run specific test
bats --filter "create-context" mta-engine.bats

# TAP output (for CI)
bats --tap mta-engine.bats
```

## Test Structure

- `test_helper.bash` - Setup/teardown, common helpers
- `mta-engine.bats` - Main test file

Each test runs in an isolated temp directory (`$TEST_CONTEXTS_DIR`), cleaned up automatically.

## Writing New Tests

```bash
@test "descriptive test name" {
  # Setup: use mta helper (wraps mta-engine)
  mta create-context TICKET-123 "Title"

  # Act: run command under test
  run mta join TICKET-123 session/abc

  # Assert: check results
  assert_success
  assert_file_contains "sessions.sup" "session/abc"
}
```

### Available Helpers

| Helper | Description |
|--------|-------------|
| `mta <cmd> [args]` | Run mta-engine with test env |
| `sup_query <file> <query>` | Query a .sup file |
| `sup_count <file> [where]` | Count records |
| `assert_success` | Exit code was 0 |
| `assert_failure` | Exit code was non-zero |
| `assert_file_exists <file>` | File exists in test dir |
| `assert_file_contains <file> <pattern>` | File contains pattern |
