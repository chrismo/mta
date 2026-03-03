---
name: mta:review
description: Fast read-only triage of cognitive debt and chunk coverage
allowed-tools: Bash
---

# Cognitive Debt Review

Quick triage: show cognitive debt status, flag gaps, suggest next actions.

## Usage

```
/mta:review [ticket]
```

If ticket is omitted, use the context from `/mta:join` or detect from branch.

## Context Discovery (IMPORTANT)

After context compaction, this session may not remember having joined a context.
Do NOT give up quickly. Follow this discovery chain:

1. **Check memory**: Do you remember a ticket from `/mta:join`?
2. **Detect from branch**: `git branch --show-current` → extract ticket pattern
3. **Search contexts**:
   ```bash
   mta-context.sh get-context <TICKET>
   mta-context.sh list-contexts
   ```
4. **If context found**: Proceed — treat it as if you joined.
5. **If no context found**: Ask the user which ticket to review.

## What This Does (ALL READ-ONLY)

1. Get debt summary:
   ```bash
   mta-context.sh debt <TICKET>
   ```

2. Get unreviewed chunks:
   ```bash
   mta-context.sh list-chunks <TICKET> --unreviewed
   ```

3. Quick gap check — compare branch commits against chunk coverage:
   ```bash
   git log main..HEAD --oneline
   ```
   Fall back to `master` if `main` doesn't exist.

   Count commits whose SHAs don't appear in any chunk's commit field
   (remember chunks can have comma-separated SHAs).

4. Present triage report (see Output Format below).

5. Suggest next actions based on findings:
   - **Untracked commits exist** → suggest `/mta:chunk`
   - **High-RISC unreviewed chunks** → suggest `/mta:quiz` or `/mta:premortem`
   - **Low debt / all reviewed** → "You're in good shape"

Does NOT create, modify, or mark chunks. Pure triage.

## Output Format

```
## Review: PROJ-1641

### Debt Summary
Unreviewed: 4 chunks | Weighted score: 22 | High-RISC (≥7): 2

### Top Unreviewed (by RISC)
1. "retry backoff logic" RISC:8 — src/sync.sh, src/async.sh
2. "auth token refresh" RISC:9 — src/auth.sh

### Coverage Gaps
3 commits not tracked by any chunk (out of 12 total)

### Suggested Actions
- Run `/mta:chunk` to create chunks for 3 untracked commits
- Run `/mta:premortem` to review 2 high-RISC chunks
```

If there are no chunks at all and no commits on the branch:
```
## Review: PROJ-1641

No commits on branch, no chunks recorded. Nothing to review.
```

If everything is tracked and reviewed:
```
## Review: PROJ-1641

All 12 commits tracked across 5 chunks. All chunks reviewed.
You're in good shape.
```

## Notes

- This should be fast — no diff reading, no AI analysis, just data queries
- Keep the output scannable — the human should grok the state in 10 seconds
- This is called automatically at the end of `/mta:update`
- **Gap check limitation**: The current gap check is commit-level only — it checks
  whether a commit SHA appears in any chunk. A chunk can claim a commit but only
  cover part of its diff. A future `mta-context.sh chunk-gaps` command will do
  line-level coverage checking (see TODO in `/mta:chunk` notes).
