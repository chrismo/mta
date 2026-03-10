# MTA Quickstart

## The Loop

```
  YOU (human)                        CLAUDE SESSIONS
  ───────────                        ───────────────

  "work on PROJ-42"
       │
       ▼
  ┌──────────┐    /mtm:slot
  │ Manager  │──────────────────────▶ spawns Worker A in worktree
  │ (MTM)    │    /mtm:slot
  └──────────┘──────────────────────▶ spawns Worker B in worktree

                                          ┌────────────┐
                    /mta:join             │ Worker A   │
                 ◀────────────────────────│ (auth)     │
                   (creates context       │            │
                    if it doesn't exist)  │ commits... │
                    /mta:update           │            │
                 ◀────────────────────────│ logs chunks│
                    /mta:leave            │            │
                 ◀────────────────────────└────────────┘

              ┌──────────────────┐        ┌────────────┐
              │  shared context  │◀───────│ Worker B   │
              │  ─────────────── │        │ (tests)    │
              │  decisions       │        │            │
              │  tasks           │        │ reads A's  │
              │  blockers        │        │ decisions  │
              │  chunks          │        └────────────┘
              │                  │
              │  ~/.claude/      │
              │  contexts/*.sup  │
              │  (JSON files)    │
              └──────────────────┘

  LATER...
       │
       ▼
  ┌──────────┐
  │   YOU    │   mta-context.sh debt PROJ-42
  │          │   ───────────────────────────▶  "3 unreviewed chunks,
  │  review  │                                  highest RISC: 8"
  │  time    │   /mta:review
  │          │   ───────────────────────────▶  walks you through
  └──────────┘                                  chunk by chunk
```

## Typical Day

```bash
# Morning — what's going on?
/mtm:start-day

# Spin up workers
/mtm:slot PROJ-42        # copies a claude-slot command
                          # paste into terminal → new Ghostty tab + worktree + Claude

# Mid-day check-in
/mtm:update

# Review what they built
mta-context.sh debt       # cognitive debt across all tickets
/mta:review               # guided walkthrough of unreviewed chunks

# End of day
/mtm:eod
```

## Key Concept: RISC

Every chunk of AI-generated code gets a RISC score (1-10):

|                     | Low (1-3)       | Medium (4-6)   | High (7-10)              |
|---------------------|-----------------|----------------|--------------------------|
| **R**each           | Helper function | Shared module  | Core architecture        |
| **I**rreversibility | Easy to revert  | Schema change  | Data migration           |
| **S**ubtlety        | Obvious change  | Some nuance    | Non-obvious side effects |
| **C**onsequence     | Cosmetic        | Feature impact | Security / data loss     |

High RISC = review this first. Low RISC = glance at it later (or don't).
