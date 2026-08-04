---
id: US-0062
title: SpawnSystem and respawn
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
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

- [ ] Six spawn points from MapData, all at street level.
- [ ] At least 40 m from the killer.
- [ ] At least 12 m from any living player.
- [ ] Falls back to the farthest available point when constraints are unsatisfiable.
- [ ] Respawn delay 5.0 s; 1.0 s spawn invulnerability.
- [ ] Suspicion resets to zero on respawn.
- [ ] Ability cooldowns reset on death.
- [ ] From any single camping position, at least three spawns remain valid.

## Test notes

`test_spawn_constraints.gd`, `test_spawn_anticamp.gd`.

## Notes

A spawn system that can FAIL is a crash waiting for a playtest, which is why the fallback is a
hard requirement rather than a nicety.

Spawn camping is defeated three ways: the 40 m constraint leaves at least three valid spawns the
camper cannot cover, only the camper's own contract is killable, and a camper standing still is
being hunted by their own pursuer.
