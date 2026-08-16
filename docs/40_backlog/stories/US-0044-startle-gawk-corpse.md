---
id: US-0044
title: Startle propagation, gawk and corpses
version: 0.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-16
depends_on: [TDD-08-CROWD, GDD-03-SOCIAL-STEALTH]
---

# US-0044 — Startle propagation, gawk and corpses

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-BEHAVIOUR` |
| **Systems** | `SYS-CROWD`, `SYS-CORPSE` |
| **Estimate** | M |
| **Depends on** | US-0043 |

## Description

Startle waves with probabilistic propagation, token-capped gawk clusters, and corpses as
information objects.

## Acceptance criteria

> **Six of seven. The one that is open needs a human at a windowed client**, and there are no
> NPC meshes to look at until US-0046.

- [x] **Violence startles within 12 m; a sprinting player within 5 m, evaluated once per second.**
      Both radii and the cadence are implemented and asserted.
      `TUN-CROWD-STARTLE-SPRINT-INTERVAL` is new, carrying GDD-03 §6.4's own "once per second,
      not per tick". **The sprint half runs in a live match**; the violence half has an entry
      point and no caller until `SYS-KILL` and `SYS-STUN` at M4, and the story says so.
- [x] **Propagation at 0.4 probability within 5 m, capped at TWO hops by a per-agent flag.**
      Round one is the radius, round two is whoever round one scares, and round two does not
      propagate. Measured on a line of NPCs a metre apart: a 3 m wave reaches 5 m, against a
      two-hop ceiling of 8.
- [ ] **Startle waves read directionally to a human observer, not as a circle.** **Blocked on an
      observer.** The mechanical half is asserted — 13 of 13 startled NPCs were sent away from
      the violence, so the flee vectors diverge from one point and it is recoverable — but
      "reads to a human" needs rendered clones and an owner at a windowed client. NPC meshes are
      **US-0046**. Treated like M1's feel gate: measured, recorded, not ticked.
- [x] **Gawk tokens capped at 6; fleeing NPCs are skipped.** Nearest first, `STARTLE` skipped
      because `NpcBrain.TRANSITIONS` would silently ignore the token anyway and the cluster would
      come up short with nothing saying why.
- [x] **A corpse beside a six-anchor pocket never drops it below four NPCs.** Twelve NPCs in a
      pocket, **twelve of them eligible against a cap of six**, six left standing. The
      counterfactual is asserted first: with fewer NPCs in range than the cap allows, the test
      would prove nothing about the cap.
- [x] **Corpse persists 20 s; gawk cluster disperses at 6 s — two distinct information phases.**
      Invariant 13 in numbers: gathering at 5 s and not at 7; not expired at 19 s and expired at
      21.
- [x] **NPC flee speed is below player sprint speed, asserted as an invariant.** Invariant 14,
      already asserted in `test_tuning_ranges.gd`; repeated in the crowd's own suite because the
      consequence belongs where the crowd code is read — a sprinting player who could outrun a
      wave could hide *inside* one, using the crowd's own alarm as cover.

## What a wave costs, and what it is allowed to reach

**Two rounds, and the second does not propagate.** GDD-03 §6.4's pseudocode is recursive — every
startled NPC propagates once — which caps each *agent* but not the *wave*: on a dense enough
crowd it would walk to the canal. TDD-08 §3.2 already claims "capped at two hops", so the
implementation is two explicit rounds and the reach is asserted: a 3 m wave reaches 5 m against a
ceiling of 3 + `TUN-CROWD-STARTLE-RADIUS-SPRINT`.

**`has_propagated` clears when the fleeing stops, not when it starts.** Set once per wave so an
NPC cannot scare its neighbours twice; kept while it is still running, so a re-startle buys no
second round; cleared on the way out of `STARTLE`. Left uncleared — which is what it was before
this story, since `NpcBrain.reset()` was the only thing that touched it — an NPC would propagate
exactly once per **match**, and the crowd would grow quieter as the match went on with nothing
anywhere reporting it.

**Already-fleeing NPCs are not counted as a fresh hop.** Re-startling one is legal and restarts
its timer, deliberately; letting it seed another round would turn two overlapping waves into a
chain with no cap at all.

## "Sprinting" is read from speed, not from a state name

A pawn's state lives on `PawnContext`, which a `GameSystem` cannot reach — only what is on
`MatchContext` is reachable, and pawn state lands there with `SYS-SUSPICION` (US-0051). Speed is
enough, and arguably better: the ladder is monotonic by invariant 2, so **nothing but a sprint
exceeds `TUN-SPEED-RUN`**, and design law 1 says speed is spent anonymity however you came by it.

## A gawker walks to the body, and that is what makes the cap mean anything

Without it the cluster never forms: six NPCs granted a token would stand exactly where they
already stood, and the "cluster of six staring at a point" a distant player reads at 25 m would
be six people standing where they were.

It is also what makes `TUN-CROWD-GAWK-MAX` load-bearing. The cap exists so a corpse cannot
depopulate a blend pocket — and a gawker that never left the pocket could not depopulate it
however many tokens went out. **The pocket-preservation criterion would have been vacuously
true**, which is the most expensive kind of green.

## The shared hash is empty until the first tick

`startle_at` and `register_corpse` query the grid `CrowdDirector._reindex` rebuilds at the top of
the `crowd` stage. Called before any tick they find an empty grid and startle nobody, **silently**
— which is how the first version of `test_alarm_reaches_the_crowd.gd` measured a corpse that
gathered no cluster and a wave that caught nobody.

Safe in production for a reason worth stating rather than relying on: `SYS-KILL` and `SYS-STUN`
resolve at the `combat` stage, which `SystemOrder` puts four positions *after* `crowd`.

## Test notes

| Test | Asserts |
|---|---|
| `test_startle_wave.gd` | Everybody inside the radius is caught; **propagation actually fires** (the anti-vacuous guard for every hop claim); the wave stops at two hops; a propagated NPC does not propagate again; the flag clears on leaving `STARTLE`; a re-startle buys no second round; the wave is deterministic from the seed; a sprinting pawn startles and a strolling one does not |
| `test_gawk_and_corpses.gd` | The cluster is exactly `TUN-CROWD-GAWK-MAX`; **the pocket keeps at least `TUN-BLEND-POCKET-MIN-NPC`, with the counterfactual asserted first**; fleeing NPCs are skipped rather than given a wasted token; nobody out of range is recruited; the two phases are 6 s and 20 s; a gawker leaves by its own timer; an expiring body tells its **own** onlookers; flee is slower than sprint |
| `test_alarm_reaches_the_crowd.gd` | **The wave arrives through `CrowdDirector.tick()`**, not through a test calling the alarm: the sweep runs once a second, a startled NPC is sent away from what scared it at the flee speed, and a corpse registered through the director gathers a cluster that walks to it |
| `test_crowd_is_wired_into_the_server.gd` | The director calls `sweep_for_sprinters` and `expire` — without them `CrowdAlarm` is a correct class nothing runs |

The story's own note names `test_startle_propagation.gd`, `test_gawk_pocket_preservation.gd` and
`test_flee_slower_than_sprint.gd`. The first two are covered by the files above under names that
say what they hold; the third is invariant 14 in `test_tuning_ranges.gd`, repeated in
`test_gawk_and_corpses.gd`. TDD-08 §10's table records where each one actually lives, so no
document claims a file that does not exist.

## Notes

Probabilistic propagation rather than a bigger radius, because a hard-edged circle reads as a
RADIUS while a decaying wave reads as a DIRECTION — propagation continues furthest along the way
NPCs were already fleeing. That inference is the whole point.

**Where the direction actually lives is in the flee vectors, not in the shape of the set.** The
startled *set* is a disc of radius + one hop with a soft edge. What a distant player reads is
people **running**, and every one of them runs away from whatever scared them — so the vectors
diverge from a point and the point is recoverable. A propagated NPC flees the neighbour who
scared it rather than the violence, which is why some of them cross the original point: that is
the decay, and it is why the front thins unevenly instead of expanding as a ring.

The gawk cap prevents a corpse depopulating a pocket, which would make the site of a kill SAFER
to stand in afterwards.

**`Corpse` carries `victim_peer` and nothing reads it.** Recorded rather than used: `SYS-SCORE`
and the contract cycle are M4's, and a corpse that could not say whose it was would have to be
re-derived from the score log.
