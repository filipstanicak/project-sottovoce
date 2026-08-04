---
id: US-0044
title: Startle propagation, gawk and corpses
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-08-CROWD, GDD-03-SOCIAL-STEALTH]
---

# US-0044 — Startle propagation, gawk and corpses

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-BEHAVIOUR` |
| **Systems** | `SYS-CROWD`, `SYS-CORPSE` |
| **Estimate** | M |
| **Depends on** | US-0043 |

## Description

Startle waves with probabilistic propagation, token-capped gawk clusters, and corpses as
information objects.

## Acceptance criteria

- [ ] Violence startles within 12 m; a sprinting player within 5 m, evaluated once per second.
- [ ] Propagation at 0.4 probability within 5 m, capped at TWO hops by a per-agent flag.
- [ ] Startle waves read directionally to a human observer, not as a circle.
- [ ] Gawk tokens capped at 6; fleeing NPCs are skipped.
- [ ] A corpse beside a six-anchor pocket never drops it below four NPCs.
- [ ] Corpse persists 20 s; gawk cluster disperses at 6 s — two distinct information phases.
- [ ] NPC flee speed is below player sprint speed, asserted as an invariant.

## Test notes

`test_startle_propagation.gd` for the two-hop cap. `test_gawk_pocket_preservation.gd`.
`test_flee_slower_than_sprint.gd`.

## Notes

Probabilistic propagation rather than a bigger radius, because a hard-edged circle reads as a
RADIUS while a decaying wave reads as a DIRECTION — propagation continues furthest along the way
NPCs were already fleeing. That inference is the whole point.

The gawk cap prevents a corpse depopulating a pocket, which would make the site of a kill SAFER
to stand in afterwards.
