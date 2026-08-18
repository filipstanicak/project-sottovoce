---
id: US-0096
title: Persona-aware initial seating
version: 0.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-18
depends_on: [TDD-08-CROWD, GDD-03-SOCIAL-STEALTH, US-0047]
---

# US-0096 — Persona-aware initial seating

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-ANONYMITY` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | S |
| **Depends on** | US-0047 |

## Description

The crowd's opening arrangement satisfies `TUN-CROWD-CLONE-LOCAL-MIN` at every spawn point, so a
match does not begin with a local hole that US-0047's director then spends twenty seconds closing.

## Why this exists

US-0047 first measured its guarantee at **12 958 of 12 960** readings over a three-minute
clustered match, with both misses inside the first twenty seconds. **That figure is retracted**
— the anchor fix in this very story took the same code to 248 breaches, which is how the corpus
learned the guarantee was a property of one anchor arrangement rather than of the rule (TDD-08
§5.1.4). What survives the retraction is the *reason* this story exists, which was never about
the size of the number:

> `CrowdPlacement` deals the crowd round-robin over the map's idle anchors with **no persona
> awareness at all**. The roster is derived from `match_seed`; the positions are derived from
> `match_seed`; **nobody ever matched the two.** So a match can begin with every Lucerna in the
> north and a Lucerna player spawning in the south, and nothing that re-routes rather than
> teleporting can fix that before a clone has walked 25 m — about eighteen seconds.

Twenty seconds of a four-hundred-and-eighty-second match is 4 % of it, and it is the 4 % in which
players are closest to their spawn points and least able to move. US-0047's fourth criterion says
*always*; this is what makes *always* achievable.

## Acceptance criteria

- [ ] Every spawn point has at least `TUN-CROWD-CLONE-LOCAL-MIN` clones of each in-use persona
      within `TUN-CROWD-CLONE-LOCAL-RADIUS` on the first tick of a match.
      — **Met at every spawn point that has room, and three of `MAP-VETRAIO`'s six do not.**
      18 short (spawn × persona) pairs become 9; **7 of 7 at the spawn points with room become
      0**. The nine that remain are physically impossible — see below — so the criterion as
      written is the level's now, not the code's, and is not ticked on a partial result.
- [x] It is a **permutation** of `CrowdPlacement`'s output, not a replacement for it: the set of
      occupied positions is byte-identical, so the navmesh snapping, the anchor round-robin and
      the scatter bound are untouched and their tests pass unchanged.
- [x] Deterministic from `match_seed`. Two servers given the same seed seat the same crowd.
- [x] Never seats a clone somewhere no NPC was going to stand anyway — no new positions, no
      positions off the navmesh.
- [x] `CrowdPlacement`'s existing spread properties still hold: the round-robin share per anchor
      and the scatter bound are asserted against the seated arrangement, not just the raw one.

## THE FINDING: THREE OF SIX SPAWN POINTS CANNOT SATISFY RULE 3 AT ALL

Measured before the algorithm was blamed, which is the only reason it was found rather than
worked around. Satisfying `TUN-CROWD-CLONE-LOCAL-MIN` for four personas needs **eight clone
seats** inside `TUN-CROWD-CLONE-LOCAL-RADIUS`. What `MAP-VETRAIO` actually offers:

| Spawn point | NPC seats within 25 m | Needs |
|---|---|---|
| (12, 36) | 12 | 8 |
| (20, 70) | 15 | 8 |
| (6, 97.5) | **3** | 8 |
| (114, 97.5) | **0** | 8 |
| (100, 70) | **6** | 8 |
| (88, 14) | 10 | 8 |

**A permutation cannot conjure a seat that is not there.** Three of six spawn points are short
of seats outright, and one of them — **(114, 97.5) — can see no NPC at all within 25 m.**

That is worse than a clone-parity problem. GDD-03 §6.3 rule 3 is a **release blocker**, and a
player spawning at (114, 97.5) starts the match with *zero* clones of their own persona and
nobody at all nearby — which also puts them on open ground for `TUN-SUSPICION-GAIN-OPEN`, alone,
in the first seconds, before they can move. **The cause is the idle anchors: that corner of the
district has none within 25 m of its spawn point**, and `CrowdPlacement` deals from anchors.

**Reported rather than failed, exactly like US-0043's circuit separation.** Re-authoring idle
anchors against six competing rules is level design with an owner, and this story does not invent
one. `test_crowd_seating.gd` asserts what the *code* owes — zero shortfalls where there is room —
and prints the seat census on every run, so the day the anchors move, the number moves with it.

## Design

**A PERMUTATION, NOT A PLACEMENT.** `CrowdPlacement.positions()` answers "where does slot *n*
stand"; `CrowdRoster.derive()` answers "who is index *n*". Both are already derived from the seed
and both are already correct. What is missing is the *assignment* between them, and expressing the
fix as a permutation means every property `CrowdPlacement` was tested for survives by construction
— the multiset of positions does not change, so the anchor shares, the scatter bound and the
navmesh snapping cannot regress.

**FILLER IS THE CURRENCY.** Roughly thirty of the seventy-eight are archetypes, not clones, and
GDD-03 §6.3 puts **no local requirement on them whatsoever**. So a spawn point short of Lucerna
swaps a nearby filler for a distant Lucerna: the filler is not needed anywhere in particular, the
Lucerna was surplus where it was, and no other spawn point's minimum can be broken by the trade.
That is what makes the greedy pass terminate rather than oscillate — the classic failure of a
"fix every constraint in turn" loop, and one US-0047 already had to design against in
`_nearest_spare`.

**SURPLUS SECOND, AND ONLY SURPLUS.** When no filler is near enough, the swap takes a clone of a
persona that has **more than the minimum** at that spawn point. Taking one at exactly the minimum
would fix one hole by digging another, which is the oscillation again.

## Test notes

`test_crowd_seating.gd`, a unit test over the real map's anchors and spawn points.

**The vacuous-success guard runs first and must fail without this story**: the unseated
round-robin arrangement has to genuinely leave at least one spawn point short of at least one
persona, or every assertion below is true of a district that never had the problem.

## The take side needed the same guard as the give side

The first working version fixed 7 of 7 feasible shortfalls down to **2**, and the two survivors
were the last spawn points processed. `_spare_seat_near` already refused to give away a clone
another spawn point depended on; `_clone_away_from` had no such filter, so it conscripted clones
that were somebody else's minimum and the greedy pass handed the last spawn points a district
already stripped. Guarding both ends took it to 0. **The same asymmetry US-0047's
`_nearest_spare` was designed against, and it still got written the wrong way once.**

## Notes

This does not make the crowd start *around* the players — it makes the crowd start *containing*
them. The difference is the whole design: no clone is placed anywhere a clone was not already
going to stand, and the arrangement a player walks into on the first frame is one the round-robin
had already produced.
