---
id: US-0057
title: Compass bearing and pulse
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, TUN-INDEX]
---

# US-0057 — Compass bearing and pulse

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-DETECTION` |
| **Systems** | `SYS-COMPASS` |
| **Estimate** | M |
| **Depends on** | US-0056 |

## Description

`CompassMath` — the distance-to-pulse-period curve and the wobbling direction cone.

## Acceptance criteria

- [ ] Period equals min plus range times the normalised distance raised to 1/exp.
- [ ] Period matches the TUNABLES section 4.2 sampled table at EVERY listed distance within 1 ms.
- [ ] Cone half-width 12 degrees, camera-relative.
- [ ] Wobble is DETERMINISTIC from contract id and tick — not RNG.
- [ ] Wobble is applied SERVER-SIDE so every peer sees the same cone.
- [ ] Snapshot carries bearing, a distance BUCKET and lock fraction — never an exact distance.
- [ ] Updates at 30 Hz, never containing information newer than the simulation.

## Test notes

`test_compass_curve.gd` asserts every row of the sampled table.

## Notes

The reciprocal exponent is the whole trick: flat far away, steep close in. The rate at 15 m is
41 percent faster than at 40 m; at 1 m it is triple. That asymmetry is the design requirement
expressed as a curve, and it is where the heart-rate change is.

Deterministic wobble rather than random jitter, because a player must be able to learn that the
cone drifts and compensate. Unlearnable noise is a deleted channel.
