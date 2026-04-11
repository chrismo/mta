---
name: mta:overview
description: Full context overview — blockers, tasks, decisions, and cognitive debt
allowed-tools: Bash
---

# Context Overview

Full overview: blockers, tasks, decisions, chunk debt, coverage gaps, and suggested actions.

## Usage

```
/mta:overview [ticket]
```

If ticket is omitted, use the context from `/mta:join` or detect from branch.

## Context Discovery (IMPORTANT)

After context compaction, this session may not remember having joined a context.
Do NOT give up quickly. Follow this discovery chain:

1. **Look up active context**:
   ```bash
   mta-engine my-context
   ```
   This auto-detects your session and returns the ticket you joined. Use this first — it survives compaction.
2. **Detect from branch**: `git branch --show-current` → extract ticket pattern
3. **Search contexts**:
   ```bash
   mta-engine get-context <TICKET>
   mta-engine list-contexts
   ```
4. **If context found**: Proceed — treat it as if you joined.
5. **If no context found**: Ask the user which ticket to review.

## What This Does (ALL READ-ONLY)

1. Get full context status (sessions, decisions, pending tasks, unresolved blockers):
   ```bash
   mta-engine status <TICKET>
   ```

2. Get debt summary (scoped to current branch):
   ```bash
   mta-engine debt <TICKET> --branch=$(git branch --show-current)
   ```

3. Get unreviewed chunks (scoped to current branch):
   ```bash
   mta-engine list-chunks <TICKET> --unreviewed --branch=$(git branch --show-current)
   ```

4. Quick gap check — compare branch commits against chunk coverage:
   ```bash
   git log main..HEAD --oneline
   ```
   Fall back to `master` if `main` doesn't exist.

   **Working directly on main:** If the current branch IS main (or master),
   use existing chunk commits to find the range (most recent tracked SHA as base),
   or if no chunks exist, scan recent history (`git log -20 --oneline`) and identify
   commits contextually related to the current work/conversation.

   Count commits whose SHAs don't appear in any chunk's commit field
   (remember chunks can have comma-separated SHAs).

5. Present unified overview (see Output Format below).

6. Suggest next actions based on findings:
   - **Unresolved blockers** → call them out first
   - **Pending tasks** → list them
   - **Untracked commits exist** → suggest `/mta:chunk`
   - **High-RISC unreviewed chunks** → suggest `/mta:review` for walkthrough, `/mta:quiz` or `/mta:premortem` as alternatives
   - **Low debt / all reviewed** → "You're in good shape"

Does NOT create, modify, or mark chunks. Pure read-only triage.

## Output Format

```
## Overview: PROJ-1641

### Blockers
- Waiting on CI fix for dependency access (unresolved)

### Pending Tasks
- Implement retry logic for failed API calls
- Add unit tests for ceiling calculation

### Decisions
- Rate limiting uses bc for ceiling calc (bash truncates)
- Retry delays shared between sync and async paths

### Debt Summary
Unreviewed: 4 chunks | Weighted score: 22 | High-RISC (≥7): 2

### Top Unreviewed (by RISC)
1. "auth token refresh" RISC:9 — src/auth.sh
2. "retry backoff logic" RISC:8 — src/sync.sh, src/async.sh

### Coverage Gaps
3 commits not tracked by any chunk (out of 12 total)

### Suggested Actions
- Resolve 1 blocker before continuing
- Run `/mta:chunk` to create chunks for 3 untracked commits
- Run `/mta:review` to walk through 2 high-RISC unreviewed chunks
```

If there are no chunks at all and no commits on the branch:
```
## Overview: PROJ-1641

No commits on branch, no chunks recorded. Nothing to review.
```

If everything is tracked and reviewed:
```
## Overview: PROJ-1641

All 12 commits tracked across 5 chunks. All chunks reviewed.
No pending tasks. No unresolved blockers.
You're in good shape.
```

Omit any section that has no data (e.g., no blockers → skip the Blockers section).

## Notes

- This should be fast — no diff reading, no AI analysis, just data queries
- Keep the output scannable — the human should grok the state in 10 seconds
- This is called automatically at the end of `/mta:update`
- **Gap check limitation**: The current gap check is commit-level only — it checks
  whether a commit SHA appears in any chunk. A chunk can claim a commit but only
  cover part of its diff. A future `mta-engine chunk-gaps` command will do
  line-level coverage checking (see TODO in `/mta:chunk` notes).
