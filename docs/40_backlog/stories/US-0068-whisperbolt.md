---
id: US-0068
title: Ability — Whisperbolt
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY, ADR-0010]
---

# US-0068 — Ability: Whisperbolt

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY` |
| **Estimate** | M |
| **Depends on** | US-0067 |

## Description

A thrown blade: a ranged kill after a one-second wind-up during which the thrower is forced
Exposed.

Exists to punish rooftop campers.

## Acceptance criteria

- [ ] 40 s cooldown, 1.0 s wind-up, range 3 to 12 m, projectile 22 m/s.
- [ ] Minimum range EXCEEDS kill range, asserted as an invariant.
- [ ] Forces Exposed for the wind-up plus a 1.5 s tail, ON HIT AND ON MISS.
- [ ] A miss applies the failed-kill suspicion impulse.
- [ ] Requires LOS at release AND at impact, validated against the lag-compensated world.
- [ ] The caster is stunnable during the wind-up if the target reaches 3 m.
- [ ] Only kills the caster's own contract.
- [ ] The projectile visual spawns on server confirmation, not on prediction.

## Test notes

`test_whisperbolt_exposed.gd`, `test_whisperbolt_min_range.gd`, `test_whisperbolt_stunnable.gd`,
`test_whisperbolt_lagcomp.gd`.

## Notes

The 1.0 s wind-up is the whole balance of the ability; everything else is decoration. Shortening
it is not a buff, it is a different ability — and it would make the approach phase, which is the
entire game, optional.

A predicted projectile the server refuses would be a VISIBLE lie to other players, which is worse
than a one-RTT delay on a 0.55 s flight.
