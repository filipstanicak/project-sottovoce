---
id: US-0022
title: Camera FOV ladder
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-02-PLAYER, TUN-INDEX]
---

# US-0022 — Camera FOV ladder

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-CAMERA` |
| **Systems** | `SYS-CAMERA` |
| **Estimate** | S |
| **Depends on** | US-0021 |

## Description

FOV bound to speed state, transitioning at 90 deg/s.

This is not a style choice, it is a warning system. The widening FOV at speed produces peripheral
distortion that tells the player pre-consciously that they are doing something conspicuous,
before they read the tier indicator.

## Acceptance criteria

- [ ] FOV per state: 55 blend, 60 stroll, 65 jog, 69 run, 72 sprint.
- [ ] Transitions at 90 deg/s.
- [ ] FOV matches the ladder within 1 degree at each steady speed state.
- [ ] Each PawnState returns its own camera_fov from CameraTuning.
- [ ] Motion-reduction mode locks FOV at 62 and the compensating indicator is added elsewhere.

## Test notes

`test_camera_fov_ladder.gd` samples FOV at each steady state.

## Notes

The narrow blend-walk FOV does the opposite job: it compresses the scene and makes distant faces
larger and more comparable. Slowing down literally lets you see more clearly — the thesis
rendered as a lens.
