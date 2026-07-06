---
name: boot
description: One-command session start — fetch the repo, pull the TimeBox context bundle + spines, read the latest handoff + boot baton, handle the session lock, and report where you left off with ordered next actions. Use at the start of any working session, when the user says "boot", "boot up", "start the session", or pastes a NEXT-SESSION boot prompt.
---

# /boot — start the session in one command

Replaces the 5 manual boot steps every window used to do by hand. Boot cost
should stay near zero: bundle + spine + the LATEST handoff section + the baton
file — never a repo re-scan.

Uses `<timebox-skill-dir>/scripts/tb.sh` for ALL TimeBox calls (never raw curl).
Lane map: your org's lane-table doc (if it keeps one in its hub repo) or
`~/.timebox/config.json` `lanes`.

## Steps, in order

0. **Right directory?** cwd must be the org hub repo or the subject repo —
   never home or a random folder. Wrong place → stop and tell the user where to
   restart (one line, not a lecture).
1. **Fetch first.** `git fetch origin` → if `origin/main` is ahead,
   fast-forward BEFORE reading anything (never boot from a stale clone). Note
   the SHA — claims this session records cite it.
2. **TimeBox pulse:** `tb.sh GET /context/bundle` (readiness, priorities,
   deadlines, unsorted dumps) and `tb.sh GET /spines` (this repo's spine).
3. **Read the baton, then the handoff:** `NEXT-SESSION.md` at the repo root if
   present (it's the outgoing session's resumption state — highest priority,
   consume it), then the repo `SESSION-HANDOFF.md` **latest section only**.
   Do NOT re-read whole repos or re-derive what canon records.
4. **Session lock:** pull the subject lane and look for an open
   `SESSION-LOCK: <repo>`:
   - Open + recent (activity <3h) → **reporter mode**: announce it loudly
     (whose, since when); read/analyze only, no writes to code, board, or handoff.
   - Idle 3h+ → abandoned: take over by APPENDING a note to its description.
   - None → `tb.sh lock <lane-uuid> <repo-name> "<one-line scope>"`.
5. **Report — one screen max:**
   - SHA + sync state (`origin/main abc1234, in sync`)
   - Where the last session left off (from baton/handoff, 2-3 lines)
   - 🔥 deadlines + 🚫 blocked items from the bundle, if any
   - **Next actions, ordered** (from the baton, or proposed from the handoff)
   - Lock state (mine filed <id> / reporter mode because <id>)
   - If unsorted brain-dumps > 5: one line suggesting `/braindump`.

## Guardrails

- Bundle 403 → key-scope problem; diagnose per the /timebox troubleshooting
  section before anything else.
- No baton and no handoff? Say so and ask for the job — don't invent one.
- This command reads and files the lock; it does NOT start building anything.
  End with the report; the user picks the next action.
