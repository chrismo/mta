---
name: mtm:premortem
description: Proactive risk briefing on unreviewed high-RISC chunks
allowed-tools: Bash
---

# Pre-mortem Risk Briefing

Surface what could go wrong in unreviewed high-RISC code before it bites you.

## Usage

```
/mtm:premortem [ticket] [--all]
```

By default, only shows chunks with RISC >= 7. Use `--all` to include all unreviewed chunks.

## What This Does

1. Get unreviewed chunks:
   ```bash
   mta-context.sh list-chunks <TICKET> --unreviewed
   ```
   If no ticket:
   ```bash
   mta-context.sh debt
   ```
   Pick the context with highest weighted debt.

2. Filter to high-RISC chunks (RISC >= 7) unless `--all` specified.

3. For each high-RISC chunk:

   a. Read the code change:
      ```bash
      git show <commit> -- <files>
      ```

   b. Analyze and present a risk profile:
      - **What it does**: One-sentence summary of the change
      - **What could go wrong**: Concrete failure modes, not theoretical concerns
      - **Key assumptions**: What must be true for this code to work correctly
      - **Blast radius**: If this breaks, what else breaks with it

   c. Group related chunks from the same commit together.

4. After presenting all risks, ask:
   ```
   Want to mark any of these as reviewed?
   Options:
   1. Mark all as reviewed (you understand the risks)
   2. Mark specific ones (list by number)
   3. None — I need to look at these more carefully
   ```

5. Mark selected chunks:
   ```bash
   mta-context.sh review-chunk <TICKET> "<summary>"
   ```

6. Show updated debt:
   ```bash
   mta-context.sh debt <TICKET>
   ```

## Output Format

```
## Pre-mortem: PROJ-1641

### 3 high-RISC chunks to review

**1. "retry backoff logic" (RISC: 8)**
Commit: a3f7e2b | Files: src/sync.sh, src/async.sh

- What it does: Adds exponential backoff retry for failed API calls
- What could go wrong:
  - If the API returns 429 during retry, this loops until MAX_RETRIES — but doesn't respect Retry-After headers
  - The backoff timer uses wall-clock time; under high load, jitter could cause retry storms
- Key assumptions: API errors are transient; MAX_RETRIES (3) is sufficient
- Blast radius: Both sync and async paths share this logic — a bug here affects all API calls

**2. "auth token refresh" (RISC: 9)**
Commit: b8c1d4e | Files: src/auth.sh

- What it does: Adds automatic token refresh when API returns 401
- What could go wrong:
  - If refresh itself returns 401, this creates an infinite refresh loop
  - Token refresh is not atomic — concurrent requests could race on the new token
- Key assumptions: Refresh endpoint is always available; token storage is thread-safe
- Blast radius: Every authenticated API call depends on this

**3. "config env override" (RISC: 7)**
Commit: c9d0e1f | Files: src/config.sh

- What it does: Allows env vars to override config file values
- What could go wrong:
  - Env var names are case-sensitive on Linux but not macOS — could behave differently across environments
  - No validation on env var values — malformed input passes through silently
- Key assumptions: Env vars are trusted input (reasonable for CLI tool)
- Blast radius: Any config value can be overridden, including security-sensitive ones

---

Mark as reviewed?
1. All three
2. Specific ones (enter numbers)
3. None
```

## Notes

- This is a briefing, NOT a quiz — present risks, don't ask questions
- Focus on concrete, plausible risks — not "what if the network is down" boilerplate
- Be specific: name the function, the line, the variable — not "there could be a bug"
- If the commit is no longer in local git history, analyze based on the summary and RISC reason
- Shorter is better — the human should be able to scan this in 2 minutes
