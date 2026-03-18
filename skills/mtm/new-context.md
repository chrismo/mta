---
name: mtm:new-context
description: Create shared context for a new coordinated multi-Claude effort
allowed-tools: Bash
---

# Multitasking Manager - New Context

Create a shared context for coordinating multiple Claude sessions on a goal.

## Philosophy

Shared contexts are **ephemeral war room whiteboards**, not permanent TODO systems.

- **Goal-scoped**: created for a specific push (launch, incident, feature)
- **Disposable**: AI sloppiness is fine because it gets archived when done
- **Not a backlog**: blockers live here temporarily, long-lived TODOs belong elsewhere

When the goal is achieved, archive the context.

## Usage

```
/mtm:new-context <goal-name> [title]
```

## What This Does

1. Check if context already exists:
   ```bash
   mta-engine get-context <GOAL-NAME>
   ```
   - If yes, show current state and ask if user wants to proceed

2. Create the context:
   ```bash
   mta-engine create-context <GOAL-NAME> "<title>" [--ticket-url=...] [--branch=...] [--worktree=...]
   ```

## Output

```
Created shared context for <goal-name>.

Workers can now:
- /mta:join <goal-name> - to register with this coordination
- /mta:read - to see what others have done
- /mta:update - to record their work
- /mta:leave - when done with this goal
```

## Notes

If no title is provided, ask the user for a brief description.
Optionally include `--ticket-url` to link to the ticket tracker.
