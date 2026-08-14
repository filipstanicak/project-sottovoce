---
id: US-0094
title: The wall cling — a steered climb, and the reversal it requires
version: 1.0.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-13
depends_on: [GDD-02-PLAYER, GDD-05-LEVEL, BIBLE-ANIMATION]
---

# US-0094 — The wall cling

| | |
|---|---|
| **Milestone** | **Unassigned — see §Scope** |
| **Epic** | `EPIC-TRAVERSAL` |
| **Systems** | `SYS-TRAVERSAL`, `SYS-PAWN`, `SYS-CAMERA` |
| **Estimate** | L |
| **Depends on** | US-0017–0020 |

## Description

Asked for by the owner, in these words:

> I dont like the climb mechanic. If i am near a wall and press space i should be stuck on the
> wall. If i am on the wall, w makes me move up, s down, a to the left and d to the right. My
> camera should be zoomed out a little bit so i have an overview. if i press space again i jump
> into the direction if my camera. If i am facing the wall i jump the wall a bit up.

**This story is written and not built, deliberately.** It is here so the decision below can be
made once, in writing, before any code depends on it.

---

## 1. It reverses a normative principle, and that is the whole story

GDD-02 §7 is titled **"Parkour — assisted, not simulated"**, and §1.1 principle 1 says:

> **One contextual traverse.** Vault, mantle, climb, drop-swing and gap-jump resolve from one
> input by context (§7). The player never chooses *which* manoeuvre; they choose *whether* to
> move through the world athletically, and the game resolves how.

A cling the player **steers** — up, down, left, right, and off in a chosen direction — is the
opposite claim. It makes the player choose the manoeuvre and then execute it, which is simulated
parkour by the §7 definition.

**That is a legitimate change for the owner to make.** It is not a legitimate change for an agent
to make quietly inside a bug fix, which is why this document exists before the code does.

What the reversal costs, stated plainly so it is not discovered later:

| §7 promise | What the cling does to it |
|---|---|
| "The player never chooses which manoeuvre" | They choose, and then steer it. |
| "The player's attention should be on the *crowd*, not on their own footwork" (§7.3) | A steered climb is footwork that demands attention for as long as it lasts. |
| The 0.45 s forgiveness window around every traverse | Forgiveness is about *entering*. It says nothing about a mode you are inside of, so §7.3 will need a paragraph about what forgiveness means here — or an explicit note that it means nothing. |

**Nothing else in the design objects.** Design law 1 is satisfied as long as the cling costs
anonymity (§4 below); law 3 does not apply, because a cling is not an ability; law 5 is untouched.

---

## 2. What it replaces

`ClimbState` today is a **planned interpolation**, not a mode:

- The traversal resolver picks it (§7.2 case 6: `CHEST` hit on a climbable surface, height ≤
  `TUN-TRAVERSE-CLIMB-MAX-HEIGHT` 9 m).
- `enter()` freezes the velocity; `step()` lerps `ctx.position` from `traverse_start` to
  `traverse_target` at `TUN-SPEED-CLIMB`, so a 9 m façade takes 3.2 s and a 3 m one takes 1.1 s.
- The only input it reads is "pull away", which releases into a `Drop` planned from wherever you
  had reached.
- It costs `TUN-SUSPICION-GAIN-CLIMB` 12/s while it runs.

The cling keeps the *entry* (the resolver, the probes, the forgiveness buffer) and replaces
everything after it. **`traverse_target` stops being meaningful**: there is no plan, because the
player is the plan.

---

## 3. Proposed mechanics

Written as a proposal. Every number is marked **PROPOSED** and none of them has a row in
TUNABLES.md — minting the IDs is part of building this, not part of writing it.

### 3.1 Attaching

Space near a climbable surface attaches, using the existing `CHEST` probe and the existing
forgiveness buffer. **Unchanged from today's entry**, which is the part worth keeping: the player
still presses one button at a wall.

### 3.2 Moving on the wall

`INPUT-MOVE` in the **wall's** plane, not the camera's: W up, S down, A and D along the face.

> **This is the one place the camera-relative rule (§2) does not apply, and it needs saying in
> the GDD.** On a wall the player's frame *is* the wall. Reading the stick in the camera's frame
> while clinging would make A and D reverse as the camera swung round the pawn — which is
> precisely the defect fixed in #51, arriving from the other direction.

| PROPOSED | Value | Why |
|---|---|---|
| `TUN-CLING-SPEED-UP` | 2.8 m/s | Same as `TUN-SPEED-CLIMB`, so the roof economy is unchanged at the start. |
| `TUN-CLING-SPEED-DOWN` | faster than up | Descending is the retreat, and ADR-0012's asymmetry says the defensive option is cheap. |
| `TUN-CLING-SPEED-LATERAL` | slower than up | Traversing sideways is the deliberate, patient option. |

Lateral motion needs a **surface query per tick**: the wall may end, turn a corner, or have a
window in it. Running off the edge of a face is the first thing a playtest will do.

### 3.3 The camera

The owner asked for it to be *zoomed out a little* for an overview.

**It must not read as a speed warning.** GDD-02 §4.2 binds FOV to the speed *state* and calls it
a warning channel; a cling that widened the lens would tell the player, in the game's own
pre-conscious language, that they were sprinting. So: **change the arm length, not the FOV.**

| PROPOSED | Value | Why |
|---|---|---|
| `TUN-CAM-CLING-ARM-LENGTH` | ~3.6 m | Further than `TUN-CAM-ARM-LENGTH` 2.6 m. The overview the owner asked for. |

The lens stays on `TUN-CAM-FOV-CLIMB` 62°, which already exists.

### 3.4 Leaving

| Input | Result |
|---|---|
| Space, camera pointed away from the wall | Jump in the camera's direction — the request as made. |
| Space, camera pointed **at** the wall | A short hop **up** the face, keeping the cling. |
| S at the bottom | Step off, no fall. |
| Pull away (as today) | Release into a `Drop` from where you are. |

The camera-direction jump is the part that changes the game's reachability. See §5.

---

## 4. The suspicion question, which is the owner's

**A cling you can hang on for free is a hiding place on a façade**, and that is a real change to
the anonymity economy, not a detail.

Today's numbers: climbing costs 12/s, being on a roof costs 18/s **with no decay running**, and
the toll exists (TUNABLES §3.2) precisely to stop roofs being strictly better than streets. A
player who can attach to a wall at head height and hang there indefinitely at zero cost has found
a spot with a view, no crowd, and no price.

Three options, and this needs an answer before implementation:

1. **Clinging costs what climbing costs** (12/s), whether or not you are moving. Simplest, and it
   makes hanging expensive — you cannot wait on a wall.
2. **Clinging costs while moving, and decays while still.** Rewards the patient reading of the
   street from a wall, which fits design law 4 — and creates exactly the free perch above.
3. **Clinging costs a reduced rate**, with a separate tunable. More knobs, more to balance.

**Recommendation: option 1**, on the grounds that it changes nothing about the existing roof
economy and cannot create a free perch. But this is a balance decision and it is the owner's.

---

## 5. What else it touches

- **The level-design contract (GDD-05 §7.4, GDD-02 §7.4).** MAP-VETRAIO's gaps, façade heights
  and roof access were sized around vault / mantle / climb / drop / gap-jump. **A directional
  wall-jump is a new traversal verb the blockout was never designed against**, and it will make
  roofs reachable from places the level intends to be closed. Expect a survey pass, not a tweak.
- **The netcode.** A cling is a pawn state and is replayed during prediction reconciliation
  (US-0032). Surface queries must be deterministic and taken in the physics step — never a
  raycast at render time, and never `Time.*` inside `scripts/pawn/` (never-do #9).
- **Animation.** ANIMATION_SPEC will need cling clips: hold, up, down, lateral, and the wall-jump
  push-off. **None exist**, and none is blocking — the state works without them, exactly as
  everything else in M1 does.
- **The state machine.** At least one new `PawnStateId`, and edges in both directions against the
  normative §3 diagram. `Jog` is the precedent for how a state is retired; adding one is the same
  work in reverse.
- **`test_commitment_ceiling.gd`.** A cling is a state you can leave on any tick, so it is not a
  commitment — the same reasoning that exempts today's `Climb` at 3.2 s. That must stay true: a
  cling you cannot get out of would breach §5's 1.4 s ceiling by a wide margin.

---

## 6. Traps that will bite this specifically

1. **Trap 7 — a state that writes `ctx.position` must return `true` from `drives_position()`**,
   or `LocalPawnDriver` runs `move_and_slide()` and overwrites it from a body that has not moved.
   `ClimbState` already does this; the cling must too, and its lateral motion makes it easier to
   get half-right.
2. **Trap 8 — a state's own exit is not an interruption.** Gating the wall-jump on
   `is_interruptible()` would make the cling permanent, and the symptom is a frozen player, not
   an error.
3. **Trap 9 — two tick domains.** Anything counted inside `step()` uses `Tuning.step_ticks()`.
4. **Trap 4 — assert the shape.** "The pawn moved up" is true of a pawn falling *past* a wall it
   failed to attach to. Assert against the wall's normal and the pawn's facing, not a world axis.

---

## 7. Scope

**Not assigned to a milestone.** M1's exit is one player walking, blending, running, sprinting,
climbing and vaulting — which is met by the climb that exists. This story replaces a working verb
with a better one, and that is improvement rather than exit criteria.

It also is not in `SCOPE_FENCE.md`'s OUT list: `SYS-TRAVERSAL` is in scope and this changes how
one of its verbs behaves, so no fence decision is needed.

**Recommendation: after the M1 feel gate, and after US-0093.** The gate judges the traversal
forgiveness windows, and rebuilding the climb underneath an unrun gate would mean judging a
controller mid-rewrite.

---

## Acceptance criteria

None are ticked. Nothing is built.

- [ ] The §7 reversal is signed off by the owner, in GDD-02 §7, before code starts.
- [ ] Space at a climbable surface attaches, using the existing probe and forgiveness buffer.
- [ ] W/S/A/D move along the wall **in the wall's frame**, and GDD-02 §2 records that exception.
- [ ] The face's edges are respected: no clinging past the end of a surface.
- [ ] The camera pulls back to `TUN-CAM-CLING-ARM-LENGTH` and **the FOV does not change**.
- [ ] Space away from the wall jumps in the camera's direction; Space into the wall hops up.
- [ ] Suspicion while clinging is whatever §4 decides, and TUNABLES records the decision.
- [ ] `test_commitment_ceiling.gd` still classifies the cling as escapable on any tick.
- [ ] The level-design survey is done: what the wall-jump now reaches that it should not.

## Open questions for the owner

1. **What does clinging cost in suspicion?** §4. Blocking — it decides whether a façade is a
   hiding place.
2. **Does the cling replace `Climb` entirely, or coexist with it?** A player who just wants to
   get up a wall may not want to steer. Coexisting means two verbs on one button, which §7 exists
   to prevent.
3. **Is there a maximum cling time or a stamina cost?** Nothing in the design has stamina today,
   and adding one is a system, not a number.
4. **Does the wall-jump reach further than a gap-jump** (`TUN-TRAVERSE-GAP-MAX` 3.2 m)? If it
   does, it becomes the fastest way across the district and the speed ladder stops being the only
   speed decision.
