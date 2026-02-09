---
name: mta:leave
description: Deregister from a coordinated multi-Claude effort
allowed-tools: Bash
---

# Leave Shared Context

Deregister this Claude session from a coordinated effort.

## Usage

```
/mta:leave [ticket]
```

If ticket is omitted, use the context from `/mta:join` or detect from branch.

## What This Does

1. Prompt for final update if there are decisions to record:
   - If yes, run the `/mta:update` flow first

2. Determine status:
   - **done** - finished your part of the work
   - **paused** - stopping for now, may return
   - **blocked** - can't continue, noted in Blockers section
   - **handoff** - passing to another Claude/person

3. Leave the session with a note:
   ```bash
   mta-context.sh leave <TICKET> <worktree>/<short-uuid> <status> "<brief summary>"
   ```

4. Prompt: Should I commit and push? (if there are uncommitted changes)

## Output Format

```
## Leaving: <ticket>

Session: ds5/92e7df7e

Final update recorded:
- Queue scaling tested in staging-15, ready for prod

Status: done

Left session ds5/92e7df7e.

Uncommitted changes:
- (list or "None")

Commit and push? [y/n]
```

## If Last Session

Check if there are other active sessions:
```bash
mta-context.sh list-sessions <TICKET>
```

If you're the last linked session:

```
You're the last worker on <ticket>.

Options:
1. Leave context for future reference
2. Archive context

Choice? [1/2]
```

If archiving:
```bash
mta-context.sh archive <TICKET>
```
