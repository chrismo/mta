---
name: mta:chunk
description: Sync recorded chunks with branch state — expensive, call directly
allowed-tools: Bash, Skill
---

# Chunk Sync

Analyze branch commits and create RISC-graded chunks for any untracked work.

## Usage

```
/mta:chunk [ticket]
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
5. **If no context found**: Ask the user which ticket to chunk.

## What This Does

1. Get the branch commit range:
   ```bash
   git log main..HEAD --oneline
   ```
   Fall back to `master` if `main` doesn't exist.

2. Get existing chunks:
   ```bash
   mta-context.sh list-chunks <TICKET>
   ```

3. Compare: find commits not covered by any chunk's commit field.
   Chunks can have comma-separated SHAs (e.g. `sha1,sha2`) — split on commas
   when checking coverage.

4. For each untracked commit:

   a. Read the diff:
      ```bash
      git show <commit>
      ```

   b. Break into **logical review units** — chunks are about what the human
      needs to understand, not about how commits are organized:
      - One chunk can span **multiple commits** (cross-commit logical change)
      - One chunk can span **multiple files** (small scattered change)
      - One file can have **many chunks** (complex file with distinct concerns)
      - There is no 1:1 assumption between chunks, commits, or files

   c. Grade each chunk with a RISC score (1-10):
      - **1-3 Low**: Config, test scaffolding, formatting, comments
      - **4-6 Medium**: New functions, refactors with clear boundaries, dependency updates
      - **7-10 High**: Cross-cutting changes, state management, auth/security, error handling that changes failure modes, anything subtle
      - RISC = **R**each (how much code does this touch?), **I**rreversibility (how hard to undo?), **S**ubtlety (how easy to misunderstand?), **C**onsequence (what breaks if wrong?)

   d. Create via CLI:
      ```bash
      # Small scattered change — one chunk, multiple files
      mta-context.sh add-chunk <TICKET> "<commit-sha>" "<summary>" <risc> \
        --files="config-a.sh,config-b.sh" --risc-reason="<why this score>"

      # Big file, multiple chunks with line ranges
      mta-context.sh add-chunk <TICKET> "<commit-sha>" "<summary>" <risc> \
        --files="big-file.sh" --lines="big-file.sh:42-58" --risc-reason="..."

      # Cross-commit logical change
      mta-context.sh add-chunk <TICKET> "<sha1>,<sha2>" "<summary>" <risc> \
        --files="file-a.sh,file-b.sh" \
        --lines="file-a.sh:120-135,file-b.sh:1-40" --risc-reason="..."
      ```

5. After creating all chunks, run `/mta:review` to show the updated debt picture.

## Output Format

```
## Chunk Sync: PROJ-1641

Analyzed 8 commits (main..HEAD)

Already tracked: 5 commits across 3 chunks
New chunks created:

- c4d5e6f "input validation for upload endpoint" RISC:7
  Files: src/upload.sh (lines 30-55)
  Reason: validates user input at system boundary, silent pass-through if wrong

- a1b2c3d,e7f8g9h "logging format standardization" RISC:2
  Files: src/sync.sh, src/async.sh, src/auth.sh
  Reason: mechanical find-replace, no logic changes

Created 2 chunks, 8/8 commits now tracked.
```

## Known Limitation: Non-deterministic Coverage

Chunking is intentionally non-deterministic — the agent decides how to group changes
into logical review units, which produces better results than mechanical splitting.
The tradeoff: the agent can silently miss code. A commit gets marked as "tracked"
but some of its changed lines might not belong to any chunk.

**TODO**: Build a deterministic blame-based coverage checker.

Approach — two layers:

1. **Deterministic script** (`mta-context.sh chunk-gaps <TICKET>`):
   - `git diff main..HEAD` → parse hunk headers for `(file, start, count)` of every
     changed line range in the final (HEAD) state
   - `git blame -L start,end file` on each range → `(file, line, commit)` tuples
     attributing each changed line to the commit that last touched it
   - Query chunks for the ticket, expand `--files`/`--lines` into claimed coverage
   - Report uncovered `(file, line_range, commit)` tuples — no opinions, just data
   - Line-drift is a non-issue: both the diff and blame operate in HEAD coordinates

2. **`/mta:chunk` consumes the report** and uses judgment:
   - Genuinely new uncovered code → create new chunk
   - Lines previously covered by a reviewed chunk that got reshuffled by a later
     refactor → update the existing chunk's commit/lines, optionally carry forward
     the reviewed status (agent decides if the change is mechanical enough)

Trade-off: a pure refactor after reviewed chunks will show as "uncovered" and
require re-chunking. But re-chunked mechanical refactors get low RISC scores,
so `/mta:review` surfaces them as low priority. The cost is in the re-chunking
step, not the human's review time.

## Notes

- Use `--lines` for sub-file granularity on large files — optional but encouraged
  when a file has multiple distinct concerns
- Group small related commits into one chunk rather than creating noise
- Split large commits into multiple chunks when they touch distinct concerns
- If a commit only touches tests or docs, it still gets a chunk — just low RISC
