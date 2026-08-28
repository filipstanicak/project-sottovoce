---
id: US-0064
title: ScoreEvent log and the pure fold
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-28
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

- [x] ScoreEvent is immutable — no setter, no mutating method.
      **In the engine, not in a comment.** Every field is a getter-only property
      over a private backing value, so `event.tick = 9` is a parse error and
      `event.set("tick", 9)` is silently refused — which is what the test asserts,
      because the assignment a careless commit would write cannot compile and
      therefore cannot be reached by a test.
- [x] `ScoreLog.append` is the only entry point, server-only.
      `mark_death` goes through it. **The one place a `TUN-SCORE-` float becomes an
      integer**, so a scoreboard and a breakdown cannot round apart by a point.
      Server-only is a guard rather than a folder: `presentation/`, `mirrors/`,
      `pawn/` and `net/client/` may not name `ScoreLog`.
- [x] `fold(events, tuning)` is PURE — no autoload, no scene, no clock.
      **Pure, and it takes no tuning — TDD-10 §1.3 is amended.** The points are
      frozen on the event by §1.2, so a fold that re-read `ScoringTuning` could
      produce a different total from the one the feed already showed. That is the
      two-sources-of-truth defect §1.1 exists to prevent. Purity is asserted
      structurally as well: no `Tuning.`, `Net.`, `EventBus`, `get_node`,
      `get_tree` or `Time.` anywhere in the file.
- [x] The final-phase multiplier is frozen at APPEND time from the event tick.
      Derived inside `ScoreEvent._init` from the tick, so **no event can exist
      whose multiplier disagrees with its own tick**. A kill pressed one tick
      before the boundary and landing `TUN-KILL-CORPSE-SPAWN-DELAY` later pays 1×.
      The boundary is computed from `TUN-MATCH-DURATION` and
      `TUN-MATCH-FINALPHASE-DURATION`, so **scoring is not blocked on `SYS-MATCH`**
      — but the tick is the *match* tick, and until US-0079 owns a match clock the
      server's own tick is all there is.
- [x] A SCORE-DEATH marker event delimits lives.
      A real event worth zero, keyed on the **victim** as actor. Another player's
      death does not end your life, which is the counterfactual that keeps
      `SCORE-VARIETY` from resetting on every kill in the match.
- [x] No code path assigns to a player score outside the fold.
      `test_score_no_direct_mutation.gd`, falsified against a `_score += 1` planted
      in `SuspicionSystem` — it names the file and the line. **Its first
      counterfactual was wrong**: it scanned `ScoreFold` for the same needles and
      went red on correct code, because the fold accumulates into a dictionary
      rather than with `+=`. It folds two events and checks the sum now.
- [x] `breakdown()` groups by kind for the results screen.
      **Sums rather than counts**, because two `SCORE-LONGHUNT` rungs pay different
      amounts under one id. Asserted to add up to the scoreboard, which is the
      defect TDD-10 §1.1 names by name.

## Test notes

`test_score_fold.gd` reproduces every reference value in GDD-07 section 3.2 exactly.
`test_score_no_direct_mutation.gd` is a source scan.
`test_multiplier_frozen.gd`: a kill initiated pre-boundary and landing post-boundary scores at 1x.

## What this story does NOT do

**Eleven of the twelve bonuses are US-0065's.** `SYS-KILL` appends exactly two
events today: `SCORE-CONTRACT` on every kill — unconditional, because this game
has no kill that is not on the announced contract — and the `SCORE-DEATH` marker.
Everything else is judged at *initiation* against state the kill handler no longer
holds, and guessing at it here would have been the wrong kind of head start.

`SCORE-VARIETY` is the one bonus computed at append time (TDD-10 §1.4). The query
it needs, `ScoreFold.since_last_death`, is built and tested here; the bonus is not.

**`server_root.gd` passed 400 lines and was split** (never-do #6). The seam is
*boot* versus *announcements*: `MatchAnnouncer` owns every message the server
sends and is **the one place a peer id becomes a wire slot**, which is a rule the
file was already asserting in three separate comments. 419 → 339 lines.

## Notes

A running integer fails four requirements at once: no per-bonus breakdown, no telemetry, score
becomes order-dependent on which system ran first, and it is nearly untestable. The classic
mitigation — a total plus a parallel stats dictionary — creates two sources of truth that
diverge, and the visible symptom is a results screen that adds up differently from the
scoreboard.
