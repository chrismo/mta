---
name: mta:quiz
description: Interactive comprehension check on high-RISC unreviewed chunks
allowed-tools: Bash
---

# Cognitive Debt Quiz

Verify your understanding of what Claude built by answering questions about high-RISC chunks.

## Usage

```
/mta:quiz [ticket]
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

1. Get unreviewed chunks for the current ticket, sorted by RISC:
   ```bash
   mta-context.sh list-chunks <TICKET> --unreviewed
   ```

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

   c. **Ground the question in tests** before asking:

      1. Search for tests that exercise the behavior you're about to ask about:
         ```bash
         grep -r "<function_or_behavior>" test/
         ```
      2. If you find a relevant passing test: cite it. Your confidence in the
         answer comes from the test, not from reading the implementation alone.
      3. If no test covers this behavior: **STOP. Do not frame this as a quiz
         question.** Instead, break out of quiz mode and flag it as a discovered gap:

         > "I noticed [X] while reviewing this chunk. There's no test covering
         > this behavior, so I'm not confident in my understanding. Let's
         > review it together."

         Discuss the gap collaboratively. After resolving it (or deciding it's
         a non-issue), resume the quiz.

      Well-grounded question examples:
      - "In `batch_update_games()`, when both scores are 0, the winner is left
        empty. The test `update_game with both scores 0 leaves winner empty`
        verifies this. Does the batch version preserve that behavior, and how?"
      - "What determines the backoff interval between retries? (See test
        `retry uses exponential backoff` in sync.bats)"

      Questions should be specific to the code, NOT generic. Bad: "What is retry logic?"

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
- **Never disguise a discovered gap as a comprehension question.** If you find something uncertain while reading the code, say so directly — the human needs to know whether they're being tested on something verified or consulted about something unknown
