---
id: US-0077
title: Results screen and bonus breakdown
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-06-UI-AUDIO, ADR-0004]
---

# US-0077 — Results screen and bonus breakdown

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-RESULTS` |
| **Systems** | `SYS-RESULTS` |
| **Estimate** | S |
| **Depends on** | US-0076 |

## Description

The teaching moment. Placement is the frame; the per-bonus breakdown is the purpose.

## Acceptance criteria

- [ ] Final placement and totals for all players.
- [ ] Per-player bonus breakdown: each type, count earned, points contributed.
- [ ] The breakdown is derived from the SAME fold as the totals, so they cannot disagree.
- [ ] Each player's persona, loadout and passive shown — retrospective kit-reading.
- [ ] Your killers by name and count. NO position, NO replay.
- [ ] Highest single kill of the match with its bonus stack, attributed.
- [ ] Time spent Anonymous per player, with the winner's highlighted.
- [ ] 25 s duration; skippable only by UNANIMOUS input.
- [ ] NO per-player timeline, path or heatmap — that is a kill-cam by another name.

## Test notes

`test_results_matches_scoreboard.gd` folds 100 random logs and asserts breakdown totals equal
scoreboard totals.

## Notes

The time-Anonymous line is the cheapest onboarding fix available: it makes the invisible skill
visible in the one place players are already comparing themselves.

Unanimous skip means one impatient player cannot deny another the teaching moment.
