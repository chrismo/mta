---
name: mtm:journal
description: View and add cross-cutting journal entries
allowed-tools: Bash
---

# Multitasking Manager - Journal

Interact with the cross-cutting journal — observations, priorities, and notes that don't belong to any single ticket.

## Usage

```
/mtm:journal              Show recent entries
/mtm:journal <text>       Add a new entry
```

## What This Does

### If args are provided — add an entry

1. Record the journal entry:
   ```bash
   mta-engine journal "<text>"
   ```

2. Confirm what was recorded.

### If no args (or just flags) — show entries

1. Show recent journal entries:
   ```bash
   mta-engine journal --list 10 --format=json
   ```

2. Present entries in a readable format with timestamps.

3. If no entries exist, say so and suggest adding one.

## Notes

- Journal entries are cross-cutting — use them for priorities, context switches, observations, incident notes, anything that spans tickets.
- For ticket-specific notes, use `/mta:update` instead.
- The `--today`, `--date=YYYY-MM-DD`, and `--delete <timestamp>` flags on `mta-engine journal` are also available if the user asks for them.
