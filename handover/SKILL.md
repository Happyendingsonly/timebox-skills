---
name: handover
description: End-of-context handover — close the session out cleanly (TimeBox reconciled, repo handoff appended, session lock released) and write a compact BOOT file the next session/account can start from at near-zero context cost. Use when switching Claude accounts mid-work, when usage/context runs low, or any time the user says "handover", "hand off this session", or "prep the next window".
---

# /handover — close this window, boot the next one cheap

For the account-swap / low-context moment: one command that (a) makes the world
match reality before this window dies, and (b) leaves a **boot prompt file** so the
next session — possibly on a different Claude account with zero shared memory —
starts working in one paste instead of re-deriving everything.

Uses `<timebox-skill-dir>/scripts/tb.sh` for all TimeBox calls (key chain +
SPA-fallthrough guard; lanes from `~/.timebox/config.json`).

## When to trigger (don't wait to be asked)

- The session-limit / out-of-credits banner appears → **EMERGENCY PATH below,
  immediately**. Retrying prompts against the wall wastes the last working turns
  (one week's transcripts show ~40 messages burned this way, and two sessions
  that died with no handover at all).
- The conversation has auto-compacted 2-3+ times, or the topic has pivoted to a
  different project → offer a handover; one thread once ran 5 days / 30
  compactions across 4 projects and features had to be re-requested after each
  compaction.
- Context/usage is visibly low and there's a natural seam → offer it.

## EMERGENCY PATH (≤2 minutes, when credits/limit are dying NOW)

Skip the full reconcile. In order, stopping wherever the window dies:
1. APPEND 3 lines to `SESSION-HANDOFF.md`: what shipped (SHA if pushed), what's
   mid-stream, the single next action. Commit + push.
2. Release the session lock: `tb.sh unlock <lane-uuid> <lock-task-uuid>`.
3. `tb.sh POST /brain-dumps '{"text":"EMERGENCY handover <repo>: <the same 3 lines>","source":"agent"}'`
   — the org bus survives even if the file never lands.
Anything not done goes at the TOP of the next session's list, flagged as
un-reconciled.

## Phase 1 — close out (delegate to /update logic, don't duplicate it)

Run the full `/update` reconcile pass on the repo(s) touched this session:

1. `git fetch origin`; sync if behind. Note the SHA — every claim below cites it.
2. Shipped → matching board task done with real verbs
   (`PATCH /project-tasks/<id> '{"done":true,"status":"done"}'`) + re-read verify.
3. Unfinished → stays open, `BLOCKED: <reason>` prefix if stuck on something.
4. Append the session section to the repo's `SESSION-HANDOFF.md` (append-only,
   timestamped). Commit + push per repo convention. Never force-push.
5. Complete this session's `SESSION-LOCK: <repo>` task (the next session files
   its own). If uncommitted work can't be pushed, say so loudly in the boot file.
6. Post a close-out summary to `POST /brain-dumps` (the org bus survives the
   window even if the local file is never read).

## Phase 2 — write the BOOT file

Write `NEXT-SESSION.md` **at the repo root of the primary repo worked on**
(overwrite freely — unlike SESSION-HANDOFF.md this file is ephemeral, owned by
the outgoing session, and stale the moment it's consumed). Contents, in order:

```markdown
# NEXT-SESSION — <repo> (<UTC timestamp>, written by /handover)

## Paste-me boot prompt
> START IN: <absolute repo path> (cd there BEFORE launching the session).
> Window label: <repo/topic — one or two words, so parallel terminals don't
> double-pick this baton>.
> You are booting into <repo> mid-stream. Read this file fully, then:
> boot per SESSION-PROTOCOL (bundle + spines + SESSION-HANDOFF.md latest section
> only), file your SESSION-LOCK (`tb.sh lock …`), use tb.sh for ALL TimeBox
> calls — never raw curl — and continue at "Next actions" below. Do NOT re-scan
> the repo or re-derive prior work — canon + this file are the truth.

## State at handover
- SHA: <origin/main sha> (pushed: yes/no — if no, WHAT is stranded where)
- Deployed: <live/verified state, one line>
- Board: <ids of tasks closed / opened / blocked this session>
- Locks: mine <id> released; other active sessions: <id + what they're doing, or "none">

## In flight (the part context dies with)
- <exactly what was mid-stream: the decision half-made, the file half-edited,
  the hypothesis being tested — the stuff NOT in any handoff yet>

## Next actions (ordered, concrete)
1. <smallest resumable step, with file:line / task id / command>
2. …

## Traps for the next session
- <session-specific gotchas learned this window that aren't canon yet>
```

Keep it under ~80 lines. It supplements — never replaces — SESSION-HANDOFF.md:
durable narrative goes in the handoff; *resumption state* goes here.

## Phase 3 — hand the baton

1. Commit `NEXT-SESSION.md` with the close-out (so the next account's clone has
   it after `git pull`).
2. Print the paste-me boot prompt as the LAST thing in the reply, in a fenced
   block, so the user can copy it straight into the new session. Include the
   absolute repo path in it.
3. Remind: new session should be started IN the repo directory; `/timebox` covers
   key setup if the new account's machine/session lacks it.

## Guardrails

- Phase 1 verification rules are the /update rules — server-side re-read, SHA-cited.
- If nothing shipped (pure research session), Phase 1 shrinks to: lock release +
  brain-dump of findings; the boot file carries the research state.
- Never put secrets/keys in NEXT-SESSION.md — it gets committed.
- If another session's SESSION-LOCK is active on the repo, note it in the boot
  file's Locks line so the next window doesn't step on it.
