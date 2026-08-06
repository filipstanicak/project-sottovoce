---
id: US-0020
title: Climb, drop and gap-jump states
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-06
depends_on: [TDD-06-PAWN, GDD-05-LEVEL]
---

# US-0020 — Climb, drop and gap-jump states

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-TRAVERSAL` |
| **Systems** | `SYS-TRAVERSAL` |
| **Estimate** | M |
| **Depends on** | US-0019 |

## Description

StateClimb and StateDrop, the latter also handling the ballistic gap-jump arc.

## Acceptance criteria

- [x] Climb at 2.8 m/s, up to 9 m in one unbroken climb.
- [x] Climb can be released mid-way, transitioning to Drop.
- [x] Drop under 4 m lands clean; over 4 m applies a 0.8 s stagger.
- [x] Gap jump routes through Drop with an initial upward velocity.
- [x] Drop is uninterruptible while airborne.
- [x] Climb applies climb-rate suspicion; **arriving on the roof stratum applies roof-presence suspicion**.

**The second half of the last criterion is met at the rate, not at the meter.** Locomotion states
return `TUN-SUSPICION-GAIN-ROOF` above `TUN-SUSPICION-ROOF-HEIGHT`, so the roof toll is charged
by the same mechanism as every other suspicion rate in the pawn — and, like every other one,
**nothing integrates it yet.** `SYS-SUSPICION` is US-0051/0052, in M4. Every
`suspicion_rate()` in the codebase is in the same position; this one is not specially unfinished.

## Test notes

Verify the balcony-to-street drop at 4.5 m costs a stagger — descending into the crowd is
deliberately a small skill check rather than a free action.

**The note's own arithmetic is off, and the map is right.** `VetraioLayout` puts the balcony at
3.5 m and the street at 0, so balcony-to-street is 3.5 m and lands **clean**. The 4.5 m drop the
note describes does not exist in MAP-VETRAIO. What costs a stagger is roof→balcony (5.0 m) and
roof→street (8.5 m), which is what `test_drop_state.gd` asserts, against `VetraioLayout` rather
than against numbers typed into the test.

The story's own Notes say the same thing correctly: *"Roof-to-balcony is exactly at the safe
threshold"* — it is 5.0 m against a 4.0 m threshold, so it is just past it, not at it.

## Notes

Roof-to-balcony is exactly at the safe threshold, so upper transitions are free and only the
final descent costs. You can flee across the roofs cheaply but cannot rejoin the crowd cheaply.

---

## The stratum arithmetic, since two documents disagreed about it

| Transition | Height | Verdict |
|---|---|---|
| Balcony → street | 3.5 m | Clean |
| Roof → balcony | 5.0 m | **Stagger** |
| Roof → street | 8.5 m | **Stagger** |

`TUN-TRAVERSE-DROP-SAFE-HEIGHT` is 4.0 m and the comparison is **strictly** greater, because the
level design builds to that boundary and a `>=` would tax a transition the metrics deliberately
made free.

So the shape the design wants holds: the escape is affordable and the return is a small skill
check. What a long fall costs is *time*, never anonymity — dropping down stays the cheap
direction, which §6.1's whole route economy rests on.

## What this story found

### A façade thinner than one probe step could not be climbed

The same defect US-0019 fixed for the obstacle-top cast, in the climb-top cast beside it, missed
because the fix was applied where the bug was found rather than to the pattern. A 0.4 m-thick
wall put every single sample behind the façade, measuring the floor, so `surface_height` stayed
`INF` and `<= TUN-TRAVERSE-CLIMB-MAX-HEIGHT` was false.

**A 0.4 m garden wall and a 0.4 m house wall are the same shape to a raycast.** Both casts now
share `ProbeLayout.TOP_SAMPLE_FRACTIONS`.

Found by the end-to-end climb test, not by reading the code — which is the second time in two
stories that the geometry tests caught something the unit tests structurally could not.

## Decisions worth recording

**Gravity is read, not tuned.** `Tuning.gravity` surfaces the pinned
`physics/3d/default_gravity` so `scripts/pawn/` can reach it through the one autoload it is
allowed to touch. A `TUN-` twin would be a second source that could disagree with the engine the
pawn actually falls in — and `test_project_settings_pinned.gd` already pins that setting
*because* "a changed default would alter every drop and stagger".

Fall durations follow from it: `sqrt(2h/g)` gives the ~0.9 s that GDD-02 §6's cost table quotes
for a 4 m drop, so the design number was read off the physics and tuning it separately would let
the two drift.

**A climb is priced per metre, not per manoeuvre.** `TUN-SPEED-CLIMB` is a speed, so a 9 m
façade takes 3.2 s and costs 38.6 suspicion — Noticed before you arrive — while a 3 m one costs
a third of that. A fixed duration would flatten the roof economy §6.1 depends on.

**Drop refuses COMBAT where Vault admits it.** GDD-02 §3.1's table says "No" for Drop and "Yes
(to COMBAT+)" for Vault, and the difference is real: a stun is a thing done to someone standing
up. `Drop.interrupt_priority()` returns COMBAT so the machine admits only FATAL, the same way
`Stunned` expresses the same rule.

## What this story does not do

- **No drop-swing.** §7.2 case 3 mentions it for a lower ledge within 2 m. The probes do not
  look for one, and no state performs it.
- **No landing collision.** A drop trusts its plan. A pawn dropping onto a spot an NPC has
  walked into will overlap them for a frame; that is `SYS-CROWD`'s problem, in M3.
- **Nothing can die mid-air.** `PawnTransitions` gives `Drop` exactly one outgoing edge, back to
  locomotion — so the FATAL interrupt the priority admits has nowhere to go. That is what the
  normative diagram draws; whether a player should be killable in freefall is an M4 question
  for `SYS-KILL`, recorded here rather than answered.
