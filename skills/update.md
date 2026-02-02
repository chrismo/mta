---
name: mta:update
description: Record decisions and work done to shared context
allowed-tools: Bash, TodoRead
---

# Update Shared Context

Record what you accomplished so other Claude sessions know.

## Usage

```
/mta:update [ticket]
```

If ticket is omitted, use the context from `/mta:join` or detect from branch.

## What This Does

1. Summarize what was accomplished in this session:
   - Review conversation history for key decisions, changes, learnings
   - Look at git diff/status for concrete changes
   - Identify 2-5 key points other Claudes should know

2. Check for outstanding tasks using TodoRead:
   - Capture any pending or in-progress tasks
   - These represent incomplete work that future sessions should pick up

3. Record decisions:
   ```bash
   mta-context.sh add-decision <TICKET> "<decision text>"
   ```
   Run once for each significant decision/change.

4. Record outstanding tasks:
   ```bash
   mta-context.sh add-task <TICKET> "<task description>"
   ```
   Run for any pending work that needs to be picked up.

5. Record any blockers:
   ```bash
   mta-context.sh add-blocker <TICKET> "<blocker description>"
   ```

6. Prompt: Should I commit and push? (if there are uncommitted changes)

## Decision Extraction

Look for:
- Architectural decisions ("we decided to use X because Y")
- Implementation changes ("changed ceiling calc to use bc")
- Gotchas discovered ("SuperDB doesn't support X, had to work around")
- Blockers ("waiting on CI fix for Oban Pro access")

Keep entries concise - one line each. Other Claudes need signal, not noise.

## Output Format

```
## Update: <ticket>

Added to shared context:

Decisions:
- Queue scaling uses bc for ceiling calc (bash truncates)
- Cooldowns shared between memory and queue paths

Tasks:
- Implement retry logic for failed API calls
- Add unit tests for ceiling calculation

Uncommitted changes:
- ops/platform/aws/ops-lambda/scripts/asg-scaler/asg-scaler.sh (modified)

Commit and push? [y/n]
```

If no outstanding tasks exist, omit the "Tasks" section.

## If No Meaningful Updates

If the session was just exploration or reading:

```
No significant decisions to record. Skip update? [y/n]
```

## Script Location

The `mta-context.sh` script is at `~/brain/ai-agents/claude/bin/mta-context.sh`.
You may need to use the full path or ensure it's in PATH.
