# MTA - Multi-Tasking Agents

> **Warning:** You're entering a vibe-heavy zone. It's a mess. It works for *my* brain so far. If it works for yours, you might need meds.

Ticket-centric tooling for AI-assisted development: **multi-session coordination** and **cognitive debt tracking**. Built on [SuperDB](https://superdb.org/).

**[Quickstart](quickstart.md)** — TL;DR with ASCII art showing how the pieces fit together.

## Two Problems, One Data Model

### Coordination: Multiple Claudes, one ticket

When multiple Claude sessions work on the same ticket, they need shared context — who's working on what, what decisions were made, what's blocked, what remains.

```bash
mta-engine create-context PROJ-1641 "Upgrade auth service"
mta-engine join PROJ-1641 ds5/session-abc
mta-engine add-decision PROJ-1641 "Using bc for ceiling calc"
mta-engine add-task PROJ-1641 "Add retry logic"
mta-engine leave PROJ-1641 ds5/session-abc done "implemented scaling"
```

### Cognitive Debt: What has the human actually reviewed?

AI agents produce code fast. The human can't review it all at once. Chunks break each commit into RISC-graded pieces so the human can triage what needs attention and track what they've reviewed.

```bash
mta-engine add-chunk PROJ-1641 abc123 "New retry logic" 7
mta-engine list-chunks PROJ-1641 --unreviewed
mta-engine debt PROJ-1641
mta-engine review-chunk PROJ-1641 "retry"
```

### Why one repo?

Both concerns are keyed by ticket and share the same SuperDB data store. Coordination tracks what the agents are doing; cognitive debt tracks what the human still needs to understand. Same ticket, two sides.

## Why SuperDB?

- Relational model with multiple files (contexts, sessions, decisions, tasks, blockers, chunks)
- SQL-like queries for joins and aggregations
- Appending records is just appending lines
- Query across all tickets: "show me all unresolved blockers"

## Installation

### Prerequisites

- [SuperDB](https://superdb.org/) (`super` CLI)
- Bash 3.2

```bash
# macOS
brew install brimdata/tap/super

# Or via asdf
asdf plugin add superdb https://github.com/chrismo/asdf-superdb.git
asdf install superdb latest
asdf global superdb latest
```

### Install mta-engine

```bash
# Clone and add to PATH
git clone https://github.com/chrismo/mta.git
export PATH="$PATH:$(pwd)/mta/bin"

# Or copy to your bin
cp mta/bin/mta-engine ~/.local/bin/
```

## Usage

### Context Management

```bash
mta-engine create-context <ticket> <title> [--ticket-url=...] [--branch=...] [--worktree=...]
mta-engine list-contexts [--format=json|csv|table]
mta-engine get-context <ticket>
```

### Session Management

```bash
mta-engine session-id                          # Auto-detect session identifier
mta-engine join <ticket> [session-id]           # Session ID auto-detected if omitted
mta-engine leave <ticket> <session-id> <status> [note]
mta-engine list-sessions [ticket] [--format=json|csv|table]
```

### Decisions, Tasks, Blockers

```bash
mta-engine add-decision <ticket> <text>
mta-engine list-decisions <ticket> [--format=json|csv|table]

mta-engine add-task <ticket> <text>
mta-engine complete-task <ticket> <pattern>
mta-engine list-tasks [ticket] [--pending] [--format=json|csv|table]

mta-engine add-blocker <ticket> <text>
mta-engine resolve-blocker <ticket> <pattern>
mta-engine list-blockers [--unresolved] [--format=json|csv|table]
```

### Chunks (Cognitive Debt)

Track what the human has and hasn't reviewed. Each commit is broken into RISC-graded chunks.

```bash
# Legacy mode (combined score):
mta-engine add-chunk <ticket> <commit> <summary> <risc> [--files=...] [--lines=...] [--risc-reason=...] [--branch=...]

# Component mode (per-category scores, risc auto-computed as min(sum, 10)):
mta-engine add-chunk <ticket> <commit> <summary> 1 \
  --reach=N --irrev=N --subtle=N --conseq=N [--files=...] [--lines=...] [--risc-reason=...] [--branch=...]

# Branch is auto-detected from git if --branch not provided

mta-engine list-chunks <ticket> [--unreviewed] [--branch=...] [--format=json|csv|commits|table]
mta-engine chunk-diff <ticket> <summary-pattern>    # Show git diff for a chunk's commit(s)
mta-engine review-chunk <ticket> <summary-pattern>

# update-chunk supports both --risc=N (legacy) and component flags:
mta-engine update-chunk <ticket> <summary-pattern> [--risc=N] [--summary=...] [--files=...] [--lines=...] [--risc-reason=...] [--branch=...]
mta-engine update-chunk <ticket> <summary-pattern> [--reach=N] [--irrev=N] [--subtle=N] [--conseq=N] [--summary=...]

mta-engine delete-chunk <ticket> <summary-pattern>
mta-engine debt [ticket] [--branch=...]    # Show cognitive debt summary
```

RISC (1-10) = **R**each, **I**rreversibility, **S**ubtlety, **C**onsequence. Higher = needs more human attention.
Component mode stores individual scores and computes `risc = min(R + I + S + C, 10)`.

### Journal

Cross-cutting notes for the manager — not tied to any single ticket.

```bash
mta-engine journal "Incident response consumed the day"
mta-engine journal                          # Show last 10 entries
mta-engine journal --today                  # Today's entries only
mta-engine journal --date=YYYY-MM-DD        # Entries for a specific date
mta-engine journal --list 5                 # Last N entries
mta-engine journal --list --format=json     # Any query supports --format
mta-engine journal --delete <timestamp>     # Delete entry by timestamp
```

### MTM Tasks

Manager-level checklist — cross-cutting tasks not tied to any ticket.

```bash
mta-engine mtm-add-task "Sarah pinged about deploy issue"
mta-engine mtm-complete-task "deploy issue"
mta-engine mtm-list-tasks --pending
```

### Priority

Free-form priority text on context records.

```bash
mta-engine set-priority <ticket> "urgent - stakeholder deadline Friday"
mta-engine set-priority <ticket> --clear
```

### Update (Shorthand)

```bash
mta-engine update <ticket> --decision "text"  # alias for add-decision
mta-engine update <ticket> --task "text"      # alias for add-task
mta-engine update <ticket> --blocker "text"   # alias for add-blocker
```

### Status & Archive

```bash
mta-engine status [ticket]  # Full overview
mta-engine archive <ticket>
mta-engine unarchive <ticket>
mta-engine rename-context <old-ticket> <new-ticket>
```

### Migration

```bash
mta-engine import <context.md>  # Import old markdown context into SuperDB
```

## Data Storage

Data is stored in `~/.claude/contexts/` as `.sup` files (SuperDB/ZSON format). Override with `MTA_CONTEXTS_DIR`.

### contexts.sup
The parent record for each coordination effort.
```
{ticket:"PROJ-1641",title:"Upgrade auth service",created:"2026-01-27T16:32:00Z",archived_at:null,ticket_url:"https://tracker.example.com/...",branch:"proj-101-...",worktree:"wt1",priority:"high"}
```

### sessions.sup
Active/historical sessions linked to contexts.
```
{ticket:"PROJ-1641",session_id:"ds5/c342fbfe",joined_at:"2026-01-29T16:30:00Z",left_at:null}
{ticket:"PROJ-1641",session_id:"ds8",joined_at:"2026-01-27T16:00:00Z",left_at:"2026-01-27T18:25:00Z",status:"handoff",note:"diagnosed EnvType tag issue"}
```

### decisions.sup
Decision log with timestamps.
```
{ticket:"PROJ-1641",ts:"2026-01-29T20:42:00Z",text:"AUTH MIGRATION E2E VERIFIED"}
```

### tasks.sup
Outstanding tasks (incomplete work for future sessions).
```
{ticket:"PROJ-1641",ts:"2026-01-29T21:00:00Z",text:"Add deploy permission to dev profile",status:"pending"}
```

### blockers.sup
Active blockers (resolved ones can be marked).
```
{ticket:"PROJ-1706",ts:"2026-01-29T09:00:00Z",text:"Wiki page requires auth",resolved:null}
{ticket:"PROJ-1641",ts:"2026-01-27T17:30:00Z",text:"Dashboard metrics not appearing",resolved:"2026-01-27T18:10:00Z"}
```

### chunks.sup
RISC-graded commit chunks for cognitive debt tracking.
```
{ticket:"PROJ-1641",commit:"abc123",summary:"Add retry logic",risc:7,ts:"2026-01-29T21:10:00Z",reviewed_at:null}
```

### journal.sup
Manager journal — freeform timestamped notes not tied to any ticket.
```
{ts:"2026-03-19T14:00:00Z",text:"Incident response consumed the day"}
```

### mtm-tasks.sup
Manager-level tasks — cross-cutting checklist not tied to any ticket.
```
{ts:"2026-03-31T09:00:00Z",text:"Review approved PRs",status:"pending"}
```

### Example Queries

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
```

## Getting Started

### 1. Add `bin/` to PATH

```bash
# In .zshrc or .bashrc
export PATH="$HOME/modev/mta/bin:$PATH"
```

### 2. Add skills to Claude Code

Add the MTA `skills/` directory as a skills source in your Claude Code settings. This registers all `/mta:*` and `/mtm:*` slash commands.

### 3. Verify

```bash
# Check mta-engine is available
which mta-engine

# Check super CLI is installed
super --version
```

## Claude Code Skills

### MTA — Worker Skills

**Coordination:**
- `/mta:join` - Join a shared context
- `/mta:read` - Read current context state
- `/mta:update` - Record decisions and tasks
- `/mta:leave` - Deregister from context
- `/mta:update-and-leave` - Record updates and deregister in one step
- `/mta:dupe` - Spawn a duplicate worker on the same ticket

**Cognitive Debt:**
- `/mta:chunk` - Sync recorded chunks with branch state
- `/mta:review` - Chunk-by-chunk code review walkthrough
- `/mta:overview` - Quick cognitive debt triage
- `/mta:quiz` - Interactive comprehension check on high-RISC chunks
- `/mta:premortem` - Proactive risk briefing on unreviewed high-RISC code

### MTM (Manager Skills)
- `/mtm:update` - Quick mid-day status check
- `/mtm:start-day` - Full morning overview
- `/mtm:eod` - End of day wrap-up
- `/mtm:new-context` - Create a new shared context
- `/mtm:archive` - Archive a completed context
- `/mtm:slot` - Generate a claude-slot command for a ticket
- `/mtm:journal` - View and add cross-cutting journal entries

### Other Tools
- `/work-context` - Analyze current work context and recommend top priorities

### External Dependencies
- `claude-slot` - Opens a Ghostty tab in a worktree and starts Claude. Used by `/mtm:slot` and `/mta:dupe`. Lives in [claude-rig](https://github.com/chrismo/claude-rig).

## Running Tests

```bash
# Install bats-core and helper libraries
brew install bats-core                    # macOS
brew tap kaos/shell && brew install bats-assert  # installs bats-assert + bats-support

# Linux: see https://github.com/bats-core/bats-core#installation
#   and https://github.com/ztombol/bats-docs#installation

# Run tests
bats --jobs 8 test/mta-engine.bats test/mta.bats
bats --jobs 8 test/work-context.bats
```

## License

MIT
