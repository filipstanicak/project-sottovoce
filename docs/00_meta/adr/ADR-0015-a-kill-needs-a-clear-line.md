---
id: ADR-0015
title: A kill needs a clear line to its contract
version: 1.0.0
status: accepted
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [ADR-0010, GDD-03-SOCIAL-STEALTH, TDD-10-SCORING, TDD-07-SUSPICION, US-0060]
---

# ADR-0015 — A kill needs a clear line to its contract

## Context

**Two documents have disagreed since US-0060 and the disagreement was left open deliberately.**
TDD-10 §3's kill flowchart has five gates — Cinderfall, contract, range, cone, contest — and
**no line-of-sight node**, so `KillRules` was built without one and TDD-10 §3.2 recorded it:
*"as built, a kill through a market stall at 2.4 m is legal."* `ADR-0010`'s acceptance criteria
imply the opposite, listing a test for *"an NPC-occluded LOS that was clear in the past"*.

**Two things were wrong with how that contradiction was written down, and both are corrected
here.**

1. **The citation was wrong.** TDD-10 §3.2 and US-0060 both attribute the opposing claim to
   *"TDD-04 §10's test table"*. TDD-04 §10 is an interfaces section and contains no test table.
   The phrase is in `ADR-0010`'s acceptance criteria, in an **unticked** box.
2. **The phrase describes a rule this design forbids.** TDD-07: *"NPCs do not block line of
   sight… the crowd must hide you by being confusing, never by being solid."* `has_los` masks
   `WORLD` alone, so an **NPC-occluded** line cannot exist in this game. That criterion was
   written against a world where the crowd is opaque, and it is not evidence for anything.

**So the contradiction dissolves as documentation and survives as design.** The real question is
untouched by either citation: *should a kill land through solid geometry?*

### The measurement that decided it

**Yes, there is geometry thin enough — and US-0054 put a blend spot on each side of it.**

| | Closest two players can stand | Kill reach |
|---|---|---|
| **A market stall** (2.0 m deep) | **2.80 m** | 2.85 m |
| `MercatoWestWallNorth` / `-South` (2.6 m) | 3.40 m | 2.85 m |
| `FondacoGatehouse` (3.0 m) | 3.80 m | 2.85 m |
| Every other mass | 5.8 m or more | 2.85 m |

Reach is `TUN-KILL-RANGE` 2.5 m plus `TUN-KILL-VALIDATION-GRACE` 0.35 m. The separation is the
obstacle's thinnest dimension plus `NAV_AGENT_RADIUS` on each face, because a body cannot stand
inside the margin the navmesh and `VetraioGround.stall_lean_points()` both keep. **Raw thickness
is the wrong question, and asking it that way puts the two Mercato walls on the list.**

**The six market stalls are the only geometry on this map you can kill through, and the margin is
5 cm.** US-0054 derived two lean spots per stall, one on each long face at exactly that
clearance — so **the twelve blend spots built on 2026-08-26 form six pairs that are mutually
killable through two metres of stall.** A player leaning on a market counter, which is an act of
hiding, could be killed by a hunter leaning on the other side of the same counter.

**And the near miss matters as much as the hit.** The two Mercato west walls are 2.6 m thick and
clear the reach by 0.55 m — and they are the masses GDD-05 §2.7 rule 6 leans on to occlude
`S2`-`S5` and `S2`-`S4`. A slightly thinner version of a wall built to stop a *sightline* would
have put a kill straight through it.

## Decision

**Kill validation requires a clear line from the killer to the target, and sight is a
target-selection filter rather than a gate applied afterwards** — the same shape range and cone
already have. An occluded body is simply not a candidate.

**`SYS-STUN` gains no such gate.** See *The asymmetry is deliberate*, below.

### Why this violates no design law, including the one that looks like it does

**GDD-03 §9.2's "the crowd hides you by being confusing, never by being solid" is about NPCs, and
it scopes this decision rather than forbidding it.** `has_los` masks `WORLD` (layer 1); NPCs,
players and corpses sit on `PAWN`/`NPC` and cannot block it *by construction*. So a sight gate on
the kill makes **walls** solid — which they already are for the Compass lock (US-0058) and the
witnessed-kill check (US-0060) — and leaves the crowd exactly as confusing and exactly as
non-solid as before. The law that appeared to forbid the gate is what makes it safe.

### Three consequences of the shape, each of which was a decision

- **No refusal reports occlusion to the presser.** `NET-S2C-KILL-RESULT` carries slots, a tick
  and a bonus group; the verdict is server-side and stays there. A reason on the wire would make
  the kill button a probe for *where a wall stands relative to your contract*, which is the leak
  `StunVerdict` refuses for identity.
- **A stranger in the open still absorbs the press.** Because sight filters selection, a stranger
  standing between you and a contract behind a stall is still the nearest candidate and still
  earns `TUN-KILL-INVALID-TARGET-PENALTY`. A rule that refused the whole press on the
  *contract's* occlusion would hand a player a free test of whether a stranger is their contract
  — the exact thing that penalty exists to prevent.
- **The reticle hint carries the gate too.** `KillSystem.ready_for` applies it, because a hint
  that disagrees with the rule teaches the player to stop reading the hint. That is US-0061's
  `stun_ready` lesson in the other verb.

### It costs no new ray site and no rewind

`has_los` stays the project's single query and `test_los_single_query.gd` still finds one.
`DetectionSystem.clear_line()` is the body-to-body form — **both endpoints lifted to
`sight_point`**, because `RewoundWorld` holds feet and a foot-to-foot ray along a street hits the
floor. It lives beside `sight_point` rather than at each call site, and `_charge_for_witnesses`
uses it too.

**Present-tense geometry against rewound positions is exact, not an approximation.** `has_los`
masks `WORLD`; world geometry does not move. The only thing a rewind would change is the two
endpoints, and the caller has already rewound those. **US-0056's refusal of the `at_tick` form
still stands and still has no caller** — this decision does not give it one.

**`KillRules` is pure Core and may not reach a system**, so the requirement arrives as a
`Callable` that `server_root` binds. **Unbound it answers *nothing blocks***, which is not a
special case: it is what `DetectionSystem._clear_of_geometry` answers in a context with no world,
so a pure unit test and a live district agree. That default is a vacuous-success shape by
construction — forget the binding and every kill passes with nothing red — so
`test_sight_is_wired_into_the_kill.gd` asserts the binding **and** the default it depends on.

### The asymmetry is deliberate

**`SYS-STUN` keeps no sight gate, because adding one would be a weakening and never-do #13
forbids that.** A stun through a stall stays legal.

This is the same asymmetry the range advantage already expresses — stun reaches 3.35 m where the
kill reaches 2.85 — and it is design law 5: the prey must have teeth, and ADR-0013 has just
removed the stun's ability to interrupt a committed kill. It is also not categorically new: the
stun cone reads the **stunner's** yaw alone, so a stun the hunter cannot see coming is already
the intended play.

`test_sight_is_wired_into_the_kill.gd` asserts the absence, so adding one later is a deliberate
act that reads this ADR first. **This is the part of this decision most likely to want
reversing**, and it is recorded as such rather than smoothed over.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Leave it: kills pass through geometry** | Zero cost. TDD-10 §3's flowchart stays literal. | The six stall lean-spot pairs are mutually killable through two metres of stall, so a blend spot is a place you get killed in. A playtester reads that as a bug, correctly. | Rejected |
| **Shrink `TUN-KILL-RANGE` until the pair falls outside reach** | No new mechanism at all. | Closes one case by **5 cm** and changes every kill in the game to do it; the next thin prop reopens it. Also a `TUN-` change, which is the owner's. | Rejected |
| **Thicken the stalls** | Level data, no code. | Stalls are 2.0 m because six of them at that size produce the market density GDD-05 §2.3 asks for, and the twelve lean spots are derived from their faces. Moves three measured systems to fix one. | Rejected |
| **Sight as a target-selection filter** | Costs no new ray site, no rewind, no wire field and no tunable. Reuses the chokepoint. Leaves the crowd non-solid. | A gameplay rule no acceptance criterion asked for, and one more reason a press can whiff. | **Taken** |
| **Sight as a post-hoc gate with its own verdict** | Simpler to read in the flowchart. | Refusing the whole press on the *contract's* occlusion tells the presser something about a body they may not have identified, and lets a hunter test a stranger for free. | Rejected |

## Consequences

### Positive

- **A hiding place stops being a place you get killed in.** The six stall pairs are the concrete
  case, and they were created the day before this decision.
- **US-0056's "kill validation as a `has_los` consumer" criterion is met.** It had been unticked
  since M4 began, latterly with the note *"never asks"*. It asks now.
- **The concealment rule stopped being written twice.** `KillSystem._is_concealed` and an inline
  copy in `StunSystem` both encoded GDD-03 §4.1.4; they are `CombatTargets` now. Two copies of a
  targeting rule that disagreed would read as a hiding spot that works against one verb and not
  the other.

### Negative — stated honestly

- **One more reason a press can whiff**, and the geometry causing it may be waist-high and behind
  the player's own shoulder. GDD-02 §9's failure mode 7 is about exactly this, and the mitigation
  is the one that section prescribes: the whiff plays, and the reticle was already dark.
- **TDD-10 §3's flowchart gains a node it did not have**, which is a normative diagram being
  amended. Recorded there rather than left for a reader to discover from the code.
- **The kill and the stun now disagree about walls.** Defensible, asserted, and the first thing
  to revisit if playtesters report it as inconsistent rather than as a prey advantage.

### Neutral

- **The rewound crowd still has no consumer.** US-0060 found both of ADR-0010's reasons for
  rewinding NPCs false of the built game, and this decision does not change that: the sight query
  masks `WORLD`, so NPCs cannot block it however many of them are rewound.

## Revisit trigger

Reopen if playtest reports of *"I was in range and nothing happened"* rise and the geometry
blamed is repeatedly a market stall — the fix would then be the stall's collision shape rather
than this rule. Also reopen if `TEL-KILL-ATTEMPT` shows `OUT_OF_SIGHT` above ~5 % of presses,
which would mean players cannot read the gate.
