# MTA - Multi-Ticket Assistance

See [README.md](README.md) for full project docs, installation, usage, and schema.

## Key Components

- `bin/mta-engine` - CLI that all skills invoke. Must be in PATH.
- `skills/work-context.sh` - Work context script (worktrees, conversations, PRs). Installed as `work-context` in PATH.
- `skills/work-context.md` - `/work-context` skill definition
- `skills/mta/` - MTA worker skills (`/mta:join`, `/mta:read`, `/mta:update`, `/mta:leave`, `/mta:dupe`)
- `skills/mtm/` - MTM manager skills (`/mtm:update`, `/mtm:start-day`, `/mtm:eod`, `/mtm:new-context`, `/mtm:archive`, `/mtm:slot`)

## Testing

```bash
bats --jobs 8 test/mta-engine.bats test/mta.bats
```

**TDD is mandatory for ALL code changes** — bug fixes, refactors, new features. Write a failing test first, confirm it fails, then implement. For refactors, write tests that pin existing behavior before changing the code.
