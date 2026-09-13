---
id: US-0079
title: Match state machine and phases
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-09-13
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

- [x] Five phases — `LOBBY`, `WARMUP`, `ACTIVE`, `FINAL`, `RESULTS` — with the documented
      transitions, and the final warning as an **announcement** rather than a phase. —
      **Amended by owner decision 10 on 2026-09-13.** The line read *"All six phases"* from
      the day the story was written; `MatchPhase.Phase` has five members and their ordinals
      are the wire, so a sixth name for something the next criterion says changes no rules
      would have remapped every client's idea of what is happening. Built as
      `MatchClock.warning_at` and `MatchSystem.final_warning_announced` on 2026-09-08 and
      left unticked for five days rather than reworded, because rewriting a criterion to
      match what was built is the owner's call and not the builder's. See TDD-10 §6.2.
- [x] 480 s total; 30 s Final Contract; 5 s warning before it.
- [x] The warning changes NO rules — it exists so the phase is anticipated rather than sprung.
- [x] The Final Contract changes the score multiplier and NOTHING else.
- [x] Multiplier is frozen at ScoreEvent APPEND time from the event tick.
- [x] A kill initiated pre-boundary and landing post-boundary scores at 1x.
- [x] Play continues down to four players; below that the match ends WITH results shown.
- [x] Cycle built at countdown as a uniformly random permutation; seed broadcast. — **both
      halves as of 2026-09-13.** `MatchSystem.countdown_opened` is `ContractSystem.open`'s
      first caller under `scripts/`, and `NET-S2C-MATCH-START` has its first sender:
      `MatchAnnouncer.match_started` at the transition into `ACTIVE`, and `started_for` to a
      late joiner. The seed is sent at `ACTIVE` rather than at the countdown because
      `start_tick` does not exist before then, and the message is on `SESSION` so a late
      joiner cannot receive it before `NET-S2C-WELCOME`.

## Test notes

`test_finalphase_boundary.gd` for the initiation-time rule. **Built as
`test_the_score_origin_is_the_match_clock.gd`** instead, in
`test/unit/systems/combat/`, because the rule turned out to be about *which tick a score event is
stamped with* rather than about the boundary: `KillScoring` is where both moments are chosen, and
a file named after the boundary would have sat two directories from the code that decides it.
`test_a_kill_pressed_before_the_boundary_and_landing_after_it_pays_once` is the criterion.

The phase machine is `test/unit/systems/match/test_match_system.gd`; the hop onto the wire is
`test/unit/net/server/test_the_match_clock_reaches_the_wire.gd`.

## Why this is M5 and no longer waits on the lobby

**Moved 2026-09-08 by owner decision.** ADR-0016 priced this as the only single-story lever
that pulls the first playable match a milestone earlier, and asked for the stated dependency on
US-0078 to be **re-examined rather than assumed**. It was, criterion by criterion, and it does
not hold:

| This story asks for | What it actually needs |
|---|---|
| six phases and their transitions — five and an announcement since decision 10 | tick arithmetic |
| 480 s, 30 s Final Contract, 5 s warning | tick arithmetic |
| the multiplier frozen at append from the event tick | **already built** — `ScoreEvent` derives it, and scoring was deliberately not blocked on `SYS-MATCH` |
| a pre-boundary initiation landing post-boundary at 1x | the phase clock |
| play down to four, below that end **with results shown** | `Net.player_count()`, and US-0077 — **already M5** |
| the cycle built at countdown, seed broadcast | `ContractSystem.open()`, built and Fisher-Yates on the seeded RNG, called at the countdown since 2026-09-08; `NET-S2C-MATCH-START` sent since 2026-09-13 — `MatchStartWire`, `MatchAnnouncer.match_started`, `GameState.adopt_match` |

**What US-0078 provides is host-and-join, persona and loadout selection, and ready-up. None of
that appears above.** The one real coupling is the *trigger* for COUNTDOWN, and a minimum-player
rule is a trigger; the lobby replaces it later with ready-up rather than enabling it.

**AND THIS DOES NOT MOVE US-0098.** The M4 gate named four blockers for the human playtest and
the **lobby is one of them**. Whether a playtest can run on the direct-IP launch every session
here already uses is a **separate decision and the owner's** — it is not taken by this move, and
claiming otherwise is how a milestone quietly acquires work nobody agreed to.

**AND THE CLAIM THAT THE SNAPSHOT SPLIT BLOCKED THIS STORY WAS WRONG.** This section said
*"`snapshot.gd` is at 397 of its 400 lines, and a match timer is a field"* — measured on
2026-09-08 and false: the format has carried **`phase`, `ticks_remaining` and `multiplier` since
M0**. This story adds no field; it adds the first *writer* for two of them. The split (PR #214)
was worth making on its own terms and was never a prerequisite here, and the urgency was
invented. Corrected rather than deleted, because a claim that quietly vanishes is one nobody can
check.

## Notes

Every proposal to make the final phase MECHANICALLY different was rejected. Its job is to make
the last thirty seconds decisive without making them a different game. A player who spent seven
and a half minutes learning patience should be paid double for it, not have the skill
invalidated.
