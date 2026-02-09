---
name: mta:update-and-leave
description: Record updates and deregister in one step
allowed-tools: Skill
---

# Update and Leave

Convenience command that runs `/mta:update` followed by `/mta:leave`.

## Usage

```
/mta:update-and-leave [ticket]
```

## What This Does

1. Run `/mta:update [ticket]`
2. Run `/mta:leave [ticket]`

That's it. See those commands for details.

## Notes

Use this when you're done with your work and want to wrap up quickly. If you need to record a blocker or do a handoff, use `/mta:leave` directly for the interactive prompts.
