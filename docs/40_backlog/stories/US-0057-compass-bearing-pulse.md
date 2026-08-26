---
id: US-0057
title: Compass bearing and pulse
version: 0.2.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-08-26
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

- [x] Period equals min plus range times the normalised distance raised to 1/exp.
- [x] Period matches the TUNABLES section 4.2 sampled table at EVERY listed distance within 1 ms.
      **Measured worst case 0.40 ms** across all twelve rows.
- [ ] Cone half-width 12 degrees, camera-relative.
      **The server's half is done and the drawn half does not exist.**
      `TUN-COMPASS-CONE-HALFWIDTH` is asserted wider than the wobble, so the true bearing is always
      inside the rendered arc - but nothing renders an arc: `CompassVM` and the HUD are US-0084.
      The bearing is sent as a **world** angle the client rotates by its own yaw, because a
      camera-relative one computed server-side would lag the mouse by the round trip.
- [x] Wobble is DETERMINISTIC from contract id and tick — not RNG.
- [x] Wobble is applied SERVER-SIDE so every peer sees the same cone.
- [x] Snapshot carries bearing, a distance BUCKET and lock fraction — never an exact distance.
      Bearing and bucket are filled; **`lock_fraction` is US-0058's and reads zero.**
- [x] Updates at 30 Hz, never containing information newer than the simulation.
      It is computed in the `detection` stage of the net tick and read in the `snapshot` stage of
      the same one, so it cannot be newer by construction.

## Test notes

`test_compass_curve.gd` asserts every row of the sampled table.

---

## What was found building it

**THE PUBLISHED TABLE IS CORRECT, AND THAT WAS WORTH CHECKING FIRST.** All twelve rows reproduce
from the four shipped tunables to **0.40 ms** worst case. This is the fourth audit of a documented
table in this project, and the first to find one entirely right rather than partly fiction.

**THE CURVE IS 58x STEEPER CLOSE IN THAN FAR OUT** - 0.4593 Hz/m over the last ten metres against
0.0079 Hz/m over the first ten. GDD-03 §8.2's "long, flat approach followed by a sudden sense of
imminence" is that ratio, and `test_compass_curve.gd` prints it.

**A SHAPE TEST WOULD NOT HAVE CAUGHT THE ONE MISTAKE THIS CURVE INVITES.** `pow(t, 2.2)` instead
of `pow(t, 1/2.2)` is still monotone, still bounded by `TUN-COMPASS-PULSE-MIN` and `-MAX`, and
exactly backwards - a long tense approach followed by nothing. The sampled table is what separates
them; so is the gradient assertion.

**THE BEARING IS WORLD AND THE CONE IS CAMERA-RELATIVE, WHICH IS NOT THE SAME CRITERION.** The
client rotates the arc by its own yaw every rendered frame; a camera-relative bearing computed on
the server would lag the mouse by the round trip on the one HUD element that must track the
player's head. The **wobble** stays server-side because it is gameplay - two players standing
together must be lied to identically, or they could compare notes and average the lie away.

**`NO_CONTRACT` IS 255 RATHER THAN 0, AND BUCKET 0 IS WHY.** Zero is a real reading: it is what a
hunter standing on top of their contract gets, and the one moment in a hunt where a wrong answer
matters most. During `TUN-CONTRACT-REASSIGN-DELAY` a killer has no announced contract and so no
Compass at all - which is what makes the breath a breath rather than three seconds of a cone
pointing due +Z at nothing.

**AND THE WOBBLE'S PHASE IS MIXED RATHER THAN USED RAW.** Adjacent contract ids taken directly
would drift almost in step, so two hunts would share a drift and it would read as a property of
the world rather than of the hunt - the one thing that would make it *un*learnable, by teaching
the wrong lesson. Measured: consecutive ids land **2.23 rad apart**, and sixty of them cover six
of eight octants.

## Notes

The reciprocal exponent is the whole trick: flat far away, steep close in. The rate at 15 m is
41 percent faster than at 40 m; at 1 m it is triple. That asymmetry is the design requirement
expressed as a curve, and it is where the heart-rate change is.

Deterministic wobble rather than random jitter, because a player must be able to learn that the
cone drifts and compensate. Unlearnable noise is a deleted channel.
