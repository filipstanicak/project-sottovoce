---
id: US-0046
title: Clone parity enforcement
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
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

- [ ] Layer 1: `PersonaData.anonymous_clip_names` lists the 14-clip parity set per persona.
- [ ] Layer 2: `test_clone_animation_parity.gd` passes for all four personas.
- [ ] Layer 3: debug builds assert the clip played in an Anonymous-reachable state is in the parity set.
- [ ] Layer 4: covered by US-0047.
- [ ] Player and NPC footsteps use identical clips, radii and stride timing.
- [ ] The idle-variation cycler graph and weights are identical on both rigs.
- [ ] No per-instance variation on any clone: no tint, no accessory shuffle, no scale jitter.

## Test notes

`test_clone_animation_parity.gd`, `test_footstep_parity.gd`.

## Notes

This constraint fails SILENTLY. An animator adds a charming idle on the player rig, nothing
breaks, no test fails, crowd count is unchanged — and three weeks later skilled testers pick
humans out reliably and cannot say why. Human review misses this every time.

The parity boundary is exactly the suspicion cliff at stroll speed: anything free is imitated,
anything that costs is exposed.
