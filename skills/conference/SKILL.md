---
name: conference
description: Run a design conference of several agents (Claude subagents, optionally mixed with Codex CLI agents) to settle a hard design question with many open decisions. Research pack → assumptions round → independent votes → moderator tally → revote on splits only → synthesis → fidelity check, plus a cheap customer-persona reaction. Use when the user asks for a conference, panel, debate, red team + design round, or "get several models to argue this out". Not for code review (codex-review) or quick lookups (codex).
---

# Agent conference

Several models with different jobs answer the **same question sheet**, see each other's votes, and revote only on the splits. You (the orchestrator) prepare inputs, tally, and synthesize, and **the user rules on anything still split**.

Rules:
- **Votes before papers.** A vote sheet, not an essay.
- **Max two voting rounds.** Agreement isn't proof. Leftover splits go to the user, not to a round 3.
- **A changed vote must cite evidence.** "P2 convinced me" is not a reason; `brief-x §y` is.
- **Feed back roles, not model names.**
- **Cheap models get side jobs** (persona, tally), not votes.

## Cast (adjust to the question)

Two setups. Use **mixed** when `codex` is installed and logged in (`codex --version`); otherwise use **Claude only**.

**Mixed (Claude + Codex)**

| Role | Runs on | How |
|---|---|---|
| architecture | Codex `gpt-6-astra`, high | wrapper |
| ux / customer empathy | Claude Opus subagent | Agent tool |
| quality / domain | Claude Fable subagent | Agent tool |
| red team | Claude Fable subagent | Agent tool |
| moderator (tally only) | Codex `gpt-6-sol`, low | wrapper |
| customer persona (no vote) | Codex `gpt-6-luna`, low | wrapper |

**Claude only**

| Role | Runs on | How |
|---|---|---|
| architecture | Claude Opus subagent | Agent tool |
| ux / customer empathy | Claude Sonnet subagent | Agent tool |
| quality / domain | Claude Fable subagent | Agent tool |
| red team | Claude Opus subagent | Agent tool |
| moderator (tally only) | Claude Haiku subagent | Agent tool |
| customer persona (no vote) | Claude Haiku subagent | Agent tool |

One model family means more shared blind spots. To make up for it:
- **Give each voting seat a different model** where you can, and never two seats the same role.
- **Give each role its own evidence lane.** For example, the red team cites code only and quality cites the external research only. Different inputs produce different objections.
- **Take round 0 seriously.** Ask every panelist for at least 3 assumptions that the briefs themselves take for granted.

## Folder

One folder per conference, e.g. `~/conferences/<topic>/`:
`00-research-pack.md`, `brief-*.md`, `assumptions.md`, `questions.md`, `r1-<role>.md`, `tally-1.md`, `r2-<role>.md`, `tally-2.md`, `synthesis.md`, `fidelity-<role>.md`, `persona.md`.

## Steps

1. **Research pack.** The ask, constraints, corrections, and one brief per area (Explore/general agents). Every brief states which checkout/commit it read. A stale brief gets a correction line in the pack. Panelists cite `brief-x §y`.
2. **Round 0, assumptions (cheap, short).** Each panelist writes ≤30 lines: "assumptions in this pack or the ask that I'd challenge". Merge them into `assumptions.md`. **Stop and show the user** and let them strike or confirm each one. Framing errors get caught here, before every panelist inherits them.
3. **Write `questions.md`.** 15–30 questions grouped by area. Each has concrete options and an ID (A1, B3…). Show it to the user before round 1.
4. **Round 1, independent.** Each panelist writes `r1-<role>.md` without seeing the others: vote sheet (≤6 words + ≤2 lines + citation per question), ≤150 lines of role-specific proposal, open questions, and "the hill I'd die on" (ranked).
5. **Tally 1.** Moderator turns the vote sheets into `tally-1.md`: one row per question, one column per role, marked **AGREED** (all, or all but one with no hill on it) or **SPLIT**, plus every hill.
6. **Round 2, splits only.** Each panelist reads `tally-1.md` and the other r1 files, then writes `r2-<role>.md` (≤100 lines): a revote on SPLIT questions only, "votes I changed + the evidence", and the hill. Then **Tally 2**.
7. **User rules** on what's still SPLIT. Show it as a table with each side's best evidence. No round 3.
8. **Synthesis.** You write `synthesis.md` from `tally-2.md` plus the rulings. Go back to the papers only for detail a decision needs.
9. **Fidelity check (always, not improvised).** Each panelist gets the synthesis: "quote every line that contradicts your votes, your hills, or a brief". Fix what holds up.
10. **Persona reaction.** A cheap model (Luna or Haiku) plays the end customer (e.g. a salon owner in Jeddah) and reacts to the user-facing parts. Label its output **simulated**. It catches jargon and confusing steps; it is not user research.

Prompt templates for each step: `TEMPLATES.md` in this folder.

## Running panelists

**Codex** (Astra/Sol/Luna), via `codex-conference.sh`. It runs read-only and the final message becomes the file:

```bash
codex-conference.sh launch -d ~/conferences/x -r architecture -p ~/conferences/x/prompt-r1-architecture.md -o r1-architecture.md -m gpt-6-astra -e high -C ~/code/my-repo
```

```bash
codex-conference.sh wait -d ~/conferences/x -t 540
```

- `wait` blocks up to `-t` seconds (keep it under the 10-minute tool timeout). Exit 0 means everything is done; exit 3 means still running, so call it again.
- `status` prints each run without waiting.
- Done = the `.runs/<role>.exit` file exists; logs are in `.runs/<role>.log`. A run that exits 0 with an empty output counts as `exit=1`.
- Never wait with `pgrep -f`, a bare `setsid` pid, or file size (see `docs/waiting-for-detached-runs.md` in the repo).
- Timeout per run: `CONF_TIMEOUT` (default 3600s). Astra at high on a big pack can take 30–60 minutes.

**Claude** (Opus/Sonnet/Fable/Haiku): use the Agent tool with `model` set, run in the background, and tell it the exact output path to write. Completion arrives as a notification, so no polling is needed.

Launch every panelist of a round in one turn, then wait for codex while the Claude notifications arrive. Claude only: launch them all in the background in one turn and wait for the notifications. `codex-conference.sh` isn't needed.

Moderator and persona as Claude subagents: same Agent call, with `model` set to Haiku. Give the moderator only the files it tallies, and tell it to write `tally-N.md`.

## Checkpoints with the user

After round 0 (assumptions), after `questions.md`, after tally 2 (rulings), and when the synthesis passes fidelity. Nothing else needs them.
