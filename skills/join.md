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
   - Extract ticket pattern from branch name (e.g., `devops-1641-replace-custom...` → `DEVOPS-1641`)
   - Common patterns: `<project>-<number>-description` where project is letters, number is digits
   - Convert to uppercase for the context
   - If no pattern found, ask user for ticket

2. Check if context exists:
   ```bash
   mta-context.sh get-context <TICKET>
   ```
   - If not, offer to create it with `mta-context.sh create-context`

3. Extract your session identifier:
   - Your scratchpad path contains your session UUID (e.g., `/private/tmp/claude/.../92e7df7e-aa72-45e9-8817-08e921750403/scratchpad`)
   - Extract the UUID from your scratchpad path in the system prompt
   - Use the first 8 characters as a short identifier
   - Worktree name: `git rev-parse --show-toplevel | xargs basename`
   - Combined identifier: `<worktree>/<short-uuid>` (e.g., `ds5/92e7df7e`)

4. Register this session:
   ```bash
   mta-context.sh join <TICKET> <worktree>/<short-uuid>
   ```

5. Display current status:
   ```bash
   mta-context.sh status <TICKET>
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
mta-context.sh create-context <TICKET> "<title>" [--linear-url=...] [--branch=...] [--worktree=...]
```
