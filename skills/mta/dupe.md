---
name: mta:dupe
description: Output a claude-slot command to spawn a duplicate worker on the same ticket
allowed-tools: Bash
---

# Duplicate Worker

Output a `claude-slot` command to spawn another Claude session on the same worktree and ticket context.

## Usage

```
/mta:dupe
```

## What This Does

1. **Get full worktree path**:
   ```bash
   git rev-parse --show-toplevel
   ```

2. **Get current ticket**: `mta-engine my-context` (auto-detects session, returns active ticket)

3. **Output the command**:
   ```
   claude-slot /full/path/to/worktree "/mta:join TICKET-ID"
   ```

## Output Example

```
Spawn a duplicate worker:

claude-slot /Users/chrismo/dev/ds5 "/mta:join PROJ-1234"
```

## Notes

- Uses full worktree path because `~/dev` location varies across environments
- The new session will join the same shared context file
- Useful for parallelizing work on a single ticket (e.g., one Claude on tests, one on implementation)
- If not currently joined to a context, prompt user to run `/mta:join` first
