---
id: ADR-0004
title: Scoring as event sourcing
version: 1.0.0
status: accepted
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0002, TUN-INDEX]
supersedes: none
---

# ADR-0004 — Scoring as event sourcing

## Context

The scoring system has properties that are unusual for a small game:

- **Twelve stackable bonuses**, several with conditions evaluated over a time window
  (`SCORE-PATIENT` over 10 s, `SCORE-FOCUS` over 6 s, `SCORE-LONGHUNT` over 20/45 s).
- **One bonus (`SCORE-VARIETY`) depends on the player's history within the current life** —
  it pays for bonus types not yet earned since the last death.
- **A late-match multiplier** (`TUN-MATCH-FINALPHASE-MULT`) that applies to events by
  timestamp.
- **The results screen is the game's primary teaching moment.** It must show a per-player
  breakdown of *which* bonuses were earned and how often. If the runtime only keeps a
  running integer, that screen cannot be built without a parallel bookkeeping system that
  will inevitably disagree with the integer.
- **Balance is falsifiable only if the data exists.** The telemetry plan
  ([`../../10_gdd/07_balance.md`](../../10_gdd/07_balance.md) §8) needs per-bonus frequency,
  not totals.

The naive implementation — `player.score += bonus_value` scattered across the kill, stun and
match systems — fails all four. It is also nearly impossible to unit-test, because the score
becomes a function of the order in which systems happened to run.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Event sourcing: append immutable `ScoreEvent`s; the scoreboard is a fold over the log** | Score is a pure function of the log, so it is unit-testable without a game running; the results breakdown is free; telemetry is the log; the final-phase multiplier is applied at fold time from timestamps; replay and audit are free. | Memory grows with the match (bounded — see below); one extra indirection between "something happened" and "the number changed". | **Chosen** |
| Mutable running total | Simplest possible. | Untestable in isolation; no breakdown; no telemetry; the multiplier must be applied at award time, which makes it order-dependent; a bug produces a wrong number with no way to find out why. | Rejected |
| Running total + parallel stats dictionary | Gives the breakdown. | Two sources of truth that will diverge. The classic version of this bug ships in a lot of games: the results screen adds up to a different number than the scoreboard. | Rejected |
| Full event sourcing across *all* game state | Maximal consistency; time-travel debugging. | Enormous over-engineering for a project of this size. Movement and suspicion do not need an audit trail. | Rejected |

## Decision

**Every scoreable action appends an immutable `ScoreEvent` to a server-owned, append-only
log. The scoreboard, the score feed and the results screen are all folds over that log.**

```gdscript
## An immutable record of one scoreable action. Never mutated after construction.
class_name ScoreEvent
extends RefCounted

var event_id: int            # monotonic, server-assigned
var tick: int                # server tick at which it occurred
var kind: StringName         # SCORE-CONTRACT, SCORE-BLENDED, ... (see NAMING_AND_IDS.md)
var actor_id: int            # peer id who earned it
var subject_id: int          # peer id it was earned against (0 if none)
var base_points: int         # pre-multiplier
var multiplier: float        # 1.0, or TUN-MATCH-FINALPHASE-MULT
var group_id: int            # events from one kill share a group_id, for feed grouping
```

Rules:

1. **The log is append-only.** No event is edited or removed after append. A correction is
   a new, compensating event, never a mutation.
2. **`base_points` comes from `ScoringTuning`**, never a literal (ADR-0005).
3. **The multiplier is resolved at append time from the event's `tick`**, not at fold time —
   because the multiplier depends on match phase, which is a property of *when it happened*,
   and freezing it makes the fold a pure sum.
4. **The fold is a pure function** with no access to the scene tree:
   `fold(events: Array[ScoreEvent]) -> Dictionary[int, PlayerScore]`.
5. **`SCORE-VARIETY` is computed at append time**, not at fold time, by consulting the
   actor's events since their last `SCORE-DEATH` marker. This keeps the fold pure and makes
   the Variety count itself auditable in the log.
6. **The client receives events, not totals.** `NET-S2C-SCORE-EVENT` streams events; the
   client folds them locally for the HUD. This makes the score feed trivially correct: the
   feed *is* the event stream.
7. **The log is bounded by construction**: at most ~6 players × ~6 kills × ~8 bonuses × 2
   (stuns, deaths) ≈ 600 events per match, at ~40 bytes each. Memory is not a concern and
   no pruning is needed.

## Consequences

### Positive
- `test_score_fold.gd` can assert exact scores for hand-written event logs, with no engine,
  no network and no scene. The most bug-prone part of the design becomes the most testable.
- The results screen is a `group_by(kind)` over the log. It cannot disagree with the
  scoreboard because it is derived from the same data.
- The telemetry export is `JSON.stringify(log)`. No separate instrumentation to maintain,
  and no risk that telemetry measures something different from what the game scored.
- Replaying a match's scoring after a tuning change is possible: re-fold an old log with new
  `ScoringTuning` values and see what the match *would have* scored. This makes the balance
  model falsifiable against real matches, which is the entire point of
  [`../../50_tuning/BALANCE_MODEL.md`](../../50_tuning/BALANCE_MODEL.md).
- The score feed's `TUN-UI-SCOREFEED-STAGGER` presentation (bonuses arriving in sequence)
  falls out of `group_id` naturally.

### Negative — stated honestly
- One extra layer. `award()` is not `+=`. A developer in a hurry will be tempted to add a
  direct mutation; the compliance check below exists specifically to catch that.
- Freezing the multiplier at append time (rule 3) means a late change to
  `TUN-MATCH-FINALPHASE-MULT` mid-match would not retroactively apply. This is correct
  behaviour but is surprising the first time you see it.
- `SCORE-VARIETY` being computed at append time (rule 5) is an exception to the "the fold
  does the work" principle, and exceptions invite more exceptions. It is justified because
  Variety is the only bonus whose value depends on prior events; making the fold stateful to
  accommodate one bonus would cost more than this exception does.
- Streaming events rather than totals costs slightly more bandwidth. Negligible: ~600 events
  per match across all clients.

### Neutral / follow-on
- A `SCORE-DEATH` marker event (0 points) is appended on every death purely to delimit lives
  for the Variety computation. It is a real event with real semantics, not a hack — the
  results screen shows deaths from it too.

## Compliance

- [ ] `grep -rn "score +=\|score = score\|\.score\b.*=" scripts/` finds no assignment to a
      player's score outside `ScoreLog.fold()`.
- [ ] `ScoreEvent` has no setter and no mutating method.
- [ ] `ScoreLog.append()` is the only way an event enters the log, and it is server-only.
- [ ] `ScoreLog.fold()` takes only an `Array[ScoreEvent]` and a `ScoringTuning`. It
      references no autoload, no scene, and no clock.
- [ ] `test_score_fold.gd` covers: every bonus in isolation; the maximal stack; the final-
      phase multiplier; `SCORE-VARIETY` across a death boundary; `SCORE-RECKLESS` producing
      a net-positive-but-small kill; and an empty log producing zeroes.
- [ ] The results screen reads only from a fold, never from a running counter.

## Revisit trigger

Reopen if a scoring rule appears that genuinely cannot be expressed as a fold — for example
a bonus that depends on *other players'* future actions. None such exists in the MVP set,
and if one is proposed, that is itself worth examining before the architecture is.
