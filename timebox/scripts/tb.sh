#!/bin/bash
# tb.sh — TimeBox agent API helper. Wraps curl with key loading + JSON guard.
#
#   tb.sh GET  /context/bundle
#   tb.sh GET  "/project-tasks?project_id=<uuid>"          # limit=200 auto-added
#   tb.sh POST /projects/<uuid>/tasks '{"title":"..."}'
#   tb.sh PATCH /project-tasks/<uuid> '{"done":true,"status":"done"}'
#   tb.sh lock   <project-uuid> <repo-name> [scope-note]   # file SESSION-LOCK task
#   tb.sh unlock <project-uuid> <lock-task-uuid>           # complete + re-read verify
#
# Key lookup order (never printed, never logged):
#   1. $TIMEBOX_AGENT_KEY
#   2. ~/.timebox.env           → TIMEBOX_AGENT_KEY=…   (read with sed — do NOT
#      `source` this file in your shell; sourcing it has broken PATH in sessions)
#   3. ~/.timebox/config.json  → .agentKey
#   4. macOS Gatekeeper config → ~/Library/Application Support/TimeBoxGatekeeper/config.json
#
# Guards:
#   - SPA fallthrough: a wrong path returns HTTP 200 + HTML, not an error — this
#     script detects HTML and exits 1 so a missed endpoint never looks like success.
#   - Double-pathed base: a TIMEBOX_URL already ending in /api/public/agent is
#     stripped before appending (…/agent/api/public/agent/… returned the SPA
#     not-found page as a "404" on 2026-07-03).
#   - List truncation: GET on list endpoints gets limit=200 (brain-dumps: 500)
#     added automatically when the caller didn't pass one.
set -euo pipefail

# --- base URL (double-path guard) ---
RAWBASE="${TIMEBOX_URL:-https://timeboxinglife.com}"
RAWBASE="${RAWBASE%/}"
RAWBASE="${RAWBASE%/api/public/agent}"
BASE="$RAWBASE/api/public/agent"

# --- subcommands ---
if [ "${1:-}" = "lock" ]; then
  PROJ="${2:?usage: tb.sh lock <project-uuid> <repo-name> [scope-note]}"
  REPO="${3:?usage: tb.sh lock <project-uuid> <repo-name> [scope-note]}"
  SCOPE="${4:-}"
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  SURFACE="${TB_SURFACE:-Claude Code $(hostname -s 2>/dev/null || echo unknown)}"
  BODY=$(python3 -c '
import json,sys
repo,now,surface,scope=sys.argv[1:5]
d=f"session start {now}; surface: {surface}"
if scope: d+=f"; scope: {scope}"
print(json.dumps({"title":f"SESSION-LOCK: {repo}","description":d}))' "$REPO" "$NOW" "$SURFACE" "$SCOPE")
  exec "$0" POST "/projects/$PROJ/tasks" "$BODY"
fi

if [ "${1:-}" = "unlock" ]; then
  PROJ="${2:?usage: tb.sh unlock <project-uuid> <lock-task-uuid>}"
  TASK="${3:?usage: tb.sh unlock <project-uuid> <lock-task-uuid>}"
  "$0" PATCH "/project-tasks/$TASK" '{"done":true,"status":"done"}' >/dev/null
  # verify by re-read (200 ≠ landed): pull the board and print the lock's state
  "$0" GET "/project-tasks?project_id=$PROJ&limit=200" | python3 -c '
import json,sys
tid=sys.argv[1]
d=json.load(sys.stdin); ts=d.get("project_tasks",d if isinstance(d,list) else [])
m=[t for t in ts if t.get("id")==tid]
if not m:
    print(f"tb.sh unlock: task {tid} NOT FOUND on board — verify manually", file=sys.stderr); sys.exit(1)
t=m[0]
print(json.dumps({"id":t["id"],"title":t.get("title"),"done":t.get("done"),"status":t.get("status")}))
sys.exit(0 if t.get("done") is True else 1)' "$TASK"
  exit $?
fi

METHOD="${1:?usage: tb.sh METHOD /path [json-body] | tb.sh lock|unlock ...}"
APIPATH="${2:?usage: tb.sh METHOD /path [json-body]}"
BODY="${3:-}"

# --- auto-limit on list GETs (default limit=50 silently truncates busy boards) ---
if [ "$METHOD" = "GET" ] && [[ "$APIPATH" != *limit=* ]]; then
  SEP='?'; [[ "$APIPATH" == *\?* ]] && SEP='&'
  case "$APIPATH" in
    /project-tasks*|/tasks*|/ingest/events*) APIPATH="${APIPATH}${SEP}limit=200" ;;
    /brain-dumps*)                            APIPATH="${APIPATH}${SEP}limit=500" ;;
  esac
fi

get_key() {
  if [ -n "${TIMEBOX_AGENT_KEY:-}" ]; then printf '%s' "$TIMEBOX_AGENT_KEY"; return; fi
  if [ -f "$HOME/.timebox.env" ]; then
    k=$(sed -n 's/^TIMEBOX_AGENT_KEY=//p' "$HOME/.timebox.env" | head -1 | tr -d '"' )
    if [ -n "$k" ]; then printf '%s' "$k"; return; fi
  fi
  for f in "$HOME/.timebox/config.json" "$HOME/Library/Application Support/TimeBoxGatekeeper/config.json"; do
    if [ -f "$f" ]; then
      k=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('agentKey',''))" "$f" 2>/dev/null || true)
      if [ -n "$k" ]; then printf '%s' "$k"; return; fi
    fi
  done
  echo "tb.sh: no agent key found (set TIMEBOX_AGENT_KEY or add agentKey to ~/.timebox/config.json)" >&2
  exit 1
}

KEY="$(get_key)"

if [ -n "$BODY" ]; then
  RESP=$(curl -s -X "$METHOD" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$BODY" "$BASE$APIPATH")
else
  RESP=$(curl -s -X "$METHOD" -H "Authorization: Bearer $KEY" "$BASE$APIPATH")
fi

case "$RESP" in
  "<!DOCTYPE"*|"<html"*|" <"*)
    echo "tb.sh: SPA fallthrough — '$APIPATH' is not a real endpoint (got HTML, not JSON). Check the path." >&2
    exit 1;;
esac

printf '%s\n' "$RESP"
