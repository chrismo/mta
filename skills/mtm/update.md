---
name: mtm:update
description: Quick mid-day status of coordinated multi-Claude work
allowed-tools: Bash
---

# Multitasking Manager - Quick Status

Lightweight mid-day check of coordinated work and today's activity.

## Usage

```
/mtm:update
```

## What This Does

1. List all active contexts:
   ```bash
   mta-engine list-contexts
   ```

2. Get status overview (sessions, decisions, blockers per context):
   ```bash
   mta-engine status
   ```

3. Check for unresolved blockers:
   ```bash
   mta-engine list-blockers --unresolved
   ```

4. List active sessions:
   ```bash
   mta-engine list-sessions
   ```

5. Check cognitive debt:
   ```bash
   mta-engine debt
   ```

6. Show today's journal entries for continuity:
   ```bash
   mta-engine journal --today --format=json
   ```

7. Run `work-context conversations 0` (today only) for quick session overview

8. Quick PR check from `work-context data 0`:
   - Only flag PRs needing immediate action (approved, changes requested)
   - Skip the full PR breakdown (that's for start-day)

## Output Format

```
## Quick Status

### Active Coordinations
- **PROJ-1641** [priority: high]: 2 active sessions | no blockers | debt: 5 unreviewed (3 high-RISC)
- **INCIDENT-outage** [priority: urgent]: 1 session | BLOCKING | debt: 0

### Blockers
- INCIDENT-outage blocking PROJ-1641

### PRs Needing Action
- #12345 "Fix auth" — APPROVED, ready to merge
- #12350 "Add caching" — CHANGES REQUESTED

### Today's Sessions
(output from work-context conversations 0)
```

## Notes

This is the quick mid-day check. For full morning overview with 7-day history, use `/mtm:start-day`.

If no contexts exist, just show today's sessions and note: "No shared contexts. Use /mtm:new-context <ticket> to start coordinating."
