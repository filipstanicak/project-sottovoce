---
id: US-0064
title: ScoreEvent log and the pure fold
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0004, TDD-10-SCORING]
---

# US-0064 — ScoreEvent log and the pure fold

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-SCORING` |
| **Systems** | `SYS-SCORE` |
| **Estimate** | M |
| **Depends on** | US-0063 |

## Description

Event-sourced scoring: an immutable append-only log, folded to produce the scoreboard.

## Acceptance criteria

- [ ] ScoreEvent is immutable — no setter, no mutating method.
- [ ] `ScoreLog.append` is the only entry point, server-only.
- [ ] `fold(events, tuning)` is PURE — no autoload, no scene, no clock.
- [ ] The final-phase multiplier is frozen at APPEND time from the event tick.
- [ ] A SCORE-DEATH marker event delimits lives.
- [ ] No code path assigns to a player score outside the fold.
- [ ] `breakdown()` groups by kind for the results screen.

## Test notes

`test_score_fold.gd` reproduces every reference value in GDD-07 section 3.2 exactly.
`test_score_no_direct_mutation.gd` is a source scan.
`test_multiplier_frozen.gd`: a kill initiated pre-boundary and landing post-boundary scores at 1x.

## Notes

A running integer fails four requirements at once: no per-bonus breakdown, no telemetry, score
becomes order-dependent on which system ran first, and it is nearly untestable. The classic
mitigation — a total plus a parallel stats dictionary — creates two sources of truth that
diverge, and the visible symptom is a results screen that adds up differently from the
scoreboard.
