---
id: US-0047
title: Clone local-minimum rebalancing
version: 1.0.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-18
depends_on: [TDD-08-CROWD, GDD-03-SOCIAL-STEALTH]
---

# US-0047 — Clone local-minimum rebalancing

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-ANONYMITY` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0046 |

## Description

The director maintains at least two clones of each in-use persona within 25 m of every player,
by re-routing existing clones.

## Acceptance criteria

- [x] Runs on the 2 s director timer, never per tick.
- [x] Re-ROUTES existing clones; never respawns or re-personas them.
- [x] Retargets the nearest idle clone toward an under-served region.
- [ ] Over a 3-minute clustered match, every player always had at least 2 same-persona clones within 25 m. **Still unticked after rule 3 was scoped on 2026-08-21, and the scoping is not what would tick it.** The grace excuses the opening arrangement, not the mid-match troughs: 71 readings of 12 960 under the floor over the whole run, **47 of 11 544 after the grace** — 0.41 %, never below 1. A fetched clone needs eighteen seconds to cross 25 m and no re-routing rule beats a walk, so *always* is not a property this rule can have. What it guarantees is that a breach is never ignored. TDD-08 §5.1.4 and §5.1.5.
      — **Not achievable, and the reason is a walk rather than a shortage.** A fetched clone
      crosses 25 m in about eighteen seconds, so a player who loses one is short for that whole
      walk however promptly help is dispatched. Supply is not the constraint: the clustered region
      holds **23.9 NPCs and 4.27 clones of each persona on average** against a floor of 2.
      Measured at **100 readings of 12 960 under the floor after settling**, never below 1, and
      **of 21 short pairs the pass saw, 18 already had a clone on its way and 6 were dispatched**
      — the rule never ignores a breach. That last property *is* asserted; "always" is not, and
      is not ticked. See TDD-08 §5.1.4.
- [ ] Re-routing does not read as clones following players.
      — the mechanical half is asserted and the readable half cannot be judged: **no NPC is on
      the wire**, so no client has ever rendered a clone. Same treatment as US-0044's directional
      criterion and M1's feel gate.

## What was built

`scripts/systems/crowd/clone_balance.gd`, called from `CrowdDirector._rebalance_clones` on the
same 2 s pass `CrowdFormations.rebalance()` uses. `CrowdIntent._an_anchor()` prefers the
reservation over its own seeded pick, and that one line is the entire effect on an NPC — nothing
else about it changes: not its speed, not its state, not how it walks.

**`TUN-CROWD-CLONE-LOCAL-RADIUS` 25.0 m was missing and now exists.** GDD-03 §6.3 rule 3 and
TDD-08 §5.1 both say "within 25 m" and no tunable carried it — the same omission
`TUN-CROWD-IDLE-DURATION-MIN/-MAX` had in US-0040, and the value is the documents' own. Invariant
29 pins it at or below `TUN-NET-NPC-CULL-RADIUS`: a clone held near a player must be one that
player can see.

## The three findings

**FETCHING ALONE CANNOT HOLD A FLOOR.** A clone crosses 25 m in about eighteen seconds; a hole
opens the instant somebody walks out of one. Measured, a fetch-only rule left a clustered player
at **zero**. Each pass now **holds** first — a clone of a thin persona already inside the region
is given an anchor on this side of it, at no travel cost. Fetching recovers from a hole; holding
stops one opening, and TDD-08 §5.1's sketch contains only the half that cannot work alone.

**IDLE CLONES ARE RESERVED WITHOUT BEING WOKEN.** Holding only *walkers* leaves a two-second
window each pass: an idle clone near the edge finishes its pause, picks a far anchor and is gone
before anybody looks again — **91 readings of 12 960** under the floor. A reservation it simply
finds waiting costs it nothing. Cutting the pause short instead would be motion the region did
not need, and motion is what reads.

**THE DESTINATION IS KEPT A PASS'S WALK INSIDE THE BOUNDARY.** An anchor at 24.8 m is inside one
player's radius and outside their neighbour's. The margin is `TUN-CROWD-NPC-SPEED-STROLL` ×
`TUN-CROWD-DIRECTOR-INTERVAL` — 2.8 m, one pass of walking, which is exactly how long nobody is
looking. **Derived from two existing tunables rather than chosen**, so retuning either moves it.
It took the breach count from 75 to 2.

## Two decisions worth carrying

**THE STREAM IS PREVENTED BY ACCOUNTING, NOT BY A THROTTLE.** Eighteen seconds is nine passes, so
a rule counting only *arrived* clones sends nine to fix a hole one deep — nine Lucerna converging
on a market, which is the leak this story's own note warns about. A clone walking into the region
counts toward the minimum while it is on its way: **8 fetched on the first pass of a starved
district, 0 over the next five.** A cap would have hidden the fact that the arithmetic was wrong.

**STROLLERS ARE PREFERRED TO IDLERS, WHICH IS A DELIBERATE READING OF "NEAREST IDLE CLONE".**
Re-routing a walker changes only its destination. Taking one that is standing at an anchor empties
a seat, and `TUN-BLEND-POCKET-MIN-NPC` needs four NPCs standing together for the *other* blend to
exist at all — so the cheap-looking choice quietly costs hiding places. An idle clone is still
taken when no walker of that persona is spare.

**And nobody is robbed to pay somebody else.** A candidate standing inside *any* player's radius
is already somebody's local minimum; moving it would trade one player's anonymity for another's,
with the two oscillating and neither ever holding two.

## What it holds the minimum for, and why that is not yet the real answer

GDD-03 §6.3 rule 3 says "each **in-use** persona". Nothing chooses a persona for a player — there
is no lobby, `NET-C2S-LOADOUT` is M4's, and `PawnContext.persona` is `&""` on every pawn — so all
four are treated as in use, which is the call `server_root` already merged one function away for
`NpcPool.activate`. It is the safe direction: rule 5 makes a player with no clones a marked man
and clones of an unplayed persona are explicitly harmless. `SYS-MATCH` narrows it at M4, and the
rule gets *cheaper*, never weaker.

## Test notes

| Test | Asserts |
|---|---|
| `test_clone_local_min.gd` | **The counterfactual first**: six clustered players starve to zero without the pass, or every assertion below is vacuous. Then the floor over 5 400 net ticks; nothing respawned or re-personaed; every destination is a map anchor and never a player's position; a reservation does not re-aim at a player who moves; nobody is robbed from another player's radius; a hole one deep is not answered with a stream; an unwatched crowd is never re-routed |
| `test_director_runs_layer_four.gd` | **The wiring, which `CloneBalance` cannot see.** The shipped `CrowdDirector` calls it, exactly once per 2 s and never per tick, and `CrowdIntent` really prefers the reservation to its own seeded pick. Plus: the in-use set is still the playable four, so the day a lobby narrows it something says so |

**Both are unit tests and the three-minute match is one of them.** The integration suite is at
152 s of the 180 s it is allowed and 5 400 ticks of *physics* would not fit. The crowd in the
test is real — real `NpcBrain`s, real pool bodies, the real `SpatialHash` — and only navigation
is modelled, as a straight line at stroll speed. That is optimistic about travel time and cannot
flatter the rule, which is the shipped code unchanged.

## Notes

This is the layer that actually matters. Layers 1 to 3 catch authoring mistakes, which are
visible in review. This catches the invisible failure: all twelve Lucerna clones drift to the
north plaza, the Lucerna player in the south market is now unique, every rule still works, the
crowd count is still 78, nothing is broken — and they are simply, silently, findable.

Deliberately slow, because visible re-routing is itself an information leak: a stream of Lucerna
suddenly walking toward a market says a Lucerna player is there.
