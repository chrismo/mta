---
name: mtm:archive
description: Archive a completed shared context
allowed-tools: Bash
---

# Multitasking Manager - Archive Context

Archive a completed shared context.

## Usage

```
/mtm:archive <ticket>
```

Example: `/mtm:archive PROJ-1697`

## What This Does

1. Verify the context exists:
   ```bash
   mta-engine get-context <TICKET>
   ```

2. Show current state so user can confirm:
   ```bash
   mta-engine status <TICKET>
   ```

3. Archive the context:
   ```bash
   mta-engine archive <TICKET>
   ```

## Output Format

```
Archived <TICKET>.
```

## Notes

- Archived contexts are excluded from `/mtm:update` and `/mtm:start-day`
- To view archived contexts: `mta-engine list-contexts` (shows all including archived)
