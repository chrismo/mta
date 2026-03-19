---
name: mta:read
description: Read shared context to see what other Claude sessions have done
allowed-tools: Bash
---

# Read Shared Context

See what other Claude sessions have done on a coordinated ticket.

## Usage

```
/mta:read [ticket]
```

If ticket is omitted:
1. Use ticket from earlier `/mta:join` in this session
2. Or try to detect from branch name (same logic as join)
3. Or list all contexts: `mta-engine list-contexts`

## What This Does

1. Display context status:
   ```bash
   mta-engine status <TICKET>
   ```

2. Check cognitive debt:
   ```bash
   mta-engine debt <TICKET>
   ```

3. Check git status on relevant files:
   ```bash
   git log --oneline -5 -- <relevant-paths>
   ```

4. Summarize what you need to know before continuing work

## Output Format

```
## <ticket> - Current State

### Context
- Title: <title>
- Branch: <branch>
- Worktree: <worktree>
- Priority: <priority> (or: none)

### Active Sessions
- ds5/92e7df7e
- ds8/x9y8z7w6

### Recent Decisions
- 2026-01-27 11:00: <decision>
- 2026-01-27 10:30: <decision>

### Pending Tasks
- <task 1>
- <task 2>

### Blockers
- None (or list any unresolved)

### Cognitive Debt
- 3 unreviewed | weighted: 15 | 2 high-RISC

### Recent Commits
- abc1234 asg-scaler: add queue metrics support
- def5678 asg-scaler: fix ceiling calc with bc

Ready to work.
```

## No Context Found

If no context file exists for the ticket:

```
No shared context for <ticket>.
Run /mta:join <ticket> to set up coordination, or work independently.
```

## Additional Queries

For more specific queries:

```bash
# Just decisions
mta-engine list-decisions <TICKET>

# Just tasks
mta-engine list-tasks <TICKET> --pending

# Just blockers
mta-engine list-blockers --unresolved

# Active sessions
mta-engine list-sessions <TICKET>

# Cognitive debt
mta-engine debt <TICKET>

# Unreviewed chunks
mta-engine list-chunks <TICKET> --unreviewed
```
