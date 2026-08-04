---
id: US-0021
title: Camera rig and occlusion
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
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

Third-person rather than first because the player must be able to see their own silhouette —
judging how you look right now is a core skill, and a first-person camera makes it impossible.

## Acceptance criteria

- [ ] Spring arm 2.6 m, pivot 1.55 m, shoulder offset 0.45 m, all from tunables.
- [ ] Shoulder swap in 0.25 s.
- [ ] Occlusion pulls in at 12 m/s and restores at 4 m/s — slower restore prevents doorway oscillation.
- [ ] NPCs do NOT occlude the camera.
- [ ] The arm never pulls sideways to a position granting sight around a corner the player could not see around on foot.
- [ ] Camera control is retained during KillAnim, Vault and Drop.
- [ ] Camera control is REMOVED while Stunned — it snaps to a fixed offset.

## Test notes

Verify by walking into a six-NPC pocket with no arm pull-in.

## Notes

If NPCs pushed the camera in, a dense crowd — the safest place in the game — would become the
place where the camera is least usable.
