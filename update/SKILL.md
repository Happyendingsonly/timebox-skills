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

## Steps

1. **Gather what actually happened.**
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

5. **Verify server-side.** Re-read the task/board and confirm `status: done` /
   `done: true` in the response. A 200 alone is NOT proof. Report each verification.

6. **Partial or blocked work stays open** with `BLOCKED: <reason>` prefixed to the
   top of the description (PATCH the description; there is no blocked_reason field).

7. **File the new stuff.** New tasks, projects, subtasks the user mentions:
   - Board task: `POST /projects/<lane-uuid>/tasks` `{"title", "description"?, "priority"?, "due_date"?}`
   - Subtask: `POST /tasks/<taskId>/subtasks`
   - Deadlines in UTC `Z` format only.
   - Dedup first: check the lane's existing open tasks before creating.

8. **Update the repo.** If this repo keeps a `SESSION-HANDOFF.md`, append/refresh the
   latest-state section. Commit per the repo's conventions if the user wants;
   **never force-push shared branches.**

9. **Report** a compact table: task → action taken (completed✓verified / created /
   blocked / skipped-duplicate) → id.

## Guardrails

- Never mark a task done without server-side verification (step 5).
- Never annotate titles to indicate completion — tick the real checkmark (the verbs).
- Smoke-test tasks use a `SMOKE:` title prefix.
- No secrets/keys ever in task titles or descriptions.
