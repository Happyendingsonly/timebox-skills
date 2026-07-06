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
> You are booting into <repo path> mid-stream. Read this file fully, then:
> boot per SESSION-PROTOCOL (bundle + spines + SESSION-HANDOFF.md latest section
> only), file your SESSION-LOCK, and continue at "Next actions" below. Do NOT
> re-scan the repo or re-derive prior work — canon + this file are the truth.

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
