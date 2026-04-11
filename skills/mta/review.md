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

## What This Does

1. Get unreviewed chunks sorted by RISC descending:
   ```bash
   mta-engine list-chunks <TICKET> --unreviewed --branch=$(git branch --show-current)
   ```

2. For each chunk (no cap — the human controls pace with "stop"):

   a. Show chunk header:
      ```
      ### Chunk 1: "retry backoff logic" (RISC: 8)
      Commit: a3f7e2b
      Files: src/sync.sh, src/async.sh
      RISC reason: cross-cutting, timing-sensitive
      ```

   b. Show the diff — **IMPORTANT: render as markdown, not inside a tool call**:
      - Capture the diff using the helper command (handles multi-commit chunks,
        file scoping, and all edge cases automatically):
        ```bash
        diff_output=$(mta-engine chunk-diff <TICKET> "<summary>")
        ```
      - Then output the diff as markdown text using ````diff` fenced blocks — one
        per file. Do NOT display git show output directly in a tool result (it
        collapses and the human can't see it). Parse the captured output and
        re-render it yourself as text.

   c. **Sub-chunk display**: if the diff is longer than ~60 lines, split at
      `@@` hunk boundaries and show one section at a time:
      ```
      Section 1/3:
      ```diff
      [hunk diff]
      ```

      Type "next" for next section, "show all" to see remaining at once.
      ```

   d. Wait for human input:
      - **"good"** / **"lgtm"** → mark reviewed
      - **"discuss"** → talk about the chunk, then decide whether to mark reviewed
      - **"skip"** → move to next chunk without marking
      - **"stop"** → end the review session

   e. Mark reviewed when appropriate:
      ```bash
      mta-engine review-chunk <TICKET> "<summary>"
      ```

3. After the walkthrough (or on "stop"), show updated debt:
   ```bash
   mta-engine debt <TICKET>
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

```diff
--- a/src/auth.sh
+++ b/src/auth.sh
@@ -42,6 +42,10 @@
 ...actual diff lines...
```

good / discuss / skip / stop?

> good

Marked as reviewed.

---

### Chunk 2: "retry backoff logic" (RISC: 8)
Commit: a3f7e2b
Files: src/sync.sh, src/async.sh (Section 1/3)
RISC reason: cross-cutting, timing-sensitive

```diff
[first hunk]
```

next / show all / good / discuss / skip / stop?

> show all

```diff
[remaining hunks]
```

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
