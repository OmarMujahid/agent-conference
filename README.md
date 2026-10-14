# agent-conference

A [Claude Code](https://claude.com/claude-code) skill that runs a **design conference between several AI models**, using Claude subagents and OpenAI Codex CLI agents together, to settle a hard design question that has many open decisions.

It runs as a **Delphi process** instead of an open-ended debate:

```
research pack → round 0: assumptions → you rule
             → question sheet → you approve
             → round 1: independent votes → moderator tally
             → round 2: revote on splits only → moderator tally → you rule on what's left
             → synthesis → fidelity check → persona reaction
```

## How it works

- **Panelists** are models with different jobs (e.g. architecture, quality, red team, user advocate). They mix Claude subagents and Codex CLI agents, so they have different blind spots.
- **Votes, not essays.** Every panelist answers the same question sheet: a vote of ≤6 words, 2 lines of reason, and a citation into the research pack (`brief-x §y`).
- **Round 0 attacks the framing.** Before anyone proposes a design, each panelist lists the assumptions it doubts. You rule on them.
- **Round 1 is independent.** Panelists don't see each other's answers.
- **A moderator tallies.** A cheap model turns the votes into a table: each question is AGREED or SPLIT, plus each panelist's "hill I'd die on".
- **Round 2 covers the splits only.** Panelists read the tally and the others' answers, then revote. A changed vote must cite evidence; "another panelist argued well" doesn't count.
- **Two voting rounds, max.** Anything still split goes to you, not to a third round.
- **Panelists are labeled by role, not by model.**
- **Fidelity check.** The synthesis goes back to every panelist: "quote every line that contradicts your votes, your hills, or the evidence".
- **Persona.** A cheap model reacts as the end user, labeled *simulated*. It doesn't vote.

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) (the orchestrator, plus Claude subagents as panelists)
- [OpenAI Codex CLI](https://github.com/openai/codex) (`codex exec`), logged in, for the Codex panelists
- bash, coreutils, `setsid`, `timeout` (Linux; on macOS install `util-linux` and `coreutils`)

The default cast uses `gpt-6-astra`, `gpt-6-sol` and `gpt-6-luna` on the Codex side and Opus/Fable on the Claude side. Change the cast table in `SKILL.md` to whatever you have.

## Install

```bash
git clone https://github.com/OmarMujahid/agent-conference.git
mkdir -p ~/.claude/skills ~/.local/bin
cp -r agent-conference/skills/conference ~/.claude/skills/
cp agent-conference/bin/codex-conference.sh ~/.local/bin/ && chmod +x ~/.local/bin/codex-conference.sh
```

Make sure `~/.local/bin` is on your `PATH`. Restart Claude Code; the skill shows up as `conference`.

## Use

Ask Claude Code for it in plain words:

> Run a conference on whether we should move our job queue from Postgres to SQS. Research the codebase first.

Claude will:

1. **Build the research pack.** It sends subagents to write numbered briefs (`brief-x.md`, sections `§1…`) on the code, the evidence, and outside research. It also writes `00-research-pack.md`: the ask, constraints, and corrections when a brief got something wrong.
2. **Run round 0** and show you `assumptions.md`, a merged table of assumptions the panelists doubt. **You rule** on each. In practice this round alone can change the question.
3. **Write `questions.md`** (15–30 questions, concrete options, IDs) and **show it to you**.
4. **Run rounds 1 and 2** and the tallies, then show you the remaining splits with each side's best evidence. **You rule.**
5. **Write `synthesis.md`**, run the fidelity check, fix what holds up, and add the persona reaction.

You're asked at four points only: after round 0, after the question sheet, on the final splits, and at the end.

### Running Codex panelists by hand

```bash
codex-conference.sh launch -d ~/conferences/queue -r architecture \
  -p ~/conferences/queue/prompts/r1-architecture.md -o r1-architecture.md \
  -m gpt-6-astra -e high -C ~/code/my-repo

codex-conference.sh wait -d ~/conferences/queue -t 540   # 0 = all done, 3 = still running, call again
codex-conference.sh status -d ~/conferences/queue
```

- Runs are **read-only**. The panelist's final message is saved as the output file.
- Done means `.runs/<role>.exit` exists. Logs are in `.runs/<role>.log`.
- An empty output counts as a failure even when codex exits 0.
- `CONF_TIMEOUT` sets the per-run limit (default 3600s).

Claude panelists run as background subagents and write their own files; their completion arrives as a notification, so there's nothing to poll.

## Files

```
skills/conference/SKILL.md      the process, cast, checkpoints
skills/conference/TEMPLATES.md  prompts for every round (header, round 0/1/2, moderator, fidelity, persona)
bin/codex-conference.sh         launch / wait / status for detached Codex runs
docs/waiting-for-detached-runs.md   the polling bugs this avoids
```

## Tips

- **Spend the effort on the research pack.** When every claim cites `brief-x §y`, claims can be checked, and panelists stay grounded.
- **Have each brief state which commit or version it read.** Correct stale briefs in `00-research-pack.md`.
- **Round 0 can end the conference early.** If the panelists show the premise is unproven, the right next step may be a small experiment, not more rounds.
- **Budget:** with a frontier model at high effort and a large research pack, expect 30–60 minutes per round.

## License

MIT
