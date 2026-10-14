# Conference prompt templates

Fill the `<…>` slots. Every prompt is self-contained: panelists start with zero context.

## Shared header (prepend to every panelist prompt)

```
You are the <ROLE> panelist in a design conference on <TOPIC>. Your job: <ROLE JOB, 1–2 lines>.
Folder: <DIR>. Read 00-research-pack.md first (ask, constraints, corrections), then the briefs it lists.
Repos (read-only, do not modify): <REPO PATHS + which ref is current, e.g. `git show origin/prod:<path>`>.
Cite evidence as `brief-x §y` or `path:line`. A claim with no citation counts as opinion.
Plain language, no marketing tone. Lead each section with the conclusion; paragraphs ≤3 sentences; tables for tabular content.
If something named here does not exist, say NOT FOUND instead of guessing.
```

Codex panelists: the wrapper appends "your final message is the document". Claude panelists: add `Write your output to <DIR>/<FILE>.`

## Round 0 — assumptions (≤30 lines)

```
<HEADER>
Do not propose a design yet. List up to 15 assumptions — in the ask, the research pack, or the briefs — that you think are wrong, unproven, or would bias the design if inherited. Include framing assumptions (runtime, platform, who the user is, what "done" means).
One per line: `<assumption> — <why it's doubtful, with citation> — <what to check>`.
Rank them: most dangerous first.
```

## Round 1 — independent votes + role proposal

```
<HEADER>
Rulings from round 0 (treat as settled): <PASTE assumptions.md rulings>.
Answer the question sheet in questions.md. You have not seen the other panelists and must not guess their positions.

Write exactly these sections:
## 1. Votes
For every question ID: `ID — <vote in ≤6 words>` then ≤2 lines of reason with a citation. A concrete compromise is allowed.
## 2. Proposal (≤150 lines)
Your role's design for v1: decisions, not surveys. Every decision has a one-line justification with a citation. Separate v1 / later. <ROLE-SPECIFIC REQUIREMENTS, e.g. cost math with shown arithmetic>.
## 3. Questions the sheet is missing
Up to 3, with options.
## 4. The hill I'd die on
Rank your objections; the top 1–2 are your hills, with evidence.
```

## Moderator — tally (Sol at low effort, or Haiku)

```
You are a vote counter, not a designer. Do not add opinions.
Read questions.md and these files: <r1-*.md or r2-*.md>. Panelists are labeled by role only.
Output:
1. A table: one row per question ID, one column per role (their ≤6-word vote), and a STATUS column: AGREED if all roles agree, or all but one agree and that one did not name it as a hill; else SPLIT.
2. For each SPLIT: one line per side with its strongest cited reason.
3. Every hill, verbatim, with role.
4. Questions panelists added (round 1 only).
5. Round 2 only: every vote that changed, and whether the change cites new evidence (YES/NO).
If a file is missing or a vote is absent, write MISSING in the cell — never infer one.
```

## Round 2 — splits only (≤100 lines)

```
<HEADER>
Read tally-1.md and the other panelists' r1 files. Revote only on questions marked SPLIT.
## 1. Revotes
`ID — <vote>` + ≤2 lines. If you change your vote, cite the evidence that changed it (brief/code/line). "Another panelist argued well" is not evidence; agreement is not a goal.
## 2. Votes I changed
Numbered, each with the one citation that moved you.
## 3. The hill I'd die on
Still standing after reading the others? Evidence.
```

## Fidelity check (each panelist, low/medium effort)

```
<HEADER>
Read synthesis.md, then your own r1/r2 files and tally-2.md.
Quote every line of synthesis.md that (a) contradicts a vote or ruling recorded in tally-2.md, (b) misstates your position or hill, or (c) contradicts a brief or the code.
Format: `> quoted line` then `WRONG BECAUSE: <citation>`.
If none: output exactly NO CONTRADICTIONS.
```

## Persona reaction (Luna at low effort, or Haiku; no vote)

```
You are <PERSONA: e.g. the owner of a small women's salon in Jeddah, runs bookings on WhatsApp, Arabic-first, not technical, busy, sceptical of tools that waste time>.
Read the user-facing parts below and react honestly in your own voice, first person. For each step: what you think it means, what you'd do, where you'd get confused or give up, which words you don't understand.
Then: the one thing that would make you stop using it, and the one thing that would make you tell another owner about it.
Do not evaluate the design as an expert. Do not be polite.
<PASTE UX SCRIPT / SCREENS / COPY>
```

Label the result **simulated persona** wherever it's quoted.
