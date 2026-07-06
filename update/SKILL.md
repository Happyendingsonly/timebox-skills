---
name: update
description: Reconcile TimeBox with reality — mark shipped work done on the board (with server-side verification), file new tasks/subtasks under the right lane, and update the repo handoff. Use after shipping work, at session end, or whenever the user wants to make sure TimeBox matches what actually happened.
---

# /update — make TimeBox match reality

The manual "trust but verify" pass. Agent sessions are supposed to keep the board in
sync automatically; this command **proves** it, and fixes whatever drifted.

Uses the `timebox` skill's helper for all API calls:
`<timebox-skill-dir>/scripts/tb.sh` (loads the user's key from `~/.timebox/config.json`;
see `/timebox` for setup). Load the user's lane map from that config.

Run this **after each shipped unit of work**, not only at session end — a 17-hour
session once shipped continuously with zero board writes, and the close-out
reconcile is where drift (and lost work) hides.

## Steps

0. **Check for a foreign session lock.** Pull the subject lane and look for an
   open `SESSION-LOCK: <repo>` that is not yours. Open + recent → you are a
   reporter on that repo: report what you found, but make no board writes for it.

1. **Gather what actually happened — at the current SHA.**
   - `git fetch origin` first; if `origin/main` is ahead of HEAD, sync before
     reading anything (never reconcile from a stale clone).
   - `git log --oneline` since the last handoff entry (or last /update) in this repo.
   - The current session's work, if any.
   - Ask the user "anything shipped outside this repo?" if context is thin.

2. **Pull the board state** for each lane in the user's config:
   ```bash
   tb.sh GET "/project-tasks?project_id=<lane-uuid>&limit=200"
   ```
   (Always `limit=200` — the default is 50 and silently truncates busy boards.)

3. **Match shipped work → existing tasks.** Match by subject lane + title/meaning,
   not exact strings. Rules:
   - A task exists for the work → complete THAT task. Never duplicate.
   - No matching task → create one under the correct SUBJECT lane
     (`POST /projects/<lane-uuid>/tasks`), then complete it. Filing is by subject:
     the project the work is ABOUT, not the session that did it.

4. **Complete with the real verbs — table matters:**
   - Board tasks: `tb.sh PATCH /project-tasks/<id> '{"done":true,"status":"done"}'`
   - Brain-dump/loose tasks: `tb.sh POST /tasks/<id>/complete`

5. **Verify server-side, at a SHA.** Re-read the task/board and confirm
   `status: done` / `done: true` in the response — a 200 alone is NOT proof. Any
   "verified" claim you record must cite the commit SHA it ran at, and that SHA
   must equal `origin/main` at that moment; if origin moved mid-session, re-verify
   at the new SHA first. Report each verification with its SHA.

6. **Partial or blocked work stays open** with `BLOCKED: <reason>` prefixed to the
   top of the description (PATCH the description; there is no blocked_reason field).
   **Deployed ≠ verified:** if proving the fix needs an auth surface / device /
   account this session doesn't have, the task stays OPEN with
   `DEPLOYED-UNVERIFIED: <what's deployed, what proof is missing>` at the top —
   never closed on unproven green. (A "verified" dup-key fix closed this way once
   regressed the next day.)

7. **File the new stuff.** New tasks, projects, subtasks the user mentions:
   - Board task: `POST /projects/<lane-uuid>/tasks` `{"title", "description"?, "priority"?, "due_date"?}`
   - Subtask: `POST /tasks/<taskId>/subtasks`
   - Deadlines in UTC `Z` format only.
   - Dedup first: check the lane's existing open tasks before creating.

8. **Update the repo.** If this repo keeps a `SESSION-HANDOFF.md`, APPEND the
   latest-state section (handoffs are append-only with timestamps — never rewrite
   an earlier session's record). Commit per the repo's conventions if the user
   wants; **never force-push shared branches** — a rejected push means integrate,
   not force.
9. **Close your session lock** (if this session opened one):
   `tb.sh unlock <lane-uuid> <lock-task-uuid>` — completes with the real verbs
   and re-read verifies in one call. If you keep working after closing the lock,
   file a fresh lock for the new stretch.

10. **Report** a compact table: task → action taken (completed✓verified / created /
    blocked / skipped-duplicate) → id, citing the verification SHA.

## Guardrails

- Never mark a task done without server-side verification (step 5).
- **Completion 403s?** Your key lacks `tasks:close` (a dangerous scope that
  wildcard `*` keys do NOT include — see /timebox key-scope troubleshooting).
  Fall back: PATCH the description to start `DONE <UTC date>: <evidence>`, leave
  the checkbox for a human, and report close-out as pending a scoped key. Never
  claim the task was completed.
- Never annotate titles to indicate completion — tick the real checkmark (the verbs).
- Smoke-test tasks use a `SMOKE:` title prefix.
- No secrets/keys ever in task titles or descriptions.
