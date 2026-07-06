---
name: cron
description: Set up, list, and retire scheduled jobs that run the skill pack headlessly (nightly digest, morning board report, drift checks) — launchd on macOS, crontab on Linux, with the proven safety guards baked in. Use when the user wants something to run on a schedule, says "cron", "schedule this", "run nightly/every morning", or asks what scheduled jobs exist.
---

# /cron — put the pack on a schedule, safely

Scheduled jobs run `claude -p "<job prompt>"` headlessly via the OS scheduler.
The reference implementation is a nightly wiki digest that has run clean in
production — every guard below comes from it or from a real incident (a
"retired" job that kept ticking for days because nobody unloaded it).

## What's cron-able (and what is NOT)

| Job | Cron-safe? | Shape |
|---|---|---|
| Wiki digest (fold inbox → canon) | ✅ proven | nightly; conflicts → proposals, failures → BLOCKED task |
| Morning board report | ✅ | early am; pulls bundle + lanes, posts a report brain note/dump + files a review task if something's urgent |
| Board drift check | ✅ report-only | daily; compares repo handoffs vs board, FILES a "drift found" task — never closes tasks itself |
| /smoke, /handover, /boot, /promptguide | ❌ | human-in-the-loop by design — never schedule these |

**Report-first rule:** a scheduled job POSTS reports and FILES review tasks; it
does not close tasks, ratify canon, or touch money paths unless that specific
job was explicitly ratified to (the digest is; new jobs start report-only).

## Modes

### `/cron` (bare) — inventory
1. `ls ~/Library/LaunchAgents/` (org-prefixed plists) + `launchctl list | grep <org>`
   — label, loaded?, last exit code.
2. Tail each job's log (`~/Library/Logs/<job>.log`, last run's lines).
3. **Zombie check:** any loaded job whose board task says retired → flag it
   loudly with the kill command. Retired-on-paper-but-still-ticking is a real
   failure mode.

### `/cron add <job> <schedule>` — create
1. **Runner script** in the hub repo's `scripts/<job>.sh`, copying the proven
   guard set:
   - lockfile (`mkdir /tmp/<job>.lock` + trap rmdir) — never two at once
   - **active-session guard**: skip if the repo tree is dirty OR an open
     SESSION-LOCK exists for the repo — never fight a live session
   - `git pull --ff-only` first; diverged → file BLOCKED task + exit
   - every failure files a `BLOCKED: <job> failed <date>` task on the subject
     lane (high priority) — jobs fail LOUD on the board, never silent in a log
   - log everything to `~/Library/Logs/<job>.log`
   - the headless call: `claude -p "<the job prompt>"` (each run costs
     credits — schedule the fewest runs that do the job)
2. **launchd plist** at `~/Library/LaunchAgents/com.<org>.<job>.plist`:
   `ProgramArguments` → bash + script path; `StartCalendarInterval` for the
   schedule; **explicit `PATH` and `HOME`** in `EnvironmentVariables` (launchd
   inherits almost nothing — missing PATH is the #1 silent failure);
   `StandardOutPath`/`StandardErrorPath` into `~/Library/Logs/`;
   `RunAtLoad true` if a missed overnight run should catch up at login.
3. Load + verify: `launchctl load ~/Library/LaunchAgents/com.<org>.<job>.plist`
   then `launchctl list | grep <job>`. Optionally kick a first run
   (`launchctl start com.<org>.<job>`) and read the log.
4. **File a board task documenting the job** (label, schedule, script path,
   kill command) and leave it OPEN as the job's registry entry — this is what
   makes retirement auditable.
   Linux: same runner script, `crontab -e` line instead of a plist.

### `/cron remove <label>` — retire (deactivate, never delete)
1. `launchctl bootout gui/$(id -u)/<label>` (or `launchctl unload <plist>`).
2. Move the plist to `~/Library/LaunchAgents/disabled/` — keep the artifact.
3. Verify it's gone from `launchctl list`.
4. Close the job's registry task with a note (date retired, by whom).
   Skipping step 1 is how zombies happen — unload FIRST, then file paperwork.

## Guardrails

- Never put the agent key in a plist or script — runners use tb.sh's key chain.
- One job = one narrow prompt. A scheduled "do whatever needs doing" is a
  credit furnace with no accountability.
- Laptop asleep at fire time → launchd coalesces the run to next wake only with
  `RunAtLoad`; for must-run jobs prefer an always-on machine (server/mini), or
  use Claude Code's built-in `/schedule` (cloud routines) so the job runs even
  with every local machine off.
- New job's first week: check its log daily before trusting it.
