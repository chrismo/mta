# MTA Context Storage Refactor: SuperDB

## Problem

Current mta skills (join, update, leave) trigger many permission prompts because Claude reads/writes markdown files directly. Each file operation needs approval.

## Solution

1. Store context data in `.sup` files (SuperDB format)
2. Shell script (`mta-engine`) handles all file operations via `super` CLI
3. Skills invoke the script instead of direct file access
4. One script approval vs many read/write approvals

## Why SuperDB over JSON

- Relational model with multiple files (like tables)
- SQL queries for joins, aggregations across tickets
- Appending records is just appending lines
- Claude already knows SuperDB well
- Trivial to query "all active sessions" or "decisions this week"

## Proposed Schema

Location: `~/.claude/contexts/`

### contexts.sup
The parent record for each coordination effort.
```
{ticket:"PROJ-1641",title:"Upgrade auth service",created:"2026-01-27T16:32:00Z",archived_at:null,ticket_url:"https://tracker.example.com/...",branch:"proj-101-...",worktree:"wt1",priority:"high"}
{ticket:"PROJ-1670",title:"CI pipeline experiment",created:"2026-01-29T09:00:00Z",archived_at:null,ticket_url:"...",branch:"...",worktree:"ds9"}
```

### sessions.sup
Active/historical sessions linked to contexts.
```
{ticket:"PROJ-1641",session_id:"ds5/c342fbfe",joined_at:"2026-01-29T16:30:00Z",left_at:null}
{ticket:"PROJ-1641",session_id:"ds5/a779c24f",joined_at:"2026-01-29T15:30:00Z",left_at:null}
{ticket:"PROJ-1641",session_id:"ds8",joined_at:"2026-01-27T16:00:00Z",left_at:"2026-01-27T18:25:00Z",status:"handoff",note:"diagnosed EnvType tag issue"}
```

### decisions.sup
Decision log with timestamps.
```
{ticket:"PROJ-1641",ts:"2026-01-29T20:42:00Z",text:"AUTH MIGRATION E2E VERIFIED"}
{ticket:"PROJ-1641",ts:"2026-01-28T22:45:00Z",text:"CRITICAL: Deploy SuperDB version must match local dev"}
```

### tasks.sup
Outstanding tasks (incomplete work for future sessions).
```
{ticket:"PROJ-1641",ts:"2026-01-29T21:00:00Z",text:"Add deploy permission to dev profile",status:"pending"}
{ticket:"PROJ-1641",ts:"2026-01-29T21:00:00Z",text:"Fix JSON quote escaping in deploy script",status:"pending"}
```

### blockers.sup
Active blockers (resolved ones can be marked).
```
{ticket:"PROJ-1706",ts:"2026-01-29T09:00:00Z",text:"Wiki page requires auth",resolved:null}
{ticket:"PROJ-1641",ts:"2026-01-27T17:30:00Z",text:"Dashboard metrics not appearing",resolved:"2026-01-27T18:10:00Z"}
```

### journal.sup
Manager journal — freeform timestamped notes not tied to any ticket.
```
{ts:"2026-03-19T14:00:00Z",text:"Incident response consumed the day"}
{ts:"2026-03-19T09:15:00Z",text:"Reprioritizing PROJ-1641 after stakeholder call"}
```

### mtm-tasks.sup
Manager-level tasks — cross-cutting checklist not tied to any ticket.
```
{ts:"2026-03-31T09:00:00Z",text:"Review approved PRs",status:"pending"}
{ts:"2026-03-31T10:00:00Z",text:"Check CI pipeline config",status:"completed"}
```

## Example Queries

```bash
# All active sessions (not yet departed)
super -c "from 'sessions.sup' | where left_at = null"

# Decisions for a ticket, sorted
super -c "from 'decisions.sup' | where ticket = 'PROJ-1641' | sort ts"

# Contexts with active session counts
super -c "
  from 'contexts.sup'
  | join (
      from 'sessions.sup'
      | where left_at = null
      | count() by ticket
    ) on ticket
"

# Unresolved blockers across all tickets
super -c "from 'blockers.sup' | where resolved = null"

# Recent decisions (last 24h)
super -c "from 'decisions.sup' | where ts > '2026-01-28T00:00:00Z' | sort ts desc"

# Today's journal entries
super -c "from 'journal.sup' | where ts >= '2026-03-19T00:00:00Z' | sort ts desc"

# Contexts with priority set
super -c "from 'contexts.sup' | where archived_at is null and not missing(priority) and priority is not null"

# Pending MTM tasks
super -c "from 'mtm-tasks.sup' | where status = 'pending' | sort ts desc"
```

## Script Interface

```bash
mta-engine <command> [args]

# Context management
mta-engine create-context <ticket> <title> [--ticket-url=...] [--branch=...] [--worktree=...]
mta-engine list-contexts
mta-engine get-context <ticket>

# Session management
mta-engine join <ticket> <session-id>
mta-engine leave <ticket> <session-id> <status> [note]
mta-engine list-sessions [ticket]

# Decisions
mta-engine add-decision <ticket> <text>
mta-engine list-decisions <ticket>

# Tasks
mta-engine add-task <ticket> <text>
mta-engine complete-task <ticket> <task-text-pattern>
mta-engine list-tasks [ticket] [--pending]

# Blockers
mta-engine add-blocker <ticket> <text>
mta-engine resolve-blocker <ticket> <blocker-text-pattern>
mta-engine list-blockers [--unresolved]

# Journal
mta-engine journal <text>            # add a journal entry
mta-engine journal                   # show last 10 entries
mta-engine journal --today           # today's entries only
mta-engine journal --list [N]        # last N entries (default 10)

# MTM Tasks (manager-level)
mta-engine mtm-add-task <text>
mta-engine mtm-complete-task <task-text-pattern>
mta-engine mtm-list-tasks [--pending] [--format=json|csv|table]

# Priority
mta-engine set-priority <ticket> <text>   # set priority on a context
mta-engine set-priority <ticket> --clear  # clear priority

# Status/reporting
mta-engine status [ticket]           # formatted status for one or all
mta-engine archive <ticket>          # move to archive
```

## Migration

1. Build script + schema
2. Migrate existing .md contexts to .sup files (one-time)
3. Update mta skills to use script
4. Test the flow
5. Delete old .md files

## Archive Strategy

Archived contexts move to `~/.claude/contexts/archive/` - same .sup format, just different location. Or add `archived_at` field to contexts.sup and filter on queries.
