---
name: timebox
description: Set up and use the TimeBox agent API — get your agent key, create your config, set up brains/spines for projects, connect your workspace, and learn the API gotchas. Use when someone asks how to connect to TimeBox, set up their key, create a spine/brain, or when any session needs to call the TimeBox API for the first time.
---

# TimeBox — setup & how-to

TimeBox (timeboxinglife.com) is the org's hub and agent OS: boards (projects/lanes),
brain-dump capture, Brains (wikilinked notes with backlinks), project spines, and an
agent API (~179 endpoints, docs live at `https://timeboxinglife.com/agent-api.md`).

**Helper:** use `scripts/tb.sh` in this skill directory for **ALL API calls,
including the boot calls — never raw curl**. (Week-of-2026-07-06 evidence: every
SPA-fallthrough hit and every silent list-truncation came from sessions that
bypassed tb.sh; sessions that used it had zero.) It loads the key safely,
auto-adds `limit`, guards the SPA-fallthrough and double-pathed-base traps, and
files/releases session locks:

```bash
scripts/tb.sh GET /context/bundle
scripts/tb.sh POST /projects/<project-uuid>/tasks '{"title":"My task"}'
scripts/tb.sh lock   <project-uuid> <repo-name> "<scope note>"   # SESSION-LOCK in one call
scripts/tb.sh unlock <project-uuid> <lock-task-uuid>             # complete + re-read verify
```

## SECURITY — non-negotiable

- **Never print, echo, log, or commit an agent key.** Not even a fragment.
- Keys go in local config files only (chmod 600), never in git, never in URLs,
  never in task descriptions or brain notes.
- Each person/lane gets **their own key** — never share keys between users or lanes.
- When showing examples to others, use placeholder UUIDs (`<project-uuid>`), never
  real IDs from someone else's workspace.

## 1. Get your agent key

**Key hygiene first:** never paste a key into the chat or `!` bash-input — it
lands in the session transcript permanently (this happened once; the key had to
be rotated). If the user pastes one anyway: write it straight into the config,
never echo it back, and recommend rotation. If no key/config exists on this
machine yet, STOP and have the user create it **in their own terminal**, not
through the session.

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
4. **Scope preflight** (never prints the key): `scripts/tb.sh GET /context/bundle`
   → should return JSON with `readiness`, `priorities`, `recent_activity`. A 403
   here means the key lacks `me:read` — see the troubleshooting section below.
   If this session will close tasks, confirm the key carries `tasks:close` NOW
   (wildcard `*` keys don't include it) rather than discovering it at close-out.

Key lookup order used by tb.sh: `$TIMEBOX_AGENT_KEY` env → `~/.timebox/config.json`
→ macOS Gatekeeper config (owner machines only).

### Key-scope troubleshooting (decoding 403s)

Keys look identical (`lk_live_…`) but carry different scopes depending on where
they were issued. Verified failure modes (2026-07-06):

- **`GET /context/bundle` 403s** → the key lacks `me:read` (keys from the old
  "Agent keys" settings page) or is ingest-only (`builds:read` — keys from the
  Agents page before 2026-07-06, and any key found in a settings.local.json
  allowlist). Fix: re-issue from **Settings → Agents** (grants full `*`).
- **Reads work but completing tasks 403s** (`PATCH /project-tasks` with done, or
  `POST /tasks/:id/complete`) → `tasks:close` is a *dangerous* scope that wildcard
  `*` keys do NOT include. Fix: have the workspace owner issue/upgrade a key with
  explicit `tasks:close`. Until then, **fall back, don't fake it**: PATCH the
  description to start `DONE <UTC date>: <evidence>`, leave the real checkbox to a
  human, and say clearly in your report that close-out is pending a scoped key.
- Diagnose in one line: a 403 body names the missing scope — read it before
  assuming the key is dead.

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

0. **Be IN a real repo** — your org's hub repo (where the wiki/spines/lane map
   live) or the subject repo, whichever your org prefers; never your home dir or
   a random folder. Out-of-repo sessions load no project instructions, file
   transcripts under the wrong project, and re-hit solved traps.

```bash
scripts/tb.sh GET /context/bundle    # readiness, priorities, blocks, recent activity
scripts/tb.sh GET /spines            # find your project's spine
git fetch origin                     # FETCH FIRST — never act on a stale clone
git log --oneline HEAD..origin/main  # remote ahead? fast-forward BEFORE reading state
scripts/tb.sh lock <lane-uuid> <repo-name> "<one-line scope>"   # SESSION-LOCK (step, not optional)
```

Then read the repo's `SESSION-HANDOFF.md`. Context lives in TimeBox + the handoff,
not in any one session's memory.

**Session-lock rules:** check the lane for an existing open `SESSION-LOCK: <repo>`
BEFORE filing yours. Open + recent → demote yourself to reporter (read and
analyze; no writes to code, board tasks, or the handoff). Idle 3h+ → abandoned:
take over by APPENDING a note to its description (never delete a stale lock —
it's the audit trail). At close-out:
`scripts/tb.sh unlock <lane-uuid> <lock-task-uuid>` (completes + re-read verifies
in one call). Lock adoption was 1/3 the night the rule shipped — it is a boot
STEP, not a suggestion.

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
| Capture an idea | `POST /brain-dumps` `{"text":"…"}` (field is `text` — `content` returns `{"error":"Required"}`; brain NOTES use `content`, dumps use `text`) |
| Read the dump feed | `GET /brain-dumps?limit=500` (default truncates) |
| Brains / notes | `GET /brains` · `GET/POST /brains/:id/notes` · `GET/PATCH /brain-notes/:id` (full note + backlinks) |
| Update a spine | `PATCH /spines/:id` |

**Any endpoint NOT in this table: fetch `https://timeboxinglife.com/agent-api.md`
and grep it BEFORE calling. Never guess a path** — wrong paths return 200 + HTML,
not a 404, so a guessed path can look like success (tb.sh catches this, raw curl
won't).

## API gotchas (hard-won — trust these)

- **Wrong paths don't 404.** `POST /project-tasks` does not exist — it returns
  HTTP 200 + the SPA's HTML. Always check the body is JSON (tb.sh does this for you).
- **List responses are usually wrapped — and the key is per-endpoint:**
  `/project-tasks` → `project_tasks` (NOT `tasks` — parsing `.tasks` gives a
  silent empty list), `/spines` → `spines`, `/brains/:id/notes` → `notes`,
  `/brain-dumps` → `brain_dumps`. But NOT always: `GET /workspaces` AND
  `GET /brains/:id/notes` return BARE arrays (the notes one caused false-alarm
  failure reports on 2026-07-06). Handle both shapes — and mind the order:
  `d if isinstance(d, list) else d.get("<key>", [])` (calling `.get` first
  crashes on the bare-array endpoints).
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
- **`done:true` in a CREATE body is silently ignored** — `POST /projects/:id/tasks`
  accepts it, 200s, and stores `done:false`. Create first, then PATCH done.
  And PATCH by **full uuid**: a short-id PATCH can set `status` but not `done`
  (verified 2026-07-06 — the re-read catches this).
- **Datetimes must be UTC `Z` format** (`2026-07-09T05:59:00Z`); offset strings
  (`+00:00`) are rejected with 400 invalid_string.
- **Blocked work:** keep the task open and put `BLOCKED: <reason>` at the TOP of the
  description. There is no blocked_reason field — don't invent one.
- Use `curl` (or tb.sh), not Python urllib — the system Python 3.9 fails TLS
  against this server (51 failures in one week of sessions that forgot this).
- **Don't `source ~/.timebox.env`** — sourcing it has broken PATH mid-session
  (`curl: command not found`). tb.sh reads the key itself; let it.
- **No foreground `sleep` while waiting** on deploys/backfills — the harness
  blocks it. Run the wait in a background command and poll, or just proceed and
  re-check.
- Note-list responses omit `content`; fetch `GET /brain-notes/:id` for full content
  + backlinks.

## Companion commands

- `/update` — reconcile shipped work with the board (mark done, file new tasks)
- `/braindump` — route raw thoughts to the right lanes/tasks/ideas
- `/tasksworkspace` — show what's pending across your lanes
