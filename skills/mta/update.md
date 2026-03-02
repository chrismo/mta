---
name: mta:update
description: Record decisions and work done to shared context
allowed-tools: Bash, TodoRead, Skill
---

# Update Shared Context

Record what you accomplished so other Claude sessions know.

## Usage

```
/mta:update [ticket]
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
4. **If context found**: Proceed with the update — treat it as if you joined.
   Re-derive your session identifier from the scratchpad path and worktree name.
5. **If no context found**: Offer to create one (don't just bail out).

The goal is to ALWAYS find or create a context to write to. Only ask the user
if you genuinely can't determine which ticket this session is working on.

## What This Does

1. Run `/mta:read <ticket>` to understand current state before updating

2. Summarize what was accomplished in this session:
   - Review conversation history for key decisions, changes, learnings
   - Look at git diff/status for concrete changes
   - Identify 2-5 key points other Claudes should know

3. Check for outstanding tasks using TodoRead:
   - Capture any pending or in-progress tasks
   - These represent incomplete work that future sessions should pick up

4. Record decisions:
   ```bash
   mta-context.sh add-decision <TICKET> "<decision text>"
   ```
   Run once for each significant decision/change.

5. Record outstanding tasks:
   ```bash
   mta-context.sh add-task <TICKET> "<task description>"
   ```
   Run for any pending work that needs to be picked up.

6. Record any blockers:
   ```bash
   mta-context.sh add-blocker <TICKET> "<blocker description>"
   ```

7. Record RISC-graded chunks for commits in this session:
   - Check recent commits: `git log --oneline -10`
   - For each commit, break it into logical concerns (usually 1:1 with the commit)
   - Grade each chunk with a RISC score (1-10):
     - **1-3 Low**: Config, test scaffolding, formatting, comments
     - **4-6 Medium**: New functions, refactors with clear boundaries, dependency updates
     - **7-10 High**: Cross-cutting changes, state management, auth/security, error handling that changes failure modes, anything subtle
   - RISC = **R**each (how much code does this touch?), **I**rreversibility (how hard to undo?), **S**ubtlety (how easy to misunderstand?), **C**onsequence (what breaks if wrong?)
   ```bash
   mta-context.sh add-chunk <TICKET> <commit-sha> "<summary>" <risc> \
     --files="<comma-separated files>" \
     --risc-reason="<why this score>"
   ```
   Run once per chunk. Multiple chunks per commit are fine if the commit has mixed concerns.

8. Prompt: Should I commit and push? (if there are uncommitted changes)

## Decision Extraction

Look for:
- Architectural decisions ("we decided to use X because Y")
- Implementation changes ("changed ceiling calc to use bc")
- Gotchas discovered ("SuperDB doesn't support X, had to work around")
- Blockers ("waiting on CI fix for dependency access")

Keep entries concise - one line each. Other Claudes need signal, not noise.

## Output Format

```
## Update: <ticket>

Added to shared context:

Decisions:
- Rate limiting uses bc for ceiling calc (bash truncates)
- Retry delays shared between sync and async paths

Tasks:
- Implement retry logic for failed API calls
- Add unit tests for ceiling calculation

Chunks (RISC-graded):
- a3f7e2b "ceiling calc utility" RISC:3 (pure function, isolated)
- a3f7e2b "retry backoff logic" RISC:8 (cross-cutting, timing-sensitive)

Uncommitted changes:
- src/services/auth/auth-handler.sh (modified)

Commit and push? [y/n]
```

If no outstanding tasks exist, omit the "Tasks" section.

## If No Meaningful Updates

If the session was just exploration or reading:

```
No significant decisions to record. Skip update? [y/n]
```
