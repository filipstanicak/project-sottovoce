---
id: US-0106
title: The hunter picks the figure
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-10-02
depends_on: [ADR-0025, US-0103]
---

# US-0106 — The hunter picks the figure

| | |
|---|---|
| **Milestone** | M6 road (ROADMAP §8.3) |
| **Epic** | `EPIC-COMBAT` |
| **Systems** | `SYS-KILL`, `SYS-DETECTION`, `SYS-CROWD`, `SYS-SCORE`, `SYS-NET-*` |
| **Estimate** | L — five to eight PRs |
| **Depends on** | ADR-0025 (accepted); **US-0103 first**, by owner decision |

## Description

**Owner decision 14, 2026-10-02: exactly as the reference.** Today the kill button picks the
nearest *player* and the lock outlines the true body, so the server answers *which of the
identical figures is the human* for the hunter. In the reference the hunter picks the figure, a
civilian killed instead costs the contract, and the lock confirms nothing. ADR-0025 records the
rule and its cost; this story builds it.

**No rule of ours fills a gap.** Every detail ADR-0025 lists under *To source before building*
is sourced, with the source named in the PR (never in the repo, never-do #5), before the part
that depends on it is built.

## Acceptance criteria

- [ ] ADR-0025's source questions A–H are answered from the reference, each recorded here with
      what it decides.
- [ ] Item I — the lock symbol over a running player — is sourced **and then accepted or rejected
      by the owner**, because it is a marker over a body that never-do #12 governs. Nothing of it
      is built before that ruling.
- [ ] The kill goes to the selected figure — the locked one, otherwise the reference's own
      targeting — player or civilian. `KillRules` no longer chooses the nearest player.
- [ ] A civilian can be killed. Killing one costs the hunter the contract and reveals their
      position to the other players as the reference shows it (A). What it scores (G) and how the
      crowd reacts (H) are as sourced — nothing of ours fills either.
- [ ] The prey whose persona the killed civilian wore, within the sourced radius, is paid the
      reference's bonus and told *your pursuer killed a civilian* (US-0105's line).
- [ ] The lock is a targeting act with the reference's two input paths — a press locks a figure in
      immediate sight, a hold aims at one at distance — as C sources them,
      the kill goes to the locked figure, and the lock confirms nothing: the reveal of the true
      body is gone. Any other action it governs is as sourced (F). `SCORE-FOCUS` still pays a
      charged lock on the contract.
- [ ] The kill ring lights for any selected figure in reach and never tells the contract from a
      clone. Asserted the way `test_the_stun_hint_names_nobody.gd` asserts the stun hint.
- [ ] The dash meets civilians as the reference's does.
- [ ] The selection travels as a selection, not as an outcome; the server rewinds and judges
      reach, cone and sight as today. NPCs are recorded in the lag-compensation ring, which
      closes US-0035's and US-0060's NPC criteria. `PROTOCOL_VERSION` 8.
- [ ] GDD-03 §8 and §10, ADR-0010/0013/0015/0021, UI_UX_SPEC, NETWORK_PROTOCOL and the glossary
      say the new rule; the old wording is kept and marked.

## Test notes

The first test is the property the decision is about: a contract standing among clones of its
persona, the kill pressed at a clone, **the clone dies and the hunter loses the contract**. Its
counterpart: the same press at the contract kills the contract. And the anonymity property: the
kill ring reads the same on the contract and on a clone at the same spot.

## Notes

Waits on US-0103 by owner decision: a crowd that sits and gathers gives the read something to
work with, and without animation a human is told from a clone almost only by behaviour.
