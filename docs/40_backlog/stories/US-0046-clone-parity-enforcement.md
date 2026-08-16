---
id: US-0046
title: Clone parity enforcement
version: 0.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-16
depends_on: [BIBLE-ANIMATION-SPEC, BIBLE-AUDIO, GDD-03-SOCIAL-STEALTH]
---

# US-0046 — Clone parity enforcement

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-ANONYMITY` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0045 |

## Description

All four enforcement layers for the constraint the entire anonymity model rests on.

Four layers because a single check gets deleted eventually by someone who does not understand it.

## Acceptance criteria

> **Three of seven, and this story turned out to contain something it never mentioned.** Four
> other documents point at US-0046 for "the meshes"; US-0046 never says the word. See below.

- [x] **Layer 1: `PersonaData.anonymous_clip_names` lists the 14-clip parity set per persona.**
      Four `.tres` in `data/personas/`, and the set is a `const` on `PersonaData` rather than four
      copies — §7.1's table has a tick in every cell, and four copies of one list is four places
      for it to drift invisibly.
- [ ] **Layer 2: `test_clone_animation_parity.gd` passes for all four personas.** The
      **declaration** half is asserted: the set is the documented fourteen, every clip is a
      harvested `ANIM-` id, every persona declares all of them and nothing else, the four
      silhouettes and hues are mutually distinct. The **library** half cannot pass — there are no
      animation clips in this project on either rig — so it reports and turns real by itself the
      day the first `AnimationLibrary` lands.
- [ ] **Layer 3: debug builds assert the clip played in an Anonymous-reachable state is in the
      parity set.** `PersonaData.is_anonymous_clip()` is the check; there is no call site,
      because a call site needs an `AnimationTree` playing a clip and neither exists. Unticked
      rather than ticked on a function nobody calls.
- [ ] **Layer 4: covered by US-0047.** Not this story's.
- [ ] **Player and NPC footsteps use identical clips, radii and stride timing.** Blocked:
      `Audio.play()` is an empty stub until **US-0075**.
- [ ] **The idle-variation cycler graph and weights are identical on both rigs.** Blocked: there
      is no `AnimationTree` and no rig.
- [x] **No per-instance variation on any clone: no tint, no accessory shuffle, no scale jitter.**
      `test_no_clone_variation.gd` scans everything that draws a clone for `randf`, `randi`,
      `RandomNumberGenerator`, `pick_random` and `shuffle`, falsified against a planted tint
      jitter — and asserts a body is **told** its persona rather than choosing one, because
      GDD-03 §6.3 rule 4 derives personas from `match_seed` on every peer.

## Four documents point here for the meshes and this story never mentions one

Found while starting it, and worth recording because it is a backlog defect rather than a code
one:

| Says | Where |
|---|---|
| "any mesh at all — **US-0046**" | US-0039's omission table |
| "NPC meshes are **US-0046**" | US-0044 |
| "no `NpcView`, no mesh — **US-0046**" | US-0045, TDD-08 §11.1 |
| the four greybox personas "belong to **US-0039**" | ART_BIBLE §6.1 |
| "Four personas, silhouette-distinct at 40 m — **M3**" | `SCOPE_FENCE` IN #3 |

US-0039 shipped without them and US-0046's criteria are all *enforcement*. So the four
constructions were an M3 deliverable owned by **no story's acceptance criteria**, which is how a
scope item goes missing without anything failing.

They are built here: `PersonaBody`, procedural from primitives, one per ART_BIBLE §6.1 row. That
is a deliberate widening of this story rather than a silent one.

## What the first render of them showed, which no test did

ART_BIBLE §6.1's rows are silhouette **claims**, and §1.2 judges them rendered, at distance, in
solid black, by a human. `tools/persona_lineup.gd` is what produces that picture; it **refuses to
run headless**, because a blank PNG reads exactly like a bad model (trap 13).

The first render showed **Lucerna's pole floating detached beside the figure** — §6.1 says
"cylinder pole 0.9 m above head", which is where its *top* goes, and a cylinder only 0.9 m long
put the whole thing in the air. It runs from hand height now, so the silhouette reads as somebody
*carrying* something. No assertion in this repository would ever have caught that.

Also settled at the same time: Cantatrice's skirt is **1.5× the capsule radius, not 2×**. A skirt
that overhangs the collider too far is the silhouette lying about the thing it stands for — a
hunter reads a shape they cannot walk through and aims at a gap that is really open.

**The §1.2 judgement itself is unticked and is the owner's**, exactly like M1's feel gate. What a
machine can hold is the geometry underneath it, and `test_persona_silhouettes.gd` holds it.

## The two width claims are different claims

§6.1 says Vetraio is `LOW_BROAD` — ×1.4 at the **shoulders** — and Cantatrice is
`FLOOR_TRIANGLE` — a cone widening toward the **ground**. The first version of the silhouette
test asked which figure was widest *overall*, got Cantatrice, and read like a modelling error. It
was the assertion that was too crude. Measured: shoulders 0.98 vs 0.43, floor 0.70 vs 1.05.

## Nothing wears a persona yet

`PersonaBody` is built by the lineup tool and by its tests. The **pawn still wears
`GreyboxBody`**, because nothing chooses a persona for a player: there is no lobby and
`NET-C2S-LOADOUT` is M4's. And the crowd cannot wear one either — **no NPC is on the wire**, so
there is no client-side NPC to dress.

That is worth being blunt about, because the obvious reading of "the personas exist" is "you can
see the crowd now", and you cannot.

## Test notes

| Test | Asserts |
|---|---|
| `test_clone_animation_parity.gd` | Four personas with four `PERSONA-` ids; the parity set is the documented fourteen with no duplicates; every clip is a harvested `ANIM-` id; every persona declares all fourteen and nothing else; four distinct silhouettes; four distinct identity hues; ART_BIBLE's own heights. The library half **reports** |
| `test_persona_silhouettes.gd` | Every persona builds a figure; the heights are §6.1's; **no two have the same proportions**; Lucerna is tallest, Vetraio broadest at the shoulder, Cantatrice broadest at the floor |
| `test_no_clone_variation.gd` | Nothing that draws a clone is random, falsified against a planted tint jitter; a body is told its persona rather than choosing one |

`test_footstep_parity.gd` is not written: `Audio.play()` is a stub until US-0075.

**`StringName` does not sort alphabetically.** Godot orders it by internal pointer, so
`Array.sort()` on a list of them returns a stable but arbitrary order — the first version of the
four-personas assertion got them back reversed and read like a genuine mismatch. Compare as
`String`.

## Notes

This constraint fails SILENTLY. An animator adds a charming idle on the player rig, nothing
breaks, no test fails, crowd count is unchanged — and three weeks later skilled testers pick
humans out reliably and cannot say why. Human review misses this every time.

The parity boundary is exactly the suspicion cliff at stroll speed: anything free is imitated,
anything that costs is exposed.
