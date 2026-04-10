# claude-tabs: Save and Restore Ghostty Claude Sessions

## Problem

When running many Claude Code sessions across Ghostty tabs (10+), tabs accumulate over days. There's no way to snapshot the current state — which worktrees have sessions, which session UUIDs — so you can kill Ghostty and reopen everything cleanly.

## Design: Process-Based Detection

No registration, no state files maintained at runtime, no hooks. Ask the system "what's running right now?" via `lsof`.

**Why not mtime heuristics?** Tabs left open overnight (or longer) make mtime useless — a 2-day idle session and a 2-day closed session look identical on disk.

**Why not explicit registration?** It works, but requires maintaining state in sync with reality. Process detection IS reality.

## Detection Algorithm

```
lsof -c node -a -d cwd -Fn 2>/dev/null
```

This returns the cwd of every running `node` process. Claude Code runs as node, so each Claude session appears here. Multiple node processes per session (parent + children) share the same cwd, so dedup by unique path.

**Cross-reference with Claude projects to filter non-Claude node processes:**

1. For each unique cwd, encode the path: `/Users/chris/dev/ds5` → `-Users-chris-dev-ds5`
2. Check if `~/.claude/projects/<encoded>/` exists
3. If yes → it's a Claude session. Find the most recently modified `.jsonl` in that directory → filename (minus `.jsonl`) is the session UUID.
4. If no → skip (it's a non-Claude node process)

### Verified Assumptions (2026-04-09)

- `lsof -c node -a -d cwd` shows cwds for all Claude sessions (confirmed with 12 active worktrees)
- Claude does NOT keep `.jsonl` files open (confirmed: `lsof -c node | grep .jsonl` returns nothing), so we can't detect sessions via open file handles
- Project directory encoding: path with `/` replaced by `-` (e.g., `-Users-chrismo-dev-ds5`)
- Session UUID = JSONL filename without extension
- `claude --resume <session-id>` resumes a session by UUID

## Components

### 1. `bin/claude-tabs` — New Script

Subcommands: `save`, `restore`, `list`

#### `claude-tabs save`

1. Run `lsof -c node -a -d cwd -Fn` → extract unique cwds (lines starting with `n`, strip prefix)
2. For each cwd, encode path → check `~/.claude/projects/<encoded>/` exists
3. Find most recent `.jsonl` → extract session UUID
4. Write manifest to `~/.claude/tab-state.json`

**Manifest format:**
```json
[
  {"name": "ds5", "path": "/Users/chrismo/dev/ds5", "session_id": "abc-123-def"},
  {"name": "mta", "path": "/Users/chrismo/dev/mta", "session_id": "ghi-456-jkl"}
]
```

#### `claude-tabs restore [manifest]`

1. Read manifest (default: `~/.claude/tab-state.json`)
2. For each entry: `claude-slot <path> --resume <session_id>`
3. Delay between launches (Ghostty needs time to open each tab — the AppleScript paste-based approach is sequential)

#### `claude-tabs list`

Dry-run of save: detect and display active sessions without writing a manifest. Useful for verifying detection before saving.

### 2. `bin/claude-slot` — Modification

Add `--resume <session-id>` flag support.

**Current:** `claude-slot <worktree> [prompt]`
**New:** `claude-slot <worktree> [--resume <session-id>] [prompt]`

Parsing change (after worktree shift):
```bash
resume_id=""
if [[ "${1:-}" == "--resume" ]]; then
    resume_id="${2:-}"
    shift 2 || true
fi
prompt="${*:-}"
```

Command construction:
```bash
if [[ -n "$resume_id" ]]; then
    claude_cmd="claude --resume $resume_id"
elif [[ -n "$prompt" ]]; then
    claude_cmd="claude \"$prompt\""
else
    claude_cmd="claude"
fi
```

### 3. `install.sh` — Update

Add `claude-tabs` to the symlink loop (line 47):
```bash
for bin_file in mta mta-engine claude-slot claude-tabs; do
```

## Edge Cases

**Non-Claude node processes** — Filtered by checking for matching `~/.claude/projects/<encoded>/` directory. A node dev server running in `~/dev/ds5` will share the cwd but the cross-reference handles it (the session UUID comes from the JSONL, not the node process).

**Multiple sessions in same worktree** — Possible if someone opens two Claude sessions in the same directory. `lsof` deduplicates cwds, so we'd only save one (the most recent JSONL). This seems acceptable — restoring one is better than zero.

**Worktrees with spaces in path** — The `lsof -Fn` output handles this (one `n`-prefixed line per path). The `work-rig` Google Drive path in the real data confirms this is a real scenario.

**Session UUID no longer valid** — `claude --resume` with a stale UUID should either fail gracefully or start a new session. Test this.

**Restore when Ghostty already has tabs** — `claude-slot` opens a new tab each time. Restoring adds tabs; it doesn't replace existing ones. User should close/kill Ghostty first if they want a clean slate.

## Testing Strategy

**Testable without system access:**
- `encode_project_path` function (path → project dir name)
- Manifest write/read round-trip
- `claude-slot` `--resume` flag parsing (command string construction)
- Filtering logic: given mock lsof output + mock projects dir, correct sessions detected

**Approach:** Factor detection into functions that accept input (mock lsof output, mock projects dir) rather than calling lsof directly. Test file: `test/claude-tabs.bats`.

**Mock structure:**
```bash
setup() {
    TEST_DIR="$(mktemp -d)"
    # Create mock projects dirs with JSONL files
    mkdir -p "$TEST_DIR/projects/-Users-chrismo-dev-ds5"
    touch "$TEST_DIR/projects/-Users-chrismo-dev-ds5/abc-123.jsonl"
    # Create mock lsof output file
    printf 'p925\nn/Users/chrismo/dev/ds5\np3616\nn/Users/chrismo/dev/not-a-claude-project\n' \
        > "$TEST_DIR/mock-lsof.txt"
}
```

**Manual testing:** Run `claude-tabs list` and compare against visible Ghostty tabs. Save, kill Ghostty, restore, verify all sessions came back.
