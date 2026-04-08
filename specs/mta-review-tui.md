# mta-review: Chunk-Oriented Code Review TUI

## Context

GitHub PR review is file-oriented, but understanding code is concept-oriented. MTA already models this with "chunks" — logical review units graded by RISC scores — but the current UX is Claude Code conversations. A dedicated TUI would be a genuinely better self-review experience: navigate by concept, prioritize by risk, quiz yourself before marking reviewed.

**Primary audience**: Author self-review (verify understanding of AI-generated or own code before requesting peer review).  
**Tech**: Go + Bubbletea, separate repo.  
**AI**: Shell out to `claude` CLI for quiz; TUI is the navigation shell, Claude is the brain.

---

## What makes this better than GitHub PR review

1. **Concept navigation**: Chunks have names like "retry backoff logic" — not just filenames
2. **RISC-prioritized**: Most dangerous changes shown first, not alphabetical by file
3. **Meaningful progress**: RISC-weighted completion — reviewing a RISC-9 auth chunk counts more than a RISC-2 config tweak
4. **Active comprehension**: Quiz mode forces recall before marking reviewed, not passive scanning
5. **Single-player optimized**: Built for author self-review, not reviewer-author conversations

---

## Screen Flow

```
                    ┌───────────────────────┐
                    │     DASHBOARD         │
  launch ──────────>│  chunk list by RISC   │
                    │  debt summary sidebar │
                    │  RISC-weighted progress│
                    └───────┬───────────────┘
                            │ Enter
                            v
                    ┌───────────────────────┐
                    │     DETAIL            │<── Esc
                    │  scrollable diff      │
                    │  chunk metadata/RISC  │
                    └───────┬───────────────┘
                            │ q
                            v
                    ┌───────────────────────┐
                    │     QUIZ              │<── Esc
                    │  question + diff ref  │
                    │  answer textarea      │
                    │  Claude evaluation    │
                    └───────────────────────┘
```

**Dashboard**: Chunk list (sorted RISC desc) on left, debt summary on right. Progress bar is RISC-weighted (`sum(reviewed risc) / sum(all risc)`), not just count-based. Filter, sort, toggle reviewed visibility.

**Detail**: Scrollable syntax-highlighted diff viewport. Chunk metadata header (summary, RISC breakdown, files, commit SHAs). Navigate between chunks with `n/p`.

**Quiz**: Split-pane — diff reference (toggleable visible/hidden for closed-book mode) alongside a Q&A conversation with Claude. Claude asks questions scaled to RISC level, evaluates answers, user marks reviewed when satisfied.

---

## Architecture

```
mta-review/
  cmd/mta-review/main.go          # entry, arg parsing, tea.NewProgram
  internal/
    engine/
      engine.go                    # shells out to mta-engine CLI, parses JSON
      types.go                     # Chunk, DebtSummary structs
    git/
      git.go                       # branch detection
    claude/
      claude.go                    # exec `claude --print` for quiz
      prompt.go                    # system/user prompt templates
    tui/
      app.go                       # root model, screen dispatch
      theme.go                     # lipgloss styles, RISC color palette
      keys.go                      # keybindings
      dashboard/model.go
      detail/model.go
      quiz/model.go
      components/
        diffview.go                # diff syntax coloring (lipgloss, no extra lib)
        chunkcard.go               # list item renderer
        riscbadge.go               # colored RISC score badge
        statusbar.go               # contextual key hints
```

### Data flow

- **Chunks**: `mta-engine list-chunks <ticket> --format=json` -> cached in memory on startup
- **Diffs**: `mta-engine chunk-diff <ticket> <pattern>` -> cached lazily per chunk
- **Review**: `mta-engine review-chunk <ticket> <pattern>` -> update local cache, recompute debt
- **Debt**: Computed locally from cached chunks (sum unreviewed RISC, count high-RISC)
- **Quiz**: `claude --print --system-prompt <quiz-prompt> <chunk-context>` -> parse response

Ticket auto-detected from CLI arg, branch name pattern, or interactive picker via `mta-engine list-contexts`.

### Claude integration for quiz

Shell out to `claude --print` with:
- `--system-prompt`: Quiz partner instructions (question depth scaled to RISC, ground in concrete behavior, never recommend marking reviewed)
- Positional prompt: Chunk summary, RISC breakdown, RISC reason, diff
- MVP: Batch mode (wait for full response). v0.2: `--output-format=stream-json` for streaming tokens.
- Model: Default `sonnet` for speed. Configurable via `MTA_REVIEW_MODEL`.

---

## Key interactions

| Key | Dashboard | Detail | Quiz |
|-----|-----------|--------|------|
| `j/k` | navigate list | scroll diff | scroll conversation |
| `Enter` | open chunk | — | submit answer |
| `q` | quiz highlighted chunk | quiz this chunk | — |
| `r` | mark reviewed | mark reviewed | mark reviewed + exit |
| `n/p` | — | next/prev chunk | — |
| `d` | toggle reviewed visibility | — | toggle diff panel |
| `Esc` | quit | back to dashboard | back to detail |
| `/` | filter chunks | — | — |
| `?` | help overlay | help overlay | help overlay |

---

## Design decisions

- Quiz transcripts are ephemeral — no persistence. Quiz is a means to marking reviewed, not an artifact.
- Diff display is chunk-scoped only (files/lines the chunk claims). No expand-to-full-commit. Keeps focus tight.

---

## MVP scope (v0.1)

1. Dashboard with chunk list, RISC badges, debt summary, progress bar
2. Detail screen with scrollable diff, metadata header, next/prev navigation
3. Mark reviewed (`r` key, calls `mta-engine review-chunk`)
4. Ticket auto-detection from CLI arg or branch name
5. Basic quiz: batch `claude --print`, question/answer/evaluation rounds, textarea input
6. lipgloss theme with RISC color coding, diff coloring

**Explicitly deferred**: Streaming quiz, structured JSON quiz output, quiz history, split-pane quiz, premortem mode, multi-ticket, configurable keybindings, coverage gap visualization.

---

## Dependencies

```
github.com/charmbracelet/bubbletea       # TUI framework
github.com/charmbracelet/bubbles         # list, viewport, textarea, spinner, key
github.com/charmbracelet/lipgloss        # styling
github.com/charmbracelet/glamour         # markdown rendering for quiz
```

External: `mta-engine` in PATH, `git`, `claude` CLI.
