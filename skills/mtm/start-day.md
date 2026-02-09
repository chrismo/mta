---
name: mtm:start-day
description: Morning overview of all coordinated multi-Claude work
allowed-tools: Bash
---

# Multitasking Manager - Start Day

Full overview of all coordinated work - use this to plan your day.

## Usage

```
/mtm:start-day
```

## What This Does

1. Run `yah data 7` to get worktree/conversation data

2. List all active contexts:
   ```bash
   mta-context.sh list-contexts
   ```

3. Get full status for each context:
   ```bash
   mta-context.sh status
   ```

4. List all sessions to see which worktrees are linked:
   ```bash
   mta-context.sh list-sessions
   ```

5. Check for unresolved blockers:
   ```bash
   mta-context.sh list-blockers --unresolved
   ```

6. Correlate: which conversations map to which contexts

7. Output a unified status showing:
   - Active coordinated efforts (tickets with contexts)
   - Worktrees and their coordination status
   - Blockers or dependencies between efforts

## Output Format

```
## Multitasking Status

### Active Coordinations
- **DEVOPS-1641**: 3 sessions (ds5/92e7df7e, ds5/a1b2c3d4, ds8/x9y8z7w6) | 5 decisions | no blockers
- **INCIDENT-cloudflare**: 1 session (ds4/f3e2d1c0) | 1 decision | blocking DEVOPS-1641

### Uncoordinated Worktrees
- ds9: devops-1670-experiment-with-multi-workflows (no shared context)

### Recent Activity
- ds5: 2 active sessions
- ds8: 1 active session
```

## Notes

This is the heavy morning overview. For quick mid-day checks, use `/mtm:status` instead.

Keep output concise. Manager needs the big picture, not details.
If no contexts exist, note that and suggest `/mtm:new-context <ticket>` to start coordinating.
