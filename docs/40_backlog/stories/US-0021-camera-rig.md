---
id: US-0021
title: Camera rig and occlusion
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-12
depends_on: [GDD-02-PLAYER, TUN-INDEX]
---

# US-0021 — Camera rig and occlusion

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-CAMERA` |
| **Systems** | `SYS-CAMERA` |
| **Estimate** | M |
| **Depends on** | US-0015 |

## Description

Third-person spring arm with shoulder offset, swap and occlusion handling.

> **PARTLY SUPERSEDED BY US-0092, 2026-08-12.** The shoulder offset and swap are deprecated: the
> pawn is centred. The criteria below are left ticked as written, because they were true — the
> arm did carry a 0.45 m offset and the swap did take 0.25 s. What none of it did was change the
> *framing*, since the rig aimed at the pawn's own axis and the pawn re-centred in view
> regardless. Nobody could see that until there was a body to see (US-0091).

Third-person rather than first because the player must be able to see their own silhouette —
judging how you look right now is a core skill, and a first-person camera makes it impossible.

## Acceptance criteria

- [x] Spring arm 2.6 m, pivot 1.55 m, shoulder offset 0.45 m, all from tunables.
- [x] Shoulder swap in 0.25 s.
- [x] Occlusion pulls in at 12 m/s and restores at 4 m/s — slower restore prevents doorway oscillation.
- [x] NPCs do NOT occlude the camera.
- [x] The arm never pulls sideways to a position granting sight around a corner the player could not see around on foot.
- [x] Camera control is retained during KillAnim, Vault and Drop.
- [x] Camera control is REMOVED while Stunned — it snaps to a fixed offset.

**No key is bound to the shoulder swap yet.** `CameraRig.swap_shoulder()` is complete and
tested; `INPUT-SHOULDER` is bound in `project.godot` but nothing calls the method, because
routing a camera-only input needs somewhere for camera-only inputs to be routed and there is no
such seam until the HUD arrives. Nothing about the swap is unfinished — the wire is.

## Test notes

Verify by walking into a six-NPC pocket with no arm pull-in.

**Done with bodies rather than NPCs**, since `SYS-CROWD` is M3. `test_camera_rig_geometry.gd`
puts a `StaticBody3D` on the `NPC` layer exactly where a `WORLD` body demonstrably shortens the
arm, and asserts the arm does not move. A mask is a number, and a number that is wrong looks
exactly like a number that is right.

## Notes

If NPCs pushed the camera in, a dense crowd — the safest place in the game — would become the
place where the camera is least usable.

---

## The fairness rule, and why it is not a spring arm

§4.4 rule 2 forbids the ordinary behaviour of a spring arm. A standard one, blocked, **slides
along the surface** until it finds clearance — and a player pressed against a corner therefore
gets a free look down the street beyond it. Camera position becomes an information channel, in a
game that spends design law 6 on making every other channel authored and bounded.

So the arm shortens **along its own line**, never sideways, and the shoulder offset is part of
that line rather than applied after it. Pulling in costs the player the view instead, which is
the honest answer: you cannot see round the corner, because you are not round the corner.

`test_camera_arm.gd` asserts the direction is bit-identical before and after a pull-in. That
assertion is the rule.

## What US-0021 replaced

`DebugFollowCamera` is gone, deleted rather than left in `scripts/debug/`. It existed from
US-0016 so a human could see the pawn at all, and it said in its own docstring that it must not
outlive the rig it stood in for.

## What this story does not do

- **No FOV ladder.** US-0022. The rig holds `TUN-CAM-FOV-STROLL` and does not read the pawn's
  speed state, so §4.2's warning channel — the widening lens that tells you pre-consciously
  that you are being conspicuous — does not exist yet.
- **No crowd-scan.** US-0023. `INPUT-SCAN` reaches the wire and nothing reads it.
- **No camera shake, no motion-reduction mode.** §9.4's accessibility provisions are US-0084.
- **Look sensitivity is not a tunable**, for the same reason it is not one in `InputSampler`: it
  is a per-player preference in the class of a volume slider, and belongs to `IProfileStore`
  (stubbed, ASM-0026).
