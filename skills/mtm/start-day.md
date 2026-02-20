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

1. Run `work-context data 7` to get worktree/conversation data

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

7. **Review open PRs** from `work-context data` output:
   - Match PRs to active contexts/worktrees by branch name
   - Flag PRs needing attention: approved but not merged, changes requested, stale (no updates in 7+ days)
   - Note any PRs not tied to an active context (forgotten work)

8. Output a unified status showing:
   - Active coordinated efforts (tickets with contexts)
   - Worktrees and their coordination status
   - Blockers or dependencies between efforts
   - Open PR status

## Output Format

```
## Multitasking Status

### Active Coordinations
- **PROJ-1641**: 3 sessions (ds5/92e7df7e, ds5/a1b2c3d4, ds8/x9y8z7w6) | 5 decisions | no blockers
- **INCIDENT-outage**: 1 session (ds4/f3e2d1c0) | 1 decision | blocking PROJ-1641

### Open PRs
**Needs action:**
- #12345 "Fix auth flow" — APPROVED, ready to merge
- #12350 "Add caching" — CHANGES REQUESTED (3d ago)

**In flight:**
- #12360 "New feature" — REVIEW REQUIRED (draft)

**Stale (7+ days no update):**
- #11200 "Old experiment" — no activity since Jan 15

### Uncoordinated Worktrees
- ds9: proj-202-experiment-with-ci-pipeline (no shared context)

### Recent Activity
- ds5: 2 active sessions
- ds8: 1 active session
```

## Notes

This is the heavy morning overview. For quick mid-day checks, use `/mtm:update` instead.

Keep output concise. Manager needs the big picture, not details.
If no contexts exist, note that and suggest `/mtm:new-context <ticket>` to start coordinating.
