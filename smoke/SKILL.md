---
name: smoke
description: Needs-test (smoke) cards — create one with numbered click-by-click steps when a feature ships, list what's waiting to be tested, or walk the user through running one and close the linked task on pass. Use when the user says "smoke", "needs test", "what do I need to test", wants to run/score a test card, or after shipping UI the agent cannot verify itself.
---

# /smoke — needs-test cards that actually get run

The standing rule: **an agent never self-verifies shippable UI.** Anything a
human must click gets a smoke card with numbered steps; the human runs it; the
result closes (or blocks) the real task. A card with no concrete steps is
worthless — each step is an action + what you should see.

Uses `<timebox-skill-dir>/scripts/tb.sh` + the org lane map. Smoke cards are
board tasks titled `SMOKE: <feature>` on the SUBJECT lane, description linking
the feature task id.

## Modes

### `/smoke` (bare) — what's waiting to be tested
Pull each lane, list open `SMOKE:` cards: `id-prefix | feature | # steps | age`.
Oldest first. One line each. End with: which one to run first and why.

### `/smoke run [id or hint]` — walk it, score it, close it
1. Fetch the card; show the steps.
2. Walk the user through **one step at a time**: the action, then "what do you
   see?" Record pass/fail per step — the user's words, not your assumption.
3. **All pass** → complete the smoke card AND the linked feature task with the
   real verbs (`PATCH /project-tasks/:id {"done":true,"status":"done"}`), then
   re-read both to confirm server-side `done` — a 200 alone is not proof.
4. **Any fail** → both stay open. Append the finding to the smoke card's
   description (`FAILED step N: <what was seen> — <date>`), file a bug task on
   the subject lane with the failing step quoted, and link the two.

### `/smoke create` — after something ships
Build the card BEFORE claiming the feature is done:
- Title: `SMOKE: <feature, in the user's words>`
- Description: link to the feature task id, then **numbered click-by-click
  steps** — each step = exactly what to do + exactly what should be visible.
  Finish with a single yes/no gate step ("if all above matched: PASS").
- 5-9 steps is the sweet spot; over 12 means split the card.
- File on the subject lane, verify by re-read, and report the id.
- Programmatic checks the agent CAN run (API round-trips, DB reads) are run
  FIRST and their results noted in the card — the human only tests what only
  a human can see.

## Guardrails

- Never mark the feature task done while its smoke card is open.
- Never run a smoke "on the user's behalf" — the human's eyes are the point.
- No secrets or live keys in card steps; use placeholder accounts/devices.
