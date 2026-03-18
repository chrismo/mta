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
  │   YOU    │   mta-engine debt PROJ-42
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
/mta:overview             # triage — what needs attention?
/mta:review               # guided walkthrough of unreviewed chunks
                          # (these call mta-engine debt and chunk commands under the hood)

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

## Topologies

Three ways I'll work with AI agents. Each has different cognitive debt risks,
though topology is only one factor there. I can go Serial and still hand-off
too much to Claude to-do without overseeing it. (C is Claude).

```
  Serial               Converge                Parallel
  ──────               ────────                ────────

   You                   You                     You
    │                   / │ \                   / │ \
    │                  /  │  \                 /  │  \
    C                 C   C   C               C   C   C
    │                  \  │  /                |   |   |
    │                   \ │ /                 |   |   |
 ┌─────┐               ┌──────┐            ┌───┐┌───┐┌───┐
 │task │               │ task │            │ t ││ t ││ t │
 └─────┘               └──────┘            └───┘└───┘└───┘
```

MTA is built for **Converge** and **Parallel** — the topologies where cognitive
debt accumulates because you can't watch everything at once. Serial doesn't need
it as much, but chunks still work there if you want a review trail.

## Paying Down Cognitive Debt

```
  Workers are coding...         You haven't looked at any of it yet.

  ┌─────────────────────────────────────────────────┐
  │  /mta:overview                                  │
  │                                                 │
  │  PROJ-42: 5 unreviewed chunks                   │
  │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   5%    │
  │  highest RISC: 9  ← start here                  │
  └─────────────────────────────────────────────────┘
       │
       ▼
  ┌─────────────────────────────────────────────────┐
  │  /mta:review                                    │
  │                                                 │
  │  Chunk 1/5: "New auth middleware" (RISC 9)      │
  │  ───────────────────────────────────            │
  │  Shows diff, explains intent, asks questions.   │
  │  You sign off → marked reviewed.                │
  └─────────────────────────────────────────────────┘
       │
       ▼  ... repeat ...
       │
       ▼
  ┌─────────────────────────────────────────────────┐
  │  /mta:overview                                  │
  │                                                 │
  │  PROJ-42: 2 unreviewed chunks                   │
  │  ████████████████████████░░░░░░░░░░░░░░  60%    │
  │  remaining are RISC 2-3 (low risk)              │
  └─────────────────────────────────────────────────┘
       │
       ▼  review or skip the low-RISC stuff
       │
       ▼
  ┌─────────────────────────────────────────────────┐
  │  /mta:overview                                  │
  │                                                 │
  │  PROJ-42: 0 unreviewed chunks                   │
  │  ██████████████████████████████████████ 100%    │
  │  cognitive debt: paid off                       │
  └─────────────────────────────────────────────────┘
```
