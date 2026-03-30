---
name: mta:quiz
description: Collaborative comprehension check on high-RISC unreviewed chunks
allowed-tools: Bash
---

# Cognitive Debt Quiz

Build shared understanding of what Claude built by working through high-RISC chunks together. Neither of you has the full picture — the human wasn't there when the code was written, and Claude may have misunderstood its own work. The quiz is where you meet in the middle.

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
   mta-engine get-context <TICKET>
   mta-engine list-contexts
   ```
4. **If context found**: Proceed — treat it as if you joined.
5. **If no context found**: Ask the user which ticket to review.

## What This Does

1. Get unreviewed chunks for the current ticket, sorted by RISC:
   ```bash
   mta-engine list-chunks <TICKET> --unreviewed
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

   d. **Assess comprehension together.** After each answer, consider whether
      the human understands this chunk — not just the surface, but the
      edge cases, failure modes, and design intent. But remember: you are
      also fallible here. You may have misread the code, hallucinated a
      detail, or overstated your own confidence. This is a collaborative
      exercise between two flawed machines — one carbon, one silicon —
      trying to build shared understanding. Consider:
      - Did they get it right, or just close enough?
      - Could they maintain this code confidently if it broke at 2am?
      - Have you covered the riskiest aspects of this chunk?
      - Are YOU sure about the answer you expect? If not, say so.

      Based on your assessment:
      - **Something doesn't add up:** Explain what seems off — maybe the
        human missed something, or maybe you did. Ask another question
        probing a different angle. Don't ask permission to continue —
        just ask the next question.
      - **Running low on angles to probe:** Say so with hedged language —
        e.g. "I feel like we've covered the main risk areas on this chunk."
        This is never deterministic, so don't state it as certainty. Then
        wait for the human to decide (mark reviewed, skip, or keep going).
      - **Err toward more questions.** One good answer is not enough. Probe
        at least 2-3 different aspects before you run out of things to ask.
        The riskier the chunk (higher RISC), the more thorough you should be.
      - **Never recommend marking reviewed.** That's the human's call. Your
        job is to keep probing until you've exhausted the risky angles or
        the human tells you to move on.

      The human can always say "mark reviewed", "skip", or "stop" at any
      point to override your assessment.

   e. When the human marks the chunk reviewed:
      ```bash
      mta-engine review-chunk <TICKET> "<summary>"
      ```

3. The human can say at any point:
   - **"skip"** — move to next chunk without marking reviewed
   - **"I reviewed this already"** or **"mark reviewed"** — mark reviewed without answering
   - **"stop"** — end the quiz session

4. After the quiz, show updated debt:
   ```bash
   mta-engine debt <TICKET>
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

That matches what I see in the code — MAX_RETRIES at 3, RetryExhausted
on exhaustion. I think the backoff logic is the trickier part though:

Question: The backoff uses jitter — what's the range of the first
retry delay, and why does jitter matter here?

> [human answers]

Yeah, that's my read too. There's one more area I'm less sure about
myself, but it seems like it could matter in prod:

Question: What happens if the upstream service returns a 429 during
the retry window? How does that interact with the backoff?

> [human answers]

I feel like we've hit the main risk areas — retry cap, jitter rationale,
and the 429 interaction. I'm running low on angles to probe here.

> mark reviewed

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
- You drive the pace of questions, but never decide when a chunk is "understood." Ask multiple questions probing different angles. Higher RISC = more thorough probing. Remember you can be wrong too — if the human's answer surprises you, consider that they might be right
- If the commit is no longer in the local git history, note that and ask the human to review the summary/reason instead
- **Never disguise a discovered gap as a comprehension question.** If you find something uncertain while reading the code, say so directly — the human needs to know whether they're being tested on something verified or consulted about something unknown
