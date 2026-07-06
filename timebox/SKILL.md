---
name: timebox
description: Set up and use the TimeBox agent API — get your agent key, create your config, set up brains/spines for projects, connect your workspace, and learn the API gotchas. Use when someone asks how to connect to TimeBox, set up their key, create a spine/brain, or when any session needs to call the TimeBox API for the first time.
---

# TimeBox — setup & how-to

TimeBox (timeboxinglife.com) is the org's hub and agent OS: boards (projects/lanes),
brain-dump capture, Brains (wikilinked notes with backlinks), project spines, and an
agent API (~179 endpoints, docs live at `https://timeboxinglife.com/agent-api.md`).

**Helper:** use `scripts/tb.sh` in this skill directory for all API calls — it loads
the key safely and catches the SPA-fallthrough trap:

```bash
scripts/tb.sh GET /context/bundle
scripts/tb.sh POST /projects/<project-uuid>/tasks '{"title":"My task"}'
```

## SECURITY — non-negotiable

- **Never print, echo, log, or commit an agent key.** Not even a fragment.
- Keys go in local config files only (chmod 600), never in git, never in URLs,
  never in task descriptions or brain notes.
- Each person/lane gets **their own key** — never share keys between users or lanes.
- When showing examples to others, use placeholder UUIDs (`<project-uuid>`), never
  real IDs from someone else's workspace.

## 1. Get your agent key

1. Sign in to TimeBox → Settings → Agents (or ask the workspace owner to issue you one).
2. Store it in `~/.timebox/config.json` (create the file):

```json
{
  "agentKey": "<paste-key-here>",
  "lanes": {
    "<project-name>": "<project-uuid>"
  },
  "brainId": "<brain-uuid-if-you-sync-notes>"
}
```

3. `chmod 600 ~/.timebox/config.json`
4. Verify (never prints the key): `scripts/tb.sh GET /context/bundle` → should
   return JSON with `readiness`, `priorities`, `recent_activity`.

Key lookup order used by tb.sh: `$TIMEBOX_AGENT_KEY` env → `~/.timebox/config.json`
→ macOS Gatekeeper config (owner machines only).

## 2. Find your lanes (projects)

Tasks are filed by SUBJECT: a task lands under the project of the app it is ABOUT.
**There is no `GET /projects`** — discovery goes through workspaces:

```bash
scripts/tb.sh GET /workspaces                                # your workspaces (BARE array)
scripts/tb.sh GET /workspaces/<workspace-uuid>/projects      # projects in one workspace
scripts/tb.sh GET "/project-tasks?project_id=<project-uuid>&limit=200"   # a board's tasks
```

Record the project UUIDs you work with into your config's `lanes`. If your org keeps
a lane table (a task-filing doc in its hub repo), copy the lane→project IDs from
there instead of guessing.

## 3. Set up a spine for a project

A spine ties a project to its repos, blueprints, brain, and entity-URI prefix so any
agent session can boot with one call instead of re-reading everything:

```bash
scripts/tb.sh GET /spines                       # see existing spines first
scripts/tb.sh POST /spines '{
  "name": "My Project",
  "repo_refs": ["github:<org>/<repo>"],
  "blueprint_urls": ["https://github.com/<org>/<blueprint-repo>"],
  "brain_id": "<brain-uuid>",
  "entity_uri_prefixes": ["myp://"]
}'
scripts/tb.sh PATCH /spines/<spine-uuid> '{"brain_id":"<brain-uuid>"}'   # update later
```

Rule: **check existing spines before creating** — one spine per project, update
don't duplicate.

## 4. Set up a brain (wikilinked notes)

Brains hold notes with `[[wikilinks]]`; the server computes backlinks automatically.

```bash
scripts/tb.sh GET /brains                                 # list brains
scripts/tb.sh POST /brains/<brain-uuid>/notes '{"title":"My Note","content":"Links like [[Other Note]] work."}'
scripts/tb.sh GET /brain-notes/<note-uuid>                # full note incl. backlinks[]
```

Point your project's spine at the brain (`brain_id`) so navigating the project
surfaces its notes.

## 5. Session boot ritual (how every agent session should start)

```bash
scripts/tb.sh GET /context/bundle    # readiness, priorities, blocks, recent activity
scripts/tb.sh GET /spines            # find your project's spine
git fetch origin                     # FETCH FIRST — never act on a stale clone
git log --oneline HEAD..origin/main  # remote ahead? fast-forward BEFORE reading state
```

Then read the repo's `SESSION-HANDOFF.md`. Context lives in TimeBox + the handoff,
not in any one session's memory.

**Session lock (if your org runs the convention):** at boot, file a task titled
`SESSION-LOCK: <repo>` under the subject lane (description: start time UTC +
surface); complete it at close-out. If you find an open, recent lock for your repo,
demote yourself to reporter — read and analyze, but no writes to code, board tasks,
or the handoff. A lock idle for 3h is abandoned: take over by APPENDING a note to
its description (never delete a stale lock — it's the audit trail).

## Endpoint quick reference (covers ~95% of sessions)

| Purpose | Endpoint |
|---|---|
| Boot: situational awareness | `GET /context/bundle` |
| Boot: project wiring | `GET /spines` · `GET /ingest/events?spine_id=<id>` |
| Discover projects | `GET /workspaces` (bare array!) → `GET /workspaces/:id/projects` |
| Read a board | `GET /project-tasks?project_id=<id>&limit=200` |
| One board task | `GET /projects/:projectId` · `PATCH /project-tasks/:id` |
| Create board task | `POST /projects/:projectId/tasks` |
| Complete board task | `PATCH /project-tasks/:id` `{"done":true,"status":"done"}` |
| Loose/personal tasks | `GET/POST /tasks` · `POST /tasks/:id/complete` |
| Subtasks | `GET/POST /tasks/:taskId/subtasks` |
| Capture an idea | `POST /brain-dumps` `{"content","kind":"idea"}` |
| Brains / notes | `GET /brains` · `GET/POST /brains/:id/notes` · `GET/PATCH /brain-notes/:id` (full note + backlinks) |
| Update a spine | `PATCH /spines/:id` |

**Any endpoint NOT in this table: fetch `https://timeboxinglife.com/agent-api.md`
and grep it BEFORE calling. Never guess a path** — wrong paths return 200 + HTML,
not a 404, so a guessed path can look like success (tb.sh catches this, raw curl
won't).

## API gotchas (hard-won — trust these)

- **Wrong paths don't 404.** `POST /project-tasks` does not exist — it returns
  HTTP 200 + the SPA's HTML. Always check the body is JSON (tb.sh does this for you).
- **List responses are usually wrapped:** `{"project_tasks":[...]}`, `{"spines":[...]}`,
  `{"notes":[...]}` — but NOT always: `GET /workspaces` returns a bare array. Handle
  both shapes (`d if isinstance(d, list) else d.get("<key>", [])`).
- **No `GET /projects`** — list projects via `GET /workspaces` then
  `GET /workspaces/:id/projects`.
- **`GET /project-tasks` defaults to limit=50.** On busy boards your verify-by-re-read
  will silently miss fresh tasks — always pass `&limit=200` when listing to verify.
- **Create board tasks** via `POST /projects/:projectId/tasks` (title required;
  priority/status/due_date/description optional). Loose personal tasks: `POST /tasks`.
- **Completion verbs differ by table:** brain-dump/loose tasks →
  `POST /tasks/:id/complete`; board tasks → `PATCH /project-tasks/:id` with
  `{"done":true,"status":"done"}`. **Then re-read the task and confirm the server
  says done — a 200 alone is not proof.**
- **Datetimes must be UTC `Z` format** (`2026-07-09T05:59:00Z`); offset strings
  (`+00:00`) are rejected with 400 invalid_string.
- **Blocked work:** keep the task open and put `BLOCKED: <reason>` at the TOP of the
  description. There is no blocked_reason field — don't invent one.
- Use `curl` (or tb.sh), not Python urllib — the system Python 3.9 fails TLS
  against this server.
- Note-list responses omit `content`; fetch `GET /brain-notes/:id` for full content
  + backlinks.

## Companion commands

- `/update` — reconcile shipped work with the board (mark done, file new tasks)
- `/braindump` — route raw thoughts to the right lanes/tasks/ideas
- `/tasksworkspace` — show what's pending across your lanes
