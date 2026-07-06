---
name: braindump
description: Take the user's raw thoughts (typed, pasted, or voice-note transcripts) and route every item to where it belongs in TimeBox — lane tasks, ideas, subtasks, deadlines, or the knowledge inbox. Use when the user dumps unstructured thoughts, says "braindump", or wants their notes triaged into the system.
---

# /braindump — thoughts in, everything where it belongs

The user gives raw, unstructured input (one thought or fifty). Triage every single
item — nothing gets dropped, nothing stays in chat-only memory.

Uses `<timebox-skill-dir>/scripts/tb.sh` + the user's lane map from
`~/.timebox/config.json` (see `/timebox` for setup).

## Input

Take `$ARGUMENTS` as the dump if provided; otherwise ask the user to paste/say
everything on their mind. Accept mess: fragments, mixed topics, half-sentences.

## Triage rules — route each item by kind

| Item looks like | Route to | How |
|---|---|---|
| Actionable work for a known project | That SUBJECT lane's board | `POST /projects/<lane-uuid>/tasks` |
| Piece of an existing task | Subtask | `POST /tasks/<taskId>/subtasks` |
| Idea not being built now | Brain-dump feed | `POST /brain-dumps` `{"content", "kind":"idea"}` |
| Has a real deadline ("by Wednesday", "expires") | Task with `due_date` (UTC `Z`) + high priority | Board task; flag it loudly in the report |
| Durable fact/decision/convention | Knowledge inbox (if your org keeps a knowledge-base repo with an `inbox/`) | Write a dated markdown drop |
| Question needing a human answer | Task titled as the question, or ask it right now if the user is present | Board task |
| Personal (no project) | Loose task | `POST /tasks` |

## Rules

1. **Dedup before creating.** Pull the target lane's open tasks first; if an
   existing task covers the item, note the match instead of duplicating.
2. **Subject-lane filing:** an item lands under the project it is ABOUT.
3. **Repetition is signal:** if the same instruction shows up multiple times across
   dumps, it's a standing rule — flag it for the org's conventions/canon, not just
   a one-off task.
4. **Deadlines never get buried.** Anything time-critical gets its own
   high-priority task with a `due_date`, surfaced at the TOP of the report.
5. **Sensitive data:** names/reputation/identity items about third parties do NOT
   go into shared boards or wikis — flag them to the user and leave them in the
   source system only.
6. **Verify writes:** every create is confirmed by reading it back (tb.sh already
   rejects SPA-fallthrough HTML).

## Report

End with a table: item (short) → routed to (lane/idea/inbox/subtask/skipped-dup) →
id. Deadlines first. If anything was ambiguous, list it under "needs your call"
with a one-line question each — don't guess on genuinely ambiguous routing.
