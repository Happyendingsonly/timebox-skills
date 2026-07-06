# TimeBox skill pack for Claude Code

Let your AI teammate run your [TimeBox](https://timeboxinglife.com) board: mark
shipped work done, file new tasks where they belong, triage your raw thoughts, and
show you what's pending — all from Claude Code slash commands.

| Command | What it does |
|---|---|
| `/timebox` | One-time setup: your agent key, your projects, plus every API gotcha baked in |
| `/update` | Reconcile the board with reality — shipped work gets marked done (server-verified), new tasks get filed |
| `/braindump` | Dump raw thoughts; every item gets routed to the right project, idea list, or inbox |
| `/tasksworkspace` | One glance at what's pending: deadlines, blocked items, open tasks by project |

## Install (one time, ~2 minutes)

You'll need [Claude Code](https://claude.com/claude-code)
(`npm install -g @anthropic-ai/claude-code`) and a TimeBox account.

### Homebrew (recommended, macOS)

```bash
brew tap Happyendingsonly/timebox
brew trust happyendingsonly/timebox   # one-time: Homebrew asks you to trust third-party taps
brew install timebox-skills
timebox-skills-install
```

### Or manual (any OS)

```bash
git clone https://github.com/Happyendingsonly/timebox-skills ~/dev/timebox-skills
mkdir -p ~/.claude/skills
for s in timebox update braindump tasksworkspace; do
  ln -sfn ~/dev/timebox-skills/$s ~/.claude/skills/$s
done
```

Either way: open a new Claude Code session and type `/timebox` — it walks you
through getting your agent key and connecting your projects.

### Or just paste this into Claude Code

```
Set me up with TimeBox (timeboxinglife.com) so you can manage my tasks:

1. Clone https://github.com/Happyendingsonly/timebox-skills and symlink its 4
   skill folders (timebox, update, braindump, tasksworkspace) into ~/.claude/skills/.
2. Read timebox/SKILL.md from the pack and walk me through setup step by step:
   I'll get my agent key from TimeBox → Settings → Agents and paste it when you
   ask — store it ONLY in ~/.timebox/config.json (chmod 600), never print or
   commit it. Then help me fill in my projects (lanes) in that config.
3. Verify the connection with the pack's tb.sh helper (GET /context/bundle should
   return JSON) and show me it works by listing what's pending on my board.

From then on: /update reconciles my board with what actually shipped, /braindump
routes my raw thoughts, /tasksworkspace shows what's pending. Follow the skill
files exactly — verify every write by re-reading it, and never expose my key.
```

## Privacy & safety (by design)

- These files contain **no keys and no personal data** — examples use placeholder
  UUIDs only.
- Your key + project IDs live in **your own** `~/.timebox/config.json`
  (chmod 600, never committed). Every user gets their own agent key.
- The `tb.sh` helper never prints your key and refuses to mistake an HTML error
  page for API success.
- Skills verify every write by reading it back from the server — a 200 response
  alone is never treated as proof.
