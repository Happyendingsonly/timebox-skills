#!/bin/bash
# tb.sh — TimeBox agent API helper. Wraps curl with key loading + JSON guard.
#
#   tb.sh GET  /context/bundle
#   tb.sh GET  "/project-tasks?project_id=<uuid>"
#   tb.sh POST /projects/<uuid>/tasks '{"title":"..."}'
#   tb.sh PATCH /project-tasks/<uuid> '{"done":true,"status":"done"}'
#
# Key lookup order (never printed, never logged):
#   1. $TIMEBOX_AGENT_KEY
#   2. ~/.timebox.env           → TIMEBOX_AGENT_KEY=…
#   3. ~/.timebox/config.json  → .agentKey
#   4. macOS Gatekeeper config → ~/Library/Application Support/TimeBoxGatekeeper/config.json
#
# Guards against the SPA-fallthrough trap: a wrong path returns HTTP 200 + HTML,
# not an error — this script detects HTML and exits 1 so you never mistake a
# missed endpoint for success.
set -euo pipefail

METHOD="${1:?usage: tb.sh METHOD /path [json-body]}"
APIPATH="${2:?usage: tb.sh METHOD /path [json-body]}"
BODY="${3:-}"

BASE="${TIMEBOX_URL:-https://timeboxinglife.com}/api/public/agent"

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
