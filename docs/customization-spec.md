# MTA Customization Spec

## Problem

The core MTA/MTM skills make assumptions that won't hold for all users:

- `/mtm:slot` depends on Linear MCP for ticket lookup
- `start-day`, `eod`, `status` depend on `yah` for worktree/PR data
- `eod` hardcodes worktree paths
- Branch naming assumes `<PROJECT>-<NUM>-*`

Users will want to plug in their own ticket systems (Jira, GitHub Issues, Shortcut),
add custom steps to start-of-day and end-of-day workflows, and adapt to their own
dev environment layout.

## Design: Favor Composition via Inverted Control

Core skills are the building blocks. Users write **wrapper skills** that call core
skills and layer on their own logic. The user invokes their wrapper instead of the
core skill directly.

```
User invokes:   /my:start-day
                    |
                    v
Wrapper skill:  my/start-day.md
                    |
                    +-- calls /mtm:start-day  (core)
                    +-- calls /my:pr-review   (personal)
                    +-- runs custom queries   (personal)
```

This is already a proven pattern: `/mta:update-and-leave` composes
`/mta:update` + `/mta:leave`.

### Why Inversion Over Hooks

- Core skills stay simple and don't need hook discovery logic
- Users have full control over ordering and flow
- No non-determinism from file-existence checks in prompts
- Easy to understand: "my skill calls core skill"
- Works with the existing Skill tool mechanism

## Customization Patterns

### 1. Compose: Wrap with Pre/Post Steps

For workflows where the core skill logic is still wanted, but the user has
additional steps.

**Example: custom start-of-day**

```markdown
# ~/.claude/commands/my/start-day.md
---
name: my:start-day
description: My morning workflow
allowed-tools: Bash, Skill
---

1. Run /mtm:start-day for the core MTA overview.
2. Then check my team's Jira board: `jira-cli sprint active --board MYTEAM`
3. Summarize both together.
```

Good candidates: `start-day`, `eod`, `status`, `update`, `leave`

### 2. Replace: Swap a Core Skill Entirely

For cases where the core skill's approach doesn't fit at all - typically
ticket system integration.

**Example: Jira-based slot**

```markdown
# ~/.claude/commands/my/slot.md
---
name: my:slot
description: Get a claude-slot command for a Jira ticket
allowed-tools: Bash
---

Given a Jira ticket ID (e.g., PROJ-123):

1. Fetch ticket details: `jira-cli issue view PROJ-123 --plain`
2. Check for an existing MTA context: `mta-context.sh get-context PROJ-123`
3. If no context exists, create one: `mta-context.sh create-context PROJ-123`
4. Find an available worktree and output a `claude-slot` command.
```

Good candidates: `slot` (ticket system dependent), `dupe` (environment dependent)

### 3. Extend: New Skills Using Core Infrastructure

Users can write entirely new skills that call `mta-context.sh` directly.

**Example: weekly summary**

```markdown
# ~/.claude/commands/my/weekly.md
---
name: my:weekly
description: Weekly summary of all MTA activity
allowed-tools: Bash
---

Generate a weekly summary:
1. List all contexts active in the past 7 days.
2. For each, run `mta-context.sh status <TICKET>`.
3. Summarize decisions made, tasks completed, and open blockers.
```

## Making Core Skills Composition-Friendly

To support these patterns well, core skills should:

1. **Do one thing well.** Each core skill should be a useful building block
   on its own. Avoid stuffing unrelated steps into a single skill.

2. **Tolerate missing tools gracefully.** If `yah` isn't installed, `start-day`
   should still show MTA context data and note that worktree/PR info is
   unavailable. This makes core skills useful even without the full
   environment.

3. **Keep `mta-context.sh` as the stable interface.** Wrapper skills and
   extensions should call `mta-context.sh` subcommands, not poke at `.sup`
   files directly. The CLI is the contract.

4. **Document what each skill provides.** Wrapper authors need to know what
   output/context a core skill produces so they can build on it.

## Installation Convention

Core skills install to:
```
~/.claude/commands/mta/    (worker skills)
~/.claude/commands/mtm/    (manager skills)
```

Personal wrapper skills go in a separate namespace:
```
~/.claude/commands/my/     (or any user-chosen namespace)
```

This keeps core skills updatable without clobbering personal customizations.
The user simply invokes `/my:start-day` instead of `/mtm:start-day`.

## Migration Path

No breaking changes needed. This is purely additive:

1. Improve graceful degradation in core skills (handle missing `yah`, etc.)
2. Document the composition patterns (this spec)
3. Optionally ship example wrapper skills as templates in `examples/`

Users who don't customize anything keep using `/mtm:*` and `/mta:*` directly.
