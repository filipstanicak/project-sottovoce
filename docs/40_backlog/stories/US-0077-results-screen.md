---
id: US-0077
title: Results screen and bonus breakdown
version: 0.1.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-09-08
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


## Implementation status, 2026-09-08

Presentation work is in progress. Phase changes use the existing HudBridge /
EventBus signal. Match `ticks_remaining` must not drive a results countdown.
The view model will use ScoreFold for both totals and breakdowns.

The delivery seam is not implemented yet: NET-S2C-MATCH-END and
NET-C2S-SKIP-RESULTS exist in the protocol catalogue but have no handlers.
The live score feed sends only the recipient's awards and omits SCORE-DEATH;
it cannot supply all-player results. Names, complete kits and authoritative
Anonymous durations also need an end-of-match payload. The server-owned log
must not be held by presentation (test_score_no_direct_mutation.gd).
Ownership of that transport is being clarified before extending the stated
presentation-only scope. No acceptance criterion is complete yet.
