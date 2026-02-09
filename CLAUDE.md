# MTA - Multi-Ticket Assistance

## Overview

MTA coordinates multiple Claude sessions working on the same ticket via shared context stored in SuperDB `.sup` files.

## Key Components

- `bin/mta-context.sh` - CLI that all skills invoke. Must be in PATH.
- `skills/` - MTA worker skills (`/mta:join`, `/mta:read`, `/mta:update`, `/mta:leave`, `/mta:dupe`)
- `skills/mtm/` - MTM manager skills (`/mtm:status`, `/mtm:start-day`, `/mtm:eod`, `/mtm:new-context`, `/mtm:archive`, `/mtm:slot`)

## Dependencies

- [SuperDB](https://superdb.org/) (`super` CLI) - data storage and queries
- Bash 4+

## Data Location

All context data lives in `~/.claude/contexts/` as `.sup` files. Override with `MTA_CONTEXTS_DIR` env var.

## Testing

```bash
bats test/mta-context.bats
```
