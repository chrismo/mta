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
   mta-context.sh list-contexts
   mta-context.sh status
   ```

3. **Record EOD summaries** for each active context:
   ```bash
   mta-context.sh add-decision <TICKET> "EOD: <summary of today's progress and tomorrow's plan>"
   ```

4. **Check for unresolved blockers**:
   ```bash
   mta-context.sh list-blockers --unresolved
   ```

5. **Review open PRs** from `work-context data 7`:
   - Flag approved PRs not yet merged (could merge before EOD)
   - Flag PRs with changes requested (need follow-up tomorrow)
   - Note any PRs updated today that are still awaiting review

6. **Output summary**:
   ```
   ## End of Day

   ### Uncommitted Changes
   - (none) or list worktrees needing commits

   ### PRs to Act On
   - #12345 "Fix auth" — APPROVED, merge before EOD?
   - #12350 "Add caching" — CHANGES REQUESTED, follow up tomorrow

   ### Coordinated Work
   - PROJ-1641: [status summary] | Tomorrow: [next steps]

   ### Blockers
   - INCIDENT-outage: unresolved

   ### Parked (no action needed)
   - ds9, ds3
   ```

## Notes

- Don't create commits automatically - just flag what needs attention
- Keep EOD decision entries concise - just today's summary and tomorrow's plan
- If a worktree has uncommitted changes, ask user if they want to commit before closing out
