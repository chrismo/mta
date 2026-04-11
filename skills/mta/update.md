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
   mta-engine add-decision <TICKET> "<decision text>"
   ```
   Run once for each significant decision/change.

5. Record outstanding tasks:
   ```bash
   mta-engine add-task <TICKET> "<task description>"
   ```
   Run for any pending work that needs to be picked up.

6. Record any blockers:
   ```bash
   mta-engine add-blocker <TICKET> "<blocker description>"
   ```

7. Prompt: Should I commit and push? (if there are uncommitted changes)

8. Run `/mta:overview` to show the current cognitive debt picture.

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

Uncommitted changes:
- src/services/auth/auth-handler.sh (modified)

Commit and push? [y/n]

[then /mta:overview output follows]
```

If no outstanding tasks exist, omit the "Tasks" section.

## If No Meaningful Updates

If the session was just exploration or reading:

```
No significant decisions to record. Skip update? [y/n]
```
