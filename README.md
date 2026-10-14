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

## Why it's shaped this way

The first version of this was a free-form "conference": four models wrote position papers, read each other's work, and wrote rebuttals. It worked, but:

| What went wrong | What the skill does instead |
|---|---|
| ~6,000 lines of papers to settle 26 questions | **Questions first, votes first.** A vote is ≤6 words + 2 lines + a citation. |
| Every panelist inherited the first paper's framing (a wrong runtime assumption no one questioned) | **Round 0**: each panelist lists assumptions to attack *before* anyone proposes anything. A human rules on them. |
| Synthesis by one model after reading 8 papers lost detail (7 errors) | A **moderator** turns votes into a table; synthesis starts from the table. A **fidelity check** sends the synthesis back to every panelist. |
| The orchestrator spent hours waiting on a broken polling loop | A **wrapper** that launches Codex runs detached and waits on an exit file, never a pid or `pgrep` (see [docs/waiting-for-detached-runs.md](docs/waiting-for-detached-runs.md)). |
| Nobody spoke for the end user | A cheap model plays a **persona** (labeled *simulated*, no vote). |

Research behind the rules:

- **Max two voting rounds, and agreement isn't proof.** In multi-agent debate, disagreement collapses as rounds go on, and that convergence often tracks *worse* answers because agents defer to each other ([Yao et al. 2025](https://arxiv.org/abs/2509.23055v1); [CONSENSAGENT, ACL Findings 2025](https://preview.aclanthology.org/new-sigs/2025.findings-acl.1141/)). Leftover splits go to the human, not to a round 3.
- **A changed vote must cite evidence.** "Another panelist argued well" doesn't count.
- **Debate is not magic.** It often fails to beat simpler baselines for the compute it uses ([Cui et al.](https://arxiv.org/abs/2502.08788v3)). The value here is *different blind spots* plus *structured human decisions*, not the debate itself.
- **Mixed models help, but weak voters drag.** Mixing model families finds different holes; mixed results show weaker agents can hurt the group ([M3MAD-Bench](https://arxiv.org/pdf/2601.02854)). Cheap models get side jobs (tally, persona), not votes.
- **Panelists are labeled by role, not by model**, to reduce anchoring on the best-known model (as in [Language Model Council](https://arxiv.org/abs/2406.08598v4)).
- The round structure is borrowed from Delphi, which has been run with LLM panels ([Scalable Delphi, 2026](https://arxiv.org/html/2602.08889v1)).

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

You are asked at four points only: after round 0, after the question sheet, on the final splits, and at the end.

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

## Tips from real runs

- **Spend the effort on the research pack.** When every claim cites `brief-x §y`, you can check claims, and panelists stay grounded.
- **Ask each brief to state which commit it read.** One stale checkout poisoned a whole brief in the first run.
- **"The hill I'd die on"** is the most useful section: it makes each panelist rank its own objections.
- **Round 0 may end the conference early.** In one run, all four panelists independently showed the core premise rested on a single 3-sample test. The right next step was a small experiment, not two more rounds.
- Budget: a 4-panelist run with a frontier model at high effort takes 30–60 minutes per round on a large research pack.

## License

MIT
