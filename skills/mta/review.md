---
name: mta:review
description: Chunk-by-chunk code review walkthrough
allowed-tools: Bash
---

# Code Review Walkthrough

Walk through unreviewed chunks one at a time, showing actual diffs for human review.

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

## What This Does

1. Get unreviewed chunks sorted by RISC descending:
   ```bash
   mta-context.sh list-chunks <TICKET> --unreviewed --branch=$(git branch --show-current)
   ```

2. For each chunk (no cap — the human controls pace with "stop"):

   a. Show chunk header:
      ```
      ### Chunk 1: "retry backoff logic" (RISC: 8)
      Commit: a3f7e2b
      Files: src/sync.sh, src/async.sh
      RISC reason: cross-cutting, timing-sensitive
      ```

   b. Show the diff:
      ```bash
      git show <commit> -- <files>
      ```
      If files not recorded, show the full commit diff:
      ```bash
      git show <commit>
      ```
      For multi-commit chunks (comma-separated SHAs), show each commit's diff.

   c. **Sub-chunk display**: if the diff is longer than ~60 lines, split at
      `@@` hunk boundaries and show one section at a time:
      ```
      Section 1/3:
      [hunk diff]

      Type "next" for next section, "show all" to see remaining at once.
      ```

   d. Wait for human input:
      - **"good"** / **"lgtm"** → mark reviewed
      - **"discuss"** → talk about the chunk, then decide whether to mark reviewed
      - **"skip"** → move to next chunk without marking
      - **"stop"** → end the review session

   e. Mark reviewed when appropriate:
      ```bash
      mta-context.sh review-chunk <TICKET> "<summary>"
      ```

3. After the walkthrough (or on "stop"), show updated debt:
   ```bash
   mta-context.sh debt <TICKET>
   ```

## Output Format

```
## Code Review: PROJ-1641

4 unreviewed chunks (sorted by RISC)

---

### Chunk 1: "auth token refresh" (RISC: 9)
Commit: b4c5d6e
Files: src/auth.sh
RISC reason: security-critical, handles token expiry

[diff output]

good / discuss / skip / stop?

> good

Marked as reviewed.

---

### Chunk 2: "retry backoff logic" (RISC: 8)
Commit: a3f7e2b
Files: src/sync.sh, src/async.sh (Section 1/3)
RISC reason: cross-cutting, timing-sensitive

[first hunk]

next / show all / good / discuss / skip / stop?

> show all

[remaining hunks]

good / discuss / skip / stop?

> good

Marked as reviewed.

---

## Session Summary
Reviewed: 2/4 chunks
Remaining debt: 2 unreviewed | weighted: 8 | 0 high-RISC
```

## Notes

- Don't quiz, don't analyze risks — just show the code and let the human decide
- If a commit is not in local git history, show the chunk's summary and RISC reason,
  then offer to mark reviewed based on that info alone
- Keep the flow simple: show code, get verdict, move on
- The human can always say "discuss" to pause and talk about something they see
