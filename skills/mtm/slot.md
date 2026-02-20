---
name: mtm:slot
description: Get a claude-slot command to start a new worker on a ticket
allowed-tools: Bash
---

# Multitasking Manager - Slot

Generate a `claude-slot` command to start a new Claude worker on a ticket.

## Usage

```
/mtm:slot <ticket-id>
```

Example: `/mtm:slot PROJ-1714`

## What This Does

1. **Look up ticket in GitHub Issues**:
   - Get issue title, branch name, status, labels
   - Use `gh issue view <number>` to fetch details

2. **Find available worktree slots**:
   ```bash
   work-context data 7 2>/dev/null
   ```
   - Identify stale worktrees (age > 3 days, or marked done/archived)
   - Prefer slots with no active context or completed work
   - List top 2-3 candidates

3. **Check for existing context**:
   ```bash
   mta-context.sh get-context <TICKET>
   ```
   - Note if context already exists

4. **Output the command**:
   ```
   ## <TICKET-ID>: <title>

   **Branch:** <branch-name>
   **Status:** <status> | **Priority:** <priority>

   ### Available Slots
   | Slot | Current Branch | Age | Notes |
   |------|----------------|-----|-------|
   | ds4  | proj-301-...| 5d  | Likely complete |
   | ds7  | ena-101-...    | 3d  | |

   ### Recommended
   ```bash
   claude-slot ds4 "/mta:join <TICKET-ID>"
   ```

   Context: [exists | will be created on join]
   ```

## Notes

- The `/mta:join` command will handle branch checkout after joining
- If no stale slots available, suggest the least recently used one
- Always output the claude-slot command with `/mta:join <TICKET-ID>` format
