# MTA Context Storage Refactor: SuperDB

## Problem

Current mta skills (join, update, leave) trigger many permission prompts because Claude reads/writes markdown files directly. Each file operation needs approval.

## Solution

1. Store context data in `.sup` files (SuperDB format)
2. Shell script (`mta-context.sh`) handles all file operations via `super` CLI
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
{ticket:"DEVOPS-1641",title:"Replace Oban scaler",created:"2026-01-27T16:32:00Z",ticket_url:"https://linear.app/...",branch:"devops-1641-...",worktree:"ds5"}
{ticket:"DEVOPS-1670",title:"CI multi-workflow experiment",created:"2026-01-29T09:00:00Z",ticket_url:"...",branch:"...",worktree:"ds9"}
```

### sessions.sup
Active/historical sessions linked to contexts.
```
{ticket:"DEVOPS-1641",session_id:"ds5/c342fbfe",joined_at:"2026-01-29T16:30:00Z",left_at:null}
{ticket:"DEVOPS-1641",session_id:"ds5/a779c24f",joined_at:"2026-01-29T15:30:00Z",left_at:null}
{ticket:"DEVOPS-1641",session_id:"ds8",joined_at:"2026-01-27T16:00:00Z",left_at:"2026-01-27T18:25:00Z",status:"handoff",note:"diagnosed EnvType tag issue"}
```

### decisions.sup
Decision log with timestamps.
```
{ticket:"DEVOPS-1641",ts:"2026-01-29T20:42:00Z",text:"QUEUE SCALING E2E VERIFIED"}
{ticket:"DEVOPS-1641",ts:"2026-01-28T22:45:00Z",text:"CRITICAL: Lambda SuperDB version must match local dev"}
```

### tasks.sup
Outstanding tasks (incomplete work for future sessions).
```
{ticket:"DEVOPS-1641",ts:"2026-01-29T21:00:00Z",text:"Add SSM SendCommand permission to dev profile",status:"pending"}
{ticket:"DEVOPS-1641",ts:"2026-01-29T21:00:00Z",text:"Fix JSON quote escaping in bin/ssm axon_eval",status:"pending"}
```

### blockers.sup
Active blockers (resolved ones can be marked).
```
{ticket:"DEVOPS-1706",ts:"2026-01-29T09:00:00Z",text:"Notion page requires auth",resolved:null}
{ticket:"DEVOPS-1641",ts:"2026-01-27T17:30:00Z",text:"Queue metrics not appearing",resolved:"2026-01-27T18:10:00Z"}
```

## Example Queries

```bash
# All active sessions (not yet departed)
super -c "from 'sessions.sup' | where left_at = null"

# Decisions for a ticket, sorted
super -c "from 'decisions.sup' | where ticket = 'DEVOPS-1641' | sort ts"

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
```

## Script Interface

```bash
mta-context.sh <command> [args]

# Context management
mta-context.sh create-context <ticket> <title> [--ticket-url=...] [--branch=...] [--worktree=...]
mta-context.sh list-contexts
mta-context.sh get-context <ticket>

# Session management
mta-context.sh join <ticket> <session-id>
mta-context.sh leave <ticket> <session-id> <status> [note]
mta-context.sh list-sessions [ticket]

# Decisions
mta-context.sh add-decision <ticket> <text>
mta-context.sh list-decisions <ticket>

# Tasks
mta-context.sh add-task <ticket> <text>
mta-context.sh complete-task <ticket> <task-text-pattern>
mta-context.sh list-tasks [ticket] [--pending]

# Blockers
mta-context.sh add-blocker <ticket> <text>
mta-context.sh resolve-blocker <ticket> <blocker-text-pattern>
mta-context.sh list-blockers [--unresolved]

# Status/reporting
mta-context.sh status [ticket]           # formatted status for one or all
mta-context.sh archive <ticket>          # move to archive
```

## Migration

1. Build script + schema
2. Migrate existing .md contexts to .sup files (one-time)
3. Update mta skills to use script
4. Test the flow
5. Delete old .md files

## Archive Strategy

Archived contexts move to `~/.claude/contexts/archive/` - same .sup format, just different location. Or add `archived_at` field to contexts.sup and filter on queries.
