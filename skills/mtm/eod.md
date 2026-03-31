---
name: mtm:eod
description: End of day wrap-up for coordinated multi-Claude work
allowed-tools: Bash
---

# Multitasking Manager - End of Day

Wind down coordinated work across Claude sessions.

## Usage

```
/mtm:eod
```

## What This Does

1. **Check for uncommitted changes** across all worktrees:
   ```bash
   work-context data 7
   ```
   Then for each worktree with recent activity (age_days <= 1):
   ```bash
   cd /home/user/dev/<worktree> && git status --short
   ```
   Flag any with uncommitted changes.

2. **Review active contexts**:
   ```bash
   mta-engine list-contexts
   mta-engine status
   ```

3. **Record EOD summaries** for each active context:
   ```bash
   mta-engine add-decision <TICKET> "EOD: <summary of today's progress and tomorrow's plan>"
   ```

4. **Check for unresolved blockers**:
   ```bash
   mta-engine list-blockers --unresolved
   ```

5. **Check cognitive debt**:
   ```bash
   mta-engine debt
   ```
   Flag contexts where debt grew today (compare chunk timestamps to today's date).

6. **Check pending MTM tasks** (reminders of what's still undone):
   ```bash
   mta-engine mtm-list-tasks --pending --format=json
   ```

7. **Add EOD journal entry** — ask the user for a brief summary of the day, then record it:
   ```bash
   mta-engine journal "EOD: <user's summary>"
   ```
   If the user declines, skip. The journal captures cross-cutting observations that don't belong to any single ticket.

8. **Review open PRs** from `work-context data 7`:
   - Flag approved PRs not yet merged (could merge before EOD)
   - Flag PRs with changes requested (need follow-up tomorrow)
   - Note any PRs updated today that are still awaiting review

9. **Output summary**:
   ```
   ## End of Day

   ### Uncommitted Changes
   - (none) or list worktrees needing commits

   ### PRs to Act On
   - #12345 "Fix auth" — APPROVED, merge before EOD?
   - #12350 "Add caching" — CHANGES REQUESTED, follow up tomorrow

   ### Cognitive Debt
   - PROJ-1641: 5 unreviewed | weighted: 28 | 3 high-RISC (grew +2 today)
   - Consider `/mta:quiz` or `/mta:premortem` for high-RISC items

   ### MTM Tasks Still Pending
   - [ ] Review approved PRs (added 2d ago)
   - (or: All MTM tasks completed today)

   ### Coordinated Work
   - PROJ-1641: [status summary] | Tomorrow: [next steps]

   ### Blockers
   - INCIDENT-outage: unresolved

   ### Journal
   - Recorded: "EOD: Focused on auth migration, INCIDENT-outage resolved mid-afternoon"
   - (or: Skipped journal entry)

   ### Parked (no action needed)
   - ds9, ds3
   ```

## Notes

- Don't create commits automatically - just flag what needs attention
- Keep EOD decision entries concise - just today's summary and tomorrow's plan
- If a worktree has uncommitted changes, ask user if they want to commit before closing out
