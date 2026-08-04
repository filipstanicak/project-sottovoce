---
id: US-0079
title: Match state machine and phases
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-07-BALANCE, TDD-10-SCORING]
---

# US-0079 — Match state machine and phases

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-MATCHFLOW` |
| **Systems** | `SYS-MATCH` |
| **Estimate** | M |
| **Depends on** | US-0078 |

## Description

Lobby, countdown, playing, final warning, Final Contract, results — driven by tick counts, never
wall time.

## Acceptance criteria

- [ ] All six phases with the documented transitions.
- [ ] 480 s total; 30 s Final Contract; 5 s warning before it.
- [ ] The warning changes NO rules — it exists so the phase is anticipated rather than sprung.
- [ ] The Final Contract changes the score multiplier and NOTHING else.
- [ ] Multiplier is frozen at ScoreEvent APPEND time from the event tick.
- [ ] A kill initiated pre-boundary and landing post-boundary scores at 1x.
- [ ] Play continues down to four players; below that the match ends WITH results shown.
- [ ] Cycle built at countdown as a uniformly random permutation; seed broadcast.

## Test notes

`test_finalphase_boundary.gd` for the initiation-time rule.

## Notes

Every proposal to make the final phase MECHANICALLY different was rejected. Its job is to make
the last thirty seconds decisive without making them a different game. A player who spent seven
and a half minutes learning patience should be paid double for it, not have the skill
invalidated.
