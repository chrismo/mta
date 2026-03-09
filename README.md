# MTA - Multi-Ticket Assistance

Context management for coordinated multi-Claude work sessions using [SuperDB](https://superdb.org/).

## Problem

When multiple Claude sessions work on the same ticket, they need shared context:
- What decisions were made?
- Who's currently working on it?
- What blockers exist?
- What tasks remain?

## Solution

Store coordination data in `.sup` files (SuperDB format) with a CLI for all operations:

```bash
mta-context.sh create-context PROJ-1641 "Upgrade auth service"
mta-context.sh join PROJ-1641 ds5/session-abc
mta-context.sh add-decision PROJ-1641 "Using bc for ceiling calc"
mta-context.sh add-task PROJ-1641 "Add retry logic"
mta-context.sh status PROJ-1641
mta-context.sh leave PROJ-1641 ds5/session-abc done "implemented scaling"
```

## Why SuperDB?

- Relational model with multiple files (contexts, sessions, decisions, tasks, blockers)
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

### Install mta-context.sh

```bash
# Clone and add to PATH
git clone https://github.com/chrismo/mta.git
export PATH="$PATH:$(pwd)/mta/bin"

# Or copy to your bin
cp mta/bin/mta-context.sh ~/.local/bin/
```

## Usage

### Context Management

```bash
mta-context.sh create-context <ticket> <title> [--ticket-url=...] [--branch=...] [--worktree=...]
mta-context.sh list-contexts [--format=json|csv|table]
mta-context.sh get-context <ticket>
mta-context.sh archive <ticket>
```

### Session Management

```bash
mta-context.sh join <ticket> <session-id>
mta-context.sh leave <ticket> <session-id> <status> [note]
mta-context.sh list-sessions [ticket] [--format=json|csv|table]
```

### Decisions, Tasks, Blockers

```bash
mta-context.sh add-decision <ticket> <text>
mta-context.sh list-decisions <ticket> [--format=json|csv|table]

mta-context.sh add-task <ticket> <text>
mta-context.sh complete-task <ticket> <pattern>
mta-context.sh list-tasks [ticket] [--pending] [--format=json|csv|table]

mta-context.sh add-blocker <ticket> <text>
mta-context.sh resolve-blocker <ticket> <pattern>
mta-context.sh list-blockers [--unresolved] [--format=json|csv|table]
```

### Chunks (Cognitive Debt)

Track what the human has and hasn't reviewed. Each commit is broken into RISC-graded chunks.

```bash
# Legacy mode (combined score):
mta-context.sh add-chunk <ticket> <commit> <summary> <risc> [--files=...] [--lines=...] [--risc-reason=...] [--branch=...]

# Component mode (per-category scores, risc auto-computed as min(sum, 10)):
mta-context.sh add-chunk <ticket> <commit> <summary> 1 \
  --reach=N --irrev=N --subtle=N --conseq=N [--files=...] [--lines=...] [--risc-reason=...] [--branch=...]

# Branch is auto-detected from git if --branch not provided

mta-context.sh list-chunks <ticket> [--unreviewed] [--branch=...] [--format=json|csv|commits|table]
mta-context.sh chunk-diff <ticket> <summary-pattern>    # Show git diff for a chunk's commit(s)
mta-context.sh review-chunk <ticket> <summary-pattern>

# update-chunk supports both --risc=N (legacy) and component flags:
mta-context.sh update-chunk <ticket> <summary-pattern> [--risc=N] [--summary=...] [--files=...] [--lines=...] [--risc-reason=...] [--branch=...]
mta-context.sh update-chunk <ticket> <summary-pattern> [--reach=N] [--irrev=N] [--subtle=N] [--conseq=N] [--summary=...]

mta-context.sh delete-chunk <ticket> <summary-pattern>
mta-context.sh debt [ticket] [--branch=...]    # Show cognitive debt summary
```

RISC (1-10) = **R**each, **I**rreversibility, **S**ubtlety, **C**onsequence. Higher = needs more human attention.
Component mode stores individual scores and computes `risc = min(R + I + S + C, 10)`.

### Status

```bash
mta-context.sh status [ticket]  # Full overview
```

## Data Storage

Data is stored in `~/.claude/contexts/` as `.sup` files:

```
~/.claude/contexts/
├── contexts.sup    # Parent records for each ticket
├── sessions.sup    # Active/historical sessions
├── decisions.sup   # Decision log with timestamps
├── tasks.sup       # Outstanding tasks
├── blockers.sup    # Active blockers
└── chunks.sup      # RISC-graded commit chunks (cognitive debt)
```

Override with `MTA_CONTEXTS_DIR` environment variable.

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
# Check mta-context.sh is available
which mta-context.sh

# Check super CLI is installed
super --version
```

### Transition from brain repo

If you previously used MTA/MTM skills from the brain repo (`ai-agents/claude/skills/mta/` and `ai-agents/claude/skills/mtm/`), remove those skill sources to avoid conflicts. Independent skills like `plan` and `review` stay in the brain repo. The `yah` script has been moved here as `work-context`.

## Claude Code Skills

### MTA (Worker Skills)
- `/mta:join` - Join a shared context
- `/mta:read` - Read current context state
- `/mta:update` - Record decisions and tasks
- `/mta:leave` - Deregister from context
- `/mta:dupe` - Spawn a duplicate worker on the same ticket
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

## Running Tests

```bash
# Install bats-core
brew install bats-core  # macOS
apt install bats        # Linux

# Run tests
cd test
bats mta-context.bats
```

## Schema

See [skills/sup-refactor.md](skills/sup-refactor.md) for the full schema specification.

## License

MIT
