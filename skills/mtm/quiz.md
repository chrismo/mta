---
name: mtm:quiz
description: Interactive comprehension check on high-RISC unreviewed chunks
allowed-tools: Bash
---

# Cognitive Debt Quiz

Verify your understanding of what Claude built by answering questions about high-RISC chunks.

## Usage

```
/mtm:quiz [ticket]
```

If ticket is omitted, quiz across all active contexts (highest RISC first).

## What This Does

1. Get unreviewed chunks sorted by RISC:
   ```bash
   mta-context.sh list-chunks <TICKET> --unreviewed
   ```
   If no ticket specified:
   ```bash
   mta-context.sh debt
   ```
   Then pick the context with highest debt.

2. For each chunk (up to 5 per session), starting with highest RISC:

   a. Show the chunk info:
      ```
      Chunk: "retry backoff logic" (RISC: 8)
      Commit: a3f7e2b
      Files: src/sync.sh, src/async.sh
      RISC reason: cross-cutting, timing-sensitive
      ```

   b. Read the actual code change:
      ```bash
      git show <commit> -- <files>
      ```
      If files not recorded, show the full commit diff:
      ```bash
      git show <commit>
      ```

   c. Ask a specific comprehension question about the change. Examples:
      - "What happens if the API returns a 429 during the retry window?"
      - "This function modifies shared state in two places. What are they?"
      - "What's the failure mode if `bc` isn't installed?"

      Questions should be specific to the code, NOT generic. Bad: "What is retry logic?"
      Good: "What determines the backoff interval between retries?"

   d. Evaluate the answer:
      - The goal is understanding, not perfection
      - If the human demonstrates they grasp the key concern: mark reviewed
      - If not: explain what matters and offer to re-ask or move on

   e. If satisfied:
      ```bash
      mta-context.sh review-chunk <TICKET> "<summary>"
      ```

3. The human can say:
   - **"skip"** — move to next chunk without marking reviewed
   - **"I reviewed this already"** or **"mark reviewed"** — mark reviewed without answering
   - **"stop"** — end the quiz session

4. After the quiz, show updated debt:
   ```bash
   mta-context.sh debt <TICKET>
   ```

## Output Format

```
## Cognitive Debt Quiz: PROJ-1641

### Chunk 1/5: "retry backoff logic" (RISC: 8)
Files: src/sync.sh, src/async.sh

[shows diff]

Question: What determines the maximum number of retry attempts,
and what happens when it's exceeded?

> [human answers]

That's correct — the MAX_RETRIES constant caps it at 3, and on exhaustion
it raises a RetryExhausted error that propagates to the caller.

Marked as reviewed.

---

### Chunk 2/5: "auth token refresh" (RISC: 9)
...

---

## Session Summary
Reviewed: 3/5 chunks
Remaining debt: 4 unreviewed | weighted: 18 | 2 high-RISC
```

## Notes

- Prioritize high-RISC chunks — those are where misunderstanding is most dangerous
- Keep questions focused on the "what could go wrong" aspect, not trivia
- One question per chunk is usually enough — this shouldn't feel like an exam
- If the commit is no longer in the local git history, note that and ask the human to review the summary/reason instead
