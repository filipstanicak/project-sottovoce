---
id: US-0043
title: CrowdDirector and walking-group circuits
version: 0.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-16
depends_on: [TDD-08-CROWD, GDD-05-LEVEL]
---

# US-0043 — CrowdDirector and walking-group circuits

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-BEHAVIOUR` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0042 |

## Description

The director owns everything with global correctness requirements: formation slots, the four
circuits, and clone redistribution.

## Acceptance criteria

> **Four of six, and the two that are open are both level-data findings rather than
> unwritten code.** Both are measured, both are reported by a test, and neither can be closed
> without re-authoring routes — which is the owner's. See the two sections below.

- [ ] **Four circuits with periods 55 to 75 s, from MapData.** The four circuits exist and their
      **declared** periods are in band, asserted. The criterion stays unticked because the
      periods are not what the groups walk: the routes are 150–237 m long, so 55–75 s implies
      **2.6–3.2 m/s**, roughly twice `TUN-CROWD-NPC-SPEED-STROLL` and faster than
      `TUN-SPEED-RUN`. The implementation honours the speed and the period comes out at
      107–169 s. Measured in `test_crowd_circuit.gd`.
- [x] **Groups of four NPCs in loose formation at 1.3 m spacing, with a joinable slot.**
      `TUN-CROWD-GROUP-SIZE` NPCs plus one slot that is **never given to an NPC**. The closest
      pair of slots is asserted to be exactly `TUN-CROWD-GROUP-SPACING`, because "loose
      formation at 1.3 m" is a number and a layout whose real minimum was 1.84 m would satisfy
      nobody's reading of it.
- [ ] **No two circuits are within 8 m of each other simultaneously.** **Missed by 0.51 m**, and
      by *geometry* rather than timing: CIRC-A and CIRC-B share the z = 45 stretch of the Loggia
      spine, so re-timing them moves the closest approach by 15 cm. Reported rather than failed
      by `test_circuit_separation.gd`.
- [x] **No circuit enters the empty plaza.** Sampled at 1 m along every route against Piazza
      Secca's declared bounds. It passes, and it is the one rule the shipped routes get right
      without argument.
- [x] **The director runs on a 2 s timer, never on the per-tick path.** `ctx.tick %
      Tuning.ticks(TUN-CROWD-DIRECTOR-INTERVAL)` — **derived from the tick, never accumulated**,
      the same rule `MatchDirector` follows. Recruitment and revocation happen there; only
      advancing the formations and steering their members is per-tick.
- [x] **Formation slots are assignable to and revocable from a player.** `claim_slot`,
      `release_slot`, `joinable_group` and `slot_position_of` on `CrowdDirector`, tested against
      a real director in `test_walking_groups.gd`: a peer claims the slot, it cannot be stolen,
      it **travels with the procession**, and releasing it offers it to the next player.
      **Nothing in a shipping scene calls them yet** — `INPUT-BLEND` reaches them through
      `SYS-BLEND`, which is US-0053.

## The circuits are 150–237 m long and their periods say 55–75 s

Three documents cannot all be true:

| Source | Says |
|---|---|
| GDD-03 §4.2 | A walking group moves at **1.4 m/s** |
| GDD-05 §5.2 | Circuit period is **55–75 s** |
| `VetraioLayout.CIRCUITS` | The four routes are **150.3, 195.0, 237.1 and 181.2 m** |

150 m at 1.4 m/s is 107 s. The declared periods imply **2.6–3.2 m/s**, which is above
`TUN-SPEED-RUN`.

**The speed is what the implementation honours**, because the design laws pin it and the period
band does not. The walking group is the *only* blend that lets a player travel while gaining
anonymity (GDD-03 §4.1.2); at twice blend-walk it would be a speed cheat wearing a crowd, and
invariant 1 exists precisely so a blending player is indistinguishable from the crowd by motion.
`CrowdCircuit` is therefore parametrised by **distance**, and `period_at(speed)` is a read-out
rather than an input.

**What that costs, stated plainly.** A lap is 107–169 s against a documented 55–75. GDD-07 §
lists "knowing the four circuits' 55–75 s periods and intercepting them" as a ~20-match mastery
skill; at 169 s a circuit is intercepted about three times in an eight-minute match rather than
seven. **The fix is to shorten the routes**, not to speed the groups up — and re-authoring four
routes against six competing rules is level design with an owner, not a story.

## CIRC-A and CIRC-B pass within 0.51 m of each other

GDD-05 §5.2 requires 8 m, because "two adjacent groups would create a super-pocket and a
trivially safe corridor". The shipped routes miss it by more than an order of magnitude, and
**no choice of periods fixes it**: both run along z = 45 through the Loggia spine, so they
*share* that stretch of ground. Re-timing them changes the closest approach from 0.51 m to
0.66 m.

`test_circuit_separation.gd` reports this as `pending` rather than failing, the same choice
`test_upstream_bandwidth.gd` and `test_snapshot_size.gd` made: a red suite nobody can turn green
stops being read. It goes green by itself the moment the routes are re-authored.

## An agent that has arrived stops avoiding

The afternoon this story lost, and the most useful thing in it.

A `NavigationAgent3D` whose `target_position` it has reached — **or never had** — answers
`velocity_computed` with **exactly zero**, whatever `set_velocity()` was handed. Formation
members were driven at 1.4 m/s straight at their slots and stood perfectly still while the slots
walked away from them. Nothing errored, the desired velocity was correct, the bodies were on the
floor and in the right state, and the only visible symptom was a formation whose members lagged
further behind every tick.

The fix is not to path to the slot — a slot moves every tick, and sixteen path queries a tick
against `TUN-PERF-CROWD-REPATH-PER-TICK` 3 would starve every strolling NPC in the district.
Group members aim at a point **one rebalance interval ahead on their circuit**, refreshed
through the same repath queue when they get there: the agent is never finished, so avoidance
keeps running, and the cost is about a third of a query per tick.

## Two decisions that are not obvious from the code

**A procession waits for its stragglers.** The slot and the NPC chasing it both move at exactly
`TUN-CROWD-NPC-SPEED-STROLL`, so any lag — one RVO sidestep, one corner taken wide — is never
closed and the group sheds members it can never take back. `CrowdFormations._pace` throttles the
formation by the worst lag instead, because the alternative is letting a straggler jog to catch
up, and a clone that breaks into a jog is a clone a player cannot imitate.

**The district starts with its processions already walking.** A group sweeps a 2.5 m tube along
its route and picks up roughly four people per *lap*, so recruitment alone would leave the four
walking groups missing for the first minute or two of an eight-minute match — a blend that is
absent for a fifth of the match is a blend nobody plans around. `form()` seats them at match
start, before any client has been welcomed. It refuses to form a group the crowd cannot spare:
processions never outnumber the standing crowd, or `TUN-BLEND-POCKET-MIN-NPC` would have nothing
left to work with.

## Test notes

| Test | Asserts |
|---|---|
| `test_crowd_circuit.gd` | The loop closes; points and headings land where the arithmetic says; it wraps rather than clamping; a lap at stroll returns to the start; **the shipped periods imply 2.6–3.2 m/s** |
| `test_walking_group.gd` | One more slot than NPCs; **the joinable slot is never given to an NPC**, both by omission and by refusal; the closest pair of slots is exactly `TUN-CROWD-GROUP-SPACING`; no two slots share a point; the formation turns with the route |
| `test_circuit_separation.gd` | Four circuits with in-band declared periods; **no circuit enters the empty plaza**; the closest simultaneous approach is measured and reported |
| `test_walking_groups.gd` | **NPCs actually enter `WALKING_GROUP`** — the vacuous-success guard for the whole story; the crowd can spare them; no NPC takes the joinable slot in a live run; the formation travels and nobody falls out of it; **a group never outpaces blend-walk**; a player claims, holds, travels with and releases the slot |
| `test_crowd_is_wired_into_the_server.gd` | `server_root.gd` calls `form_groups()`, because a formation nothing stands up is a state nothing enters |

`test_circuit_separation.gd` samples every pair at 0.5 s intervals over four times the longest
period, which visits every phase relationship the four routes can be in.

## Notes

Two adjacent groups would form a super-pocket and a trivially safe travelling corridor. The
empty plaza stays empty — that is its entire function.

**Clone redistribution is in this story's description and in none of its criteria**, and it stays
where the criteria put it: `_rebalance_clones` (TDD-08 §5.1) is **US-0047**'s, which is the
story whose acceptance criteria cover it. `SpatialHash.count_persona()` is the query it needs and
already exists.

`CrowdFormations` is a second file rather than more of `CrowdDirector`, which is where TDD-08 §8
puts it. The director already owns the tick, the brains and the steering; one file holding all of
that plus formations would pass 400 lines before US-0044 adds a corpse to it.
