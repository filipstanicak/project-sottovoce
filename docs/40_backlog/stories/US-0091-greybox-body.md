---
id: US-0091
title: A body to look at, and a light to see it by
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-12
depends_on: [BIBLE-ART, GDD-02-PLAYER]
---

# US-0091 — The greybox body

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-CAMERA` |
| **Systems** | `SYS-PAWN` |
| **Estimate** | S |
| **Depends on** | US-0021 |

## Description

**The camera had nothing to frame, and no light to frame it in.** `PersonaVisuals` was an empty
`Node3D` in both pawn scenes, and nothing anywhere in the project had ever created a light or an
environment — so the district rendered near-black and the player rendered not at all.

GDD-02 §4.1 puts this game in third person for exactly one reason: *judging how you look right
now is a core skill when anonymity is the resource*. A spring arm 2.6 m behind an invisible pawn
is a first-person camera with extra steps.

Asked for as "a blob or any form of character for visuals". It is not cosmetic — it is the thing
the camera exists to show.

## Acceptance criteria

- [x] The local pawn draws a body, procedurally, with no mesh asset in the repository.
- [x] The body is the size of the collider, standing on the pawn's origin rather than straddling
      it, with nothing protruding past the shape that collides.
- [x] Something marks the front, on `+Z`, agreeing with `ProbeLayout.forward(0)`.
- [x] The remote pawn wears the **same script**, not a copy.
- [x] The scene is lit well enough that value contrast exists at all (ART_BIBLE §3.1).
- [x] Nothing under `PersonaVisuals` collides.

## Three stories of camera work were built around an invisible pawn

US-0021's spring arm, US-0022's FOV ladder and US-0023's crowd-scan were each built, tested and
merged against a pawn that did not render. Every suite passed — they assert positions, distances
and lens values, and **a camera 2.6 m behind an invisible capsule satisfies all of them.**

Same family as the inverted pitch (#48) and the world-space stick (#51): the arithmetic was
right, and the result was not the one the design describes. `test_pawn_is_visible.gd` is the
assertion nobody had written.

## What it is, and what it deliberately is not

`GreyboxBody` measures the sibling `CollisionShape3D` rather than declaring a size. **A visual
that is not the size of the thing that collides is worse than no visual**: the player learns a
silhouette, aims at gaps with it, and is stopped by geometry they cannot see. The first version
sat the head *on* the capsule, putting its crown 0.22 m above the collider — caught by the test,
which is the only reason it is not shipped.

**It is not a persona.** ART_BIBLE §6.1 gives four greybox constructions, and each is a
silhouette *claim* that has to survive §1.2 at 40 m in solid black. Building one here would
assert an untested claim and start `PERSONA-*` work that belongs to US-0039 with its clone-parity
rules. So the figure is generic on purpose.

## The lighting is greybox, not the art pass

GDD-05 §9 makes lighting zones step 9 of the level-design pipeline, and this is not that. One key
light, shadows on, and a flat sky — chosen so that ART_BIBLE §3.1's "value over hue" has anything
to work with. Shadows are enabled because a shadowless greybox has no depth and every wall reads
as a flat panel.

## Found while looking, not fixed here

**`TUN-CAM-SHOULDER-OFFSET` currently changes nothing about the framing.** `CameraRig` offsets
the camera 0.45 m to one side and then calls `look_at(pivot)` — and the pivot is the pawn's own
axis, so the pawn re-centres in view no matter how far the camera slides. The offset alters the
viewing *angle* and never the composition, which means the body sits dead centre and occupies the
middle of the screen.

That was invisible while the pawn was invisible. It is a framing decision rather than a bug fix —
aiming at a point offset from the pivot would put the body off to one side, which is what an
over-the-shoulder camera is for — and §4.1's "Why" cell for that row is empty, so the intent is
not recorded anywhere. **Left for the owner**, who is the only person who can say what the shot
should look like.
