---
id: US-0054
title: Blend actions — static and concealment props
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-27
depends_on: [GDD-03-SOCIAL-STEALTH, GDD-05-LEVEL]
---

# US-0054 — Blend actions: static and concealment props

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-SUSPICION` |
| **Systems** | `SYS-BLEND` |
| **Estimate** | S |
| **Depends on** | US-0053 |

## Description

Bench and stall-lean blends, plus the five capacity-one concealment props.

## Acceptance criteria

- [x] Static props require no NPCs nearby; any movement input breaks them. **The break
      threshold is `TUN-PASV-STILLNESS-SPEED-CEILING`, adopted rather than invented**:
      `PawnContext` carries no move vector, and the game already owns a number for *moving at
      all*. Stricter than the `TUN-BLEND-BREAK-ON-SPEED` every other blend uses — you may
      drift inside a crowd pocket and you may not shift on a bench.
- [x] Concealment props hide the player completely — not rendered, not killable. Both halves
      are server-side: the occupant leaves `present_slots` entirely so `RemotePawns` frees the
      body, and `SYS-KILL` and `SYS-STUN` each answer `TARGET_CONCEALED` at **no cost to the
      presser**.
- [x] Capacity is exactly 1; a second request is refused with DISTINCT feedback, not silence.
      `NET-S2C-BLEND-DENIED` is a new message — `NET-C2S-BLEND-REQUEST` had **no answer of any
      kind**, so a press at an occupied hay cart and a press at an empty street produced
      exactly the same nothing.
- [ ] The occupant can see nothing while inside. **Blocked: no client renders a blend.** The
      server half is done — `blend_state` reaches the occupant's own snapshot block, which is
      what a widget will black the screen out from — and the widget is US-0084 in M5. A guard
      over zero call sites would be vacuously green.
- [x] A 0.5 s exit-vulnerability window prevents door-flickering to dodge a kill.
      **`TUN-BLEND-PROP-EXIT-VULN` is per (peer, prop), not per player**: leaving the well and
      running to the hay cart is what the design wants; going back into the same well is not.
      Armed by *any* exit including a break, because a break is the faster of the two doors.
- [x] Occupancy is server-owned state. `PropOccupancy` is a plain object `SYS-BLEND` owns; no
      client mirrors it and nothing outside the server can decide a prop is free.

## As built, 2026-08-27 — five of six

**THE TWELVE LEAN SPOTS ARE DERIVED FROM THE STALL TABLE, NEVER HAND-LISTED.** Two per market
stall, one on each long side, standing `NAV_AGENT_RADIUS` clear of the counter — which is where
a person is when they are leaning on a 0.9 m one. Six stalls give **twelve**, and GDD-03 §4.2's
comparison table says *"~12 props"*: the number now follows from the market rather than being
asserted about it. Hand-listing was the other option and this project has already paid for it —
four procession routes were transcribed from prose and every one ran through masonry.

**AND `is_standable` IS THE WRONG QUESTION TO ASK OF A LEAN SPOT, WHICH COST SIX OF THE TWELVE.**
The first version used it and got **6**. That predicate erodes every stall by
`NAV_AGENT_RADIUS` because an *agent* cannot path into contact with a counter — but a player
leaning on one is in contact by definition, and their centre sits exactly on the eroded
boundary. `Rect2.has_point` **includes** the minimum face and excludes the maximum, so the north
side of every stall was rejected and the south side of every stall was accepted: **6 of 12,
split by a convention rather than by geometry.** Same hazard as the `AABB`/`Rect2` disagreement
that made an illegal spawn site look legal (GDD-05 §2.7).

**THE MOST SPECIFIC THING YOU ARE STANDING AT WINS, AND GDD-03 §4.1 GIVES NO ORDERING.** One is
needed, because a hay cart in a market is inside a crowd pocket and beside a stall counter at
the same time. Five exact spots, then twelve exact spots, then a formation you must be 2.5 m of,
then *anywhere at all with four NPCs*. A press at a concealment prop that silently took the
pocket instead would spend a walk the player made deliberately, and they would not find out
until a hunter looked at them.

**THE PROP REACH IS `TUN-BLEND-GROUP-JOIN-RADIUS`, ADOPTED RATHER THAN INVENTED.** §4.1.3 and
§4.1.4 both say only *"at the prop"* and no tunable carries a prop radius. Writing one would be
a new gameplay constant (never-do #1), so the number the game already means by *"close enough to
claim this blend"* is reused. **If a playtest wants them different, `TUN-BLEND-PROP-RADIUS` is a
`TUN-` addition and therefore the owner's.**

**THE CONCEALMENT PROP IS THE ONE EXCEPTION TO "BLEND PROTECTS ANONYMITY, NEVER THE BODY", AND
IT IS THE GDD'S EXCEPTION RATHER THAN THIS STORY'S.** §4.1.4: *"cannot be broken from outside; a
player inside cannot be killed"*. It is enforced by `SYS-KILL` and `SYS-STUN` reading
`PawnContext.blend_state` — written at the `suspicion` stage, read at `combat` three stages
later in the same tick — rather than by anything in `SYS-BLEND` refusing.
`test_concealed_is_untouchable.gd` asserts the exception **and the rule it is an exception to**,
so a reader comparing them sees the line instead of inferring it.

**"NOT RENDERED" MEANS LEAVING `present_slots`, NOT OMITTING THE RECORD.** Delta encoding made
absence mean *unchanged* (US-0031), so a concealed player left in the mask would be drawn
motionless at the doorway of the prop they climbed into — which is exactly where a hunter would
look. Dropping out of `everyone` also drops them from the baseline, so they are re-sent in full
when they step out: the crowd's farewell, in a second place.

**AND THE MAP GENERATOR WAS AT 399 OF ITS 400 LINES**, so this story could not add three without
splitting it. `tools/map_data_builder.gd` is that split, and the seam is the honest one: the
generator writes **two artefacts** — a pair of scenes with a baked navmesh, and a resource the
systems read — and only the second is what any rule is written against. The map reproduces
byte-identical apart from the new field.

## Test notes

| File | Asserts |
|---|---|
| `test/unit/core/blend/test_blend_prop_capacity.gd` | Capacity read from the tunable, the second arrival refused **with a reason**, the two refusals distinguishable from each other, the re-entry window per prop and in net ticks, and that a departing peer does not take a hiding spot off the map |
| `test/unit/systems/blend/test_blend_props.gd` | A lean needs no crowd and breaks on movement but survives a floor-snap velocity; a hiding spot is claimed, refused, released and locked out; and the ordering, **with the counterfactual that a pocket still wins where there is no prop** |
| `test/unit/systems/combat/test_concealed_is_untouchable.gd` | Neither verb touches a concealed player and neither charges for trying — **and the other three blend kinds leave the body exactly as killable**, which is the line asserted from both sides |
| `test/unit/net/server/test_concealed_is_not_rendered.gd` | The occupant leaves `present_slots`, comes back when they step out, and still receives their own snapshot — safe and blind is the price, safe and disconnected is a bug |

**Falsified against five planted defects**, each reddening the assertions it should and no
others: the capacity check defeated, `_moving_at_all` returning false, `_is_concealed` returning
false, the snapshot's `continue` removed, and the blend ordering reversed.

## Notes

The concealment prop is the strongest and most restricted blend: total safety in exchange for
total blindness and a fixed, learnable location. Capacity one makes each a claimable resource, so
a second player arriving is a real problem.

Every hiding spot has a POSITIONAL weakness rather than a mechanical one. The prop is always
perfect; the walk to it never is.
