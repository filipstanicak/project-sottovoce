---
id: US-0067
title: Ability — Cinderfall
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY]
---

# US-0067 — Ability: Cinderfall

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY` |
| **Estimate** | M |
| **Depends on** | US-0066 |

## Description

Area denial: a thrown ash-pot that blocks line of sight and forbids kill initiation.

Exists to give a punished attacker exactly one escape.

## Acceptance criteria

- [ ] 45 s cooldown, 0.45 s cast, 8 m throw range, 5 m radius, 4 s duration.
- [ ] Blocks LOS for detection, lock progression and Focus accumulation.
- [ ] Forbids kill INITIATION inside the radius FOR EVERYONE, INCLUDING THE CASTER.
- [ ] A kill already in progress completes.
- [ ] Applies +40 suspicion.
- [ ] Startles NPCs within 9 m.
- [ ] Registered with DetectionSystem as an LOS blocker and with KillSystem as an initiation blocker; deregistered on expiry.

## Test notes

`test_cinderfall_self_block.gd`, `test_cinderfall_blocks_los.gd`, `test_cinderfall_startle.gd`.

## Notes

The self-block is the detail that carries the ability. Without it the dominant play is "cloud,
then kill inside it", and a kill nobody can see is a legibility-law violation wearing an
ability's clothes.

The 9 m startle radius is the honest cost: the cloud hides you and simultaneously paints a
fleeing-crowd arrow at your position for everyone within 30 m.
