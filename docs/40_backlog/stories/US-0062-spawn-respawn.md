---
id: US-0062
title: SpawnSystem and respawn
version: 1.1.0
status: done
owner: Technical Director
last_updated: 2026-08-27
depends_on: [GDD-05-LEVEL, TDD-10-SCORING]
---

# US-0062 — SpawnSystem and respawn

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-COMBAT` |
| **Systems** | `SYS-SPAWN` |
| **Estimate** | S |
| **Depends on** | US-0061 |

## Description

Constrained spawn selection with a fallback that cannot fail.

## Acceptance criteria

- [x] Six spawn points from MapData, all at street level. **`PawnHost`'s round-robin
      placeholder is gone** — a join and a respawn now go through the same `SpawnRules.choose`,
      differing only in that a joiner has no killer, so the two cannot drift apart.
- [x] At least 40 m from the killer (`TUN-RESPAWN-MIN-DIST-FROM-KILLER`).
- [x] At least 12 m from any living player (`TUN-RESPAWN-MIN-DIST-FROM-ANY-PLAYER`), asked of
      **every** living player rather than the nearest one.
- [x] Falls back to the farthest available point when constraints are unsatisfiable — and the
      fallback is **deterministic**, because it runs at the worst moment in a match and the
      least bad answer is a property of the world rather than a draw.
- [x] Respawn delay 5.0 s; 1.0 s spawn invulnerability. The delay **is** the `Respawning`
      state; the invulnerability begins after it, in `CombatLockouts`, and is read by both
      combat systems.
- [x] Suspicion resets to zero on respawn — **through `TUN-RESPAWN-SUSPICION`**, which had no
      reader at all before this story: `PawnContext.reset_for_spawn` writes a literal `0.0`
      that *agrees* with the tunable without reading it.
- [x] Ability cooldowns reset on death.
      **Done in US-0066, and not where this story expected.** The note here read
      *"`reset_for_spawn` is the one call site and will honour them when they
      exist"*, and that would have been wrong: `PawnContext` is **replayed during
      prediction reconciliation**, so a cooldown living there would be rewound and
      re-applied on every correction. `AbilitySystem.on_death` owns them and
      `server_root._on_killed` calls it in the tick the death resolves.
- [x] From any single camping position, at least three spawns remain valid. **Swept over
      3 721 positions on a 2 m grid rather than the four the analysis names**, and the worst
      is exactly 3 — at (0, 58), which is not one of the four.

## As built, 2026-08-26 — seven of eight

**`Dead` HAS AN EXIT AT LAST, AND THAT IS THE HEADLINE.** The graph's only edge out of it is
`Dead -> Respawning`, and `Respawning` was the last unregistered state in the machine — so a
player killed at any point since US-0060 stayed dead for the rest of the match. **All fifteen
states now exist.**

**`SYS-SPAWN` IS NOT A `GameSystem`, FOR THE THIRD TIME AND FOR THE THIRD REASON.** TDD-01
§4's diagram has **no spawn box at all**, and its stage 8 is *"Contract — repair cycle after
deaths"*. A respawn is a repair after a death, so `ContractSystem` owns and ticks it — and it
ticks **first**, so a player whose timer expires is placed and reinserted into the cycle in the
same tick. There is never a tick in which somebody stands on the map holding no contract.

**BOTH RESPAWN EDGES ARE COMPLETIONS, NOT INTERRUPTIONS — TRAP 8, AND IT COST THE FIRST RUN.**
`Dead` and `Respawning` are both FATAL and both decline every interruption, so an interrupting
request at FATAL priority is refused by `priority <= current.interrupt_priority()` and the pawn
**stays dead forever** — exactly the symptom this story exists to fix, reproduced by the fix.
`PawnStateMachine.transition` takes an `interrupting` flag and `step()` passes false, because
*a state asking to leave is completion*; the server holds these two clocks because the position
a respawn lands at is chosen from the live lobby and a client cannot know it.

**THE POINT IS CHOSEN WHEN THE TIMER EXPIRES, NEVER WHEN THE PLAYER DIED.** Five seconds is
long enough for the whole lobby to move, and a point chosen at the contact frame would satisfy
rule 3 against a world that no longer exists.

**`TUN-RESPAWN-INVULN` IS A THIRD LOCKOUT SHAPE, NOT A STAGGER WITH THE SIGN FLIPPED.** The
stagger and the exile restrain an *initiator*; this one shields a *target*, so both combat
systems gained a `TARGET_PROTECTED` verdict that **costs the presser nothing** — they did
everything right and the game said no for a reason about the victim.

**AND THE ANTI-CAMP ANALYSIS IS CONFIRMED AND ITS EVIDENCE WAS THIN.** GDD-05 §2.7 concludes
*"worst case: three valid spawns remain"* from **four hand-picked positions**. Swept over
3 721 on a 2 m grid the answer is the same — 3 — but the worst position is **(0, 58)**, the
map's western edge, which is none of the four.

**RETRACTED 2026-08-27: THIS STORY PUBLISHED "TWO CAMPERS STANDING ON SPAWN POINTS REDUCE IT
TO ONE (`S2` + `S4`)", AND IT WAS MEASURED AGAINST A RULE THE GAME DOES NOT HAVE.** The test
asked `clear_of_killer` — **40 m** — of both campers, where `SpawnRules.candidates` applies
40 m to the killer alone and rule 3's **12 m** to everybody else. Planting the 40 m radius into
`clear_of_everyone` reproduces the retracted "1" exactly.

**CORRECTED: A KILLER AND AN ACCOMPLICE LEAVE TWO**, one body denies at most one spawn (rule
1's 30.86 m against 2 x 12 m), and with a body on **every** spawn point the rule 7 fallback
still places the victim **61.5 m from their killer** — better than the 40 m rule 2 asks for.
**No rule for coordinating campers is needed.** GDD-05 §2.7 carries the full table.

## Test notes

| File | Asserts |
|---|---|
| `test/unit/core/spawn/test_spawn_constraints.gd` | Both constraints, together and apart; that the fallback picks the furthest point and is deterministic; that `NO_KILLER` is `INF` rather than the origin, which is a real place on this map; and that the pick is seeded and reproducible |
| `test/unit/core/map/test_spawn_anticamp.gd` | The 3 721-position sweep, the same sweep restricted to standable ground, §2.7's own four rows, the conspiracy case and the fallback's clearance. **It opens with a counterfactual**, because every assertion in it is of the form *"at least three remain"* — which a rule that excludes nothing satisfies perfectly. **Its masks are taken from `SpawnRules` rather than recomputed from a radius**, which is what the retraction below cost |
| `test/unit/systems/spawn/test_spawn_system.gd` | The lifecycle: `Dead` leads somewhere, the delay is counted in net ticks, the point is chosen at expiry rather than at death, suspicion comes back through the tunable, and the cycle is repaired in the tick of the placement |

**Falsified against four planted defects.** `clear_of_killer` always true reddened the killer
constraint and the two-constraint test; a frozen `_fallback` reddened both fallback tests; the
interrupting form of `transition` reddened all three lifecycle tests; and a no-op `protect`
reddened the invulnerability.

**The fifth plant is the one worth recording: `clear_of_killer` always true left
`test_spawn_anticamp.gd` entirely green.** That file is about the *map*, and it would not have
noticed the rule was gone. Its counterfactual was added because of that measurement, and it
goes red against the same plant now.

**AND THREE MORE ON 2026-08-27, WITH THE RETRACTION ABOVE.** A 40 m `clear_of_everyone`
reddens the second-camper test and drops the conspiracy figure to the retracted 1; an inverted
`_fallback` reddens the clearance test at 0.0 m; and `TUN-RESPAWN-MIN-DIST-FROM-ANY-PLAYER`
raised to 18.0 — past half the closest spawn separation — reddens the one-body rule. **The
first of those is what a modelled sweep could not have told anybody**: before the masks came
from `SpawnRules`, that plant left the conspiracy figure reading 2 with nothing red.

## Notes

A spawn system that can FAIL is a crash waiting for a playtest, which is why the fallback is a
hard requirement rather than a nicety.

Spawn camping is defeated three ways: the 40 m constraint leaves at least three valid spawns the
camper cannot cover, only the camper's own contract is killable, and a camper standing still is
being hunted by their own pursuer.
