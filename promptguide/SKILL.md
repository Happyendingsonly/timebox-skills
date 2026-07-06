---
name: promptguide
description: Prompt patterns that provably work in agent sessions — ruling format, scoped slices, gated deploys, echo-back specs, boot batons — plus the anti-patterns that waste hours. Use when the user asks how to prompt better, wants a prompt template, invokes /promptguide, or pastes a draft prompt to tighten before sending it.
---

# /promptguide — prompts that work

Distilled from a 56-session / one-week retrospective (2026-06-29 → 07-06):
every pattern below either shipped work with **zero rework** or **cost real
hours**, measured in the actual transcripts. Nothing here is theory.

## How to run this skill (for the agent)

- Bare `/promptguide` → show the **Quick card** below, then stop.
- `/promptguide <draft text>` → rewrite the draft using the patterns here.
  Return: the tightened prompt in a fenced block (ready to paste), then 1-3
  bullet lines on what you changed and which pattern applies. Don't build
  anything — this command edits prompts, not code.
- If the draft mixes many unrelated asks, say so and offer `/braindump` triage
  instead of pretending one prompt can hold ten jobs.

## Quick card — the six golden rules

1. **Batch, don't drip.** One message with everything beats ten fragments.
   (Best session of the week: 28 prompts → 447 tool actions. Worst: 3 rebuilds
   because a value list arrived in 3 corrections.)
2. **Name the scope AND the not-scope.** "ONE slice: X. Everything not listed
   is **do not build**." Ambiguity is where credits go to die.
3. **Decide like a judge.** Rulings, numbered: "Approve. #1 high. Split #2 into
   2a and 2b. File all three, re-read each." Zero-rework format, every time.
4. **Gate risky actions on evidence, not trust.** "Deploy ONLY if SHA starts
   with 7a44ba6." "Show me the exact RPC definition BEFORE creating it."
5. **Value lists get echoed back.** Naming enums/statuses/categories out loud?
   End with: "repeat the full list back from canon before building."
6. **Second correction = make it a rule.** If you're correcting the same thing
   twice, say "make that a rule" so it lands in canon/memory instead of dying
   with the session.

## Templates — fill in and fire

**Ruling / approval** (for proposals, plans, options):
```
Approve #1 and #3. #2: split into 2a <scope> and 2b <scope>, both filed as
tasks. Reject #4 — <one-line reason>. File everything on the right lane,
re-read each, report ids.
```

**Scoped build slice**:
```
Build ONE slice: <the thing>, in <repo/app>. In scope: <A, B, C>.
Everything not listed is DO NOT BUILD. Done means: <observable check>.
File a needs-test card with numbered steps when it ships.
```

**Read-only audit / decision aid**:
```
Read-only audit — no build, no writes. Question: <the decision I need to make>.
Cite files/data for every claim. End with a recommendation and the 2-3 facts
it hinges on.
```

**Gated deploy / risky action**:
```
<Action> ONLY if <verifiable precondition — SHA prefix, test green, row count>.
If the check fails, STOP and report what you saw instead.
```

**Bug report** (screenshot + one sentence is the proven combo):
```
[screenshot] <What I did> → <what happened> → <what should happen>. Fix it,
verify with <how you'll prove it>, don't touch anything else.
```

**Voice dump / many asks at once**:
```
Braindump, triage it: route every item to the right lane/task, dedupe first,
deadlines on top. Anything that's a build spec: echo the FULL interpreted spec
(complete value lists, from canon) back to me BEFORE building. Ambiguous items
→ ask, don't guess.
```

**Boot a new window** (or just use the NEXT-SESSION.md /handover writes):
```
START IN: <absolute repo path>. Window label: <one word>.
Boot per protocol (bundle + spines + latest handoff section only), file your
session lock, then: <the single job this window owns>. Do not pick up work
named in other windows' batons.
```

**When the usage-limit banner appears** (the only prompt worth sending):
```
/handover
```

## Anti-patterns — each one cost hours this week

- **Vague deixis after a gap**: "can you do it", "flip", "i sent it", "same
  things" — after compaction or hours away, the session doesn't share your
  referent. Re-anchor in one line: "the X we discussed for Y — do Z."
- **Piecemeal value lists**: "only A and B" … "sorry also C" … "ALSO D" =
  one rebuild per message. Demand the echo-back instead (rule 5).
- **Retrying against the usage wall**: ~40 messages of "hi" / re-pasted prompts
  died against "out of credits" in one week. The wall doesn't blink. `/handover`
  takes 2 minutes and the next window boots for pennies.
- **Ten asks in one ramble, untriaged**: several silently dropped. Voice-dump
  freely — but through the braindump template so every item gets routed.
- **The same baton pasted into multiple windows**: three sessions once picked
  up the same job. One window, one job, one label.
- **Secrets in chat**: a pasted API key lives in the transcript forever and has
  to be rotated. Keys go in config files from your own terminal.
- **Marathon threads across topics**: one 5-day thread hit 30 auto-compactions
  and features had to be re-requested after each. Topic pivot = new window.

## Why this works (the one-liner)

Agent sessions execute *decisions* brilliantly and *guesses* expensively.
Every pattern above converts a guess into a decision before the work starts.
