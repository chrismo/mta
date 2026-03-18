---
name: mta:join
description: Join a shared context for coordinated multi-Claude work
allowed-tools: Bash
---

# Join Shared Context

Register this Claude session as part of a coordinated effort on a ticket.

## Usage

```
/mta:join [ticket]
```

## What This Does

1. **Detect ticket** (if not provided):
   - Get current branch: `git branch --show-current`
   - Extract ticket pattern from branch name (e.g., `proj-101-upgrade-auth...` → `PROJ-1641`)
   - Common patterns: `<project>-<number>-description` where project is letters, number is digits
   - Convert to uppercase for the context
   - If no pattern found, ask user for ticket

2. Check if context exists:
   ```bash
   mta-engine get-context <TICKET>
   ```
   - If not, offer to create it with `mta-engine create-context`

3. Register this session (session ID is auto-detected):
   ```bash
   mta-engine join <TICKET>
   ```

5. Display current status:
   ```bash
   mta-engine status <TICKET>
   ```

6. Store the ticket reference for this session so `/mta:read` and `/mta:update` know where to read/write

## Output

```
Joined <ticket> shared context as ds5/92e7df7e.

## Recent Decisions
- <decision 1>
- <decision 2>

## Active Sessions
- ds5/92e7df7e (this session)
- ds5/a1b2c3d4
- ds8/x9y8z7w6

Ready. Use /mta:update to record work, /mta:leave when done.
```

## If Context Doesn't Exist

Offer to create it:

```
No shared context for <ticket>. Create it?

This will initialize the context in ~/.claude/contexts/
```

If user confirms:
```bash
mta-engine create-context <TICKET> "<title>" [--ticket-url=...] [--branch=...] [--worktree=...]
```
