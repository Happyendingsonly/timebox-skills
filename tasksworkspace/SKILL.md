---
name: tasksworkspace
description: Pull the user's TimeBox workspace and show what's pending — open tasks per lane, blocked items with reasons, deadlines, smoke tests owed, and today's readiness. Use when the user asks what's pending, what to work on, board status, or invokes /tasksworkspace.
---

# /tasksworkspace — what's on the board

One command → the whole workspace state, organized for action.

Uses `<timebox-skill-dir>/scripts/tb.sh` + the user's lane map from
`~/.timebox/config.json` (see `/timebox` for setup).

## Pull

1. `tb.sh GET /context/bundle` — readiness (top-3 set?), unsorted brain-dump count,
   open gates, recent agent activity.
2. For each lane in the user's config:
   `tb.sh GET "/project-tasks?project_id=<lane-uuid>&limit=200"`
   (response is wrapped: `{"project_tasks":[...]}`; always `limit=200` — the
   default 50 silently truncates busy boards).
3. Optionally `tb.sh GET /spines` if the user asks about project wiring.

## Organize — in this order

1. **🔥 Deadlines** — any open task with a `due_date`, soonest first. Overdue in bold.
2. **🚫 Blocked** — tasks whose description starts with `BLOCKED:`; show the reason
   verbatim. These need a human unblock, surface them prominently.
3. **🧪 Needs test / smoke** — open tasks tagged `smoke`, titled `SMOKE:`, or
   clearly verification work.
4. **📋 Open by lane** — remaining `not_started` / in-progress tasks grouped per
   lane, one line each: `id-prefix | title`. Keep lines short.
5. **📥 Loose ends** — unsorted brain-dump count from the bundle; readiness state
   (top-3 set? journaled?) if the user tracks it.

## Rules

- Read-only by default: this command NEVER completes, creates, or edits tasks.
  If the user wants changes after seeing the board, hand off to `/update`.
- Done tasks are noise — exclude them unless the user asks for history.
- `SESSION-LOCK:` titled tasks are coordination plumbing, not work — exclude them
  from the pending lists; show at most a one-line footer ("2 active session locks")
  so the user knows which repos are claimed.
- If a lane in the config returns HTML or errors, say so per-lane rather than
  failing the whole report (tb.sh flags SPA fallthrough).
- Keep the whole report scannable — this is a glance-at-your-day view, not a data
  dump. Compact tables, id prefixes (8 chars), no descriptions unless blocked.
- If unsorted brain-dumps > 5, add one line suggesting a `/braindump` triage pass
  (boots have surfaced 11 unsorted dumps without anyone acting on them).
- End with a one-line suggestion: the single most urgent thing on the board and why.
