---
id: US-0079
title: Match state machine and phases
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-09-08
depends_on: [GDD-07-BALANCE, TDD-10-SCORING]
---

# US-0079 — Match state machine and phases

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-MATCHFLOW` |
| **Systems** | `SYS-MATCH` |
| **Estimate** | M |
| **Depends on** | US-0077 |

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

## Why this is M5 and no longer waits on the lobby

**Moved 2026-09-08 by owner decision.** ADR-0016 priced this as the only single-story lever
that pulls the first playable match a milestone earlier, and asked for the stated dependency on
US-0078 to be **re-examined rather than assumed**. It was, criterion by criterion, and it does
not hold:

| This story asks for | What it actually needs |
|---|---|
| six phases and their transitions | tick arithmetic |
| 480 s, 30 s Final Contract, 5 s warning | tick arithmetic |
| the multiplier frozen at append from the event tick | **already built** — `ScoreEvent` derives it, and scoring was deliberately not blocked on `SYS-MATCH` |
| a pre-boundary initiation landing post-boundary at 1x | the phase clock |
| play down to four, below that end **with results shown** | `Net.player_count()`, and US-0077 — **already M5** |
| the cycle built at countdown, seed broadcast | `ContractSystem.open()`, built and Fisher-Yates on the seeded RNG, **called from tests only**; `NET-S2C-MATCH-START` already carries the seed field |

**What US-0078 provides is host-and-join, persona and loadout selection, and ready-up. None of
that appears above.** The one real coupling is the *trigger* for COUNTDOWN, and a minimum-player
rule is a trigger; the lobby replaces it later with ready-up rather than enabling it.

**AND THIS DOES NOT MOVE US-0098.** The M4 gate named four blockers for the human playtest and
the **lobby is one of them**. Whether a playtest can run on the direct-IP launch every session
here already uses is a **separate decision and the owner's** — it is not taken by this move, and
claiming otherwise is how a milestone quietly acquires work nobody agreed to.

**`snapshot.gd` IS AT 397 OF ITS 400 LINES**, and a match timer is a field. The split lands
before this story adds one.

## Notes

Every proposal to make the final phase MECHANICALLY different was rejected. Its job is to make
the last thirty seconds decisive without making them a different game. A player who spent seven
and a half minutes learning patience should be paid double for it, not have the skill
invalidated.
