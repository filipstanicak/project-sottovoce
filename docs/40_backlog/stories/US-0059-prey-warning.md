---
id: US-0059
title: The prey warning
version: 0.2.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-26
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-07-SUSPICION, BIBLE-AUDIO]
---

# US-0059 — The prey warning

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-DETECTION` |
| **Systems** | `SYS-DETECTION` |
| **Estimate** | S |
| **Depends on** | US-0058 |

## Description

The prey's warning: a marker showing **where** their pursuer is, once that pursuer has been
careless enough to reveal themselves.

**RE-AUTHORED 2026-08-26 (ADR-0013).** This story used to specify a *directionless* warning —
a tick and nothing else, enforced at three layers. The reference marks a revealed pursuer on
the compass with **bearing and distance**, so this does too. The tier gate is unchanged and is
now the load-bearing half: it is the reference's rule as well as ours, and it is what still
leaves a competent hunter invisible.

## Acceptance criteria

- [ ] Fires when the pursuer is within `TUN-COMPASS-WARN-RADIUS` 15 m AND at least Noticed.
- [ ] An ANONYMOUS pursuer fires NO warning at any range, and draws no marker.
- [ ] Re-trigger cooldown `TUN-COMPASS-WARN-COOLDOWN` 2.5 s prevents strobing at the tier
      boundary.
- [ ] `NET-S2C-PREY-WARNING` carries a **world bearing and a distance bucket**, and no third
      field. `TUN-COMPASS-WARN-GIVES-DIRECTION` is `true`.
- [ ] **The payload names nobody.** No persona, no wire slot, no colour — nothing from which a
      client could identify *which* of the people on that bearing is the player. Asserted
      structurally, not by a widget: the Compass lock (ASM-0030) is the only thing in the game
      that earns an identity.
- [ ] The bearing is a **world** angle, rotated into view space by the client each rendered
      frame — the same decision `SYS-COMPASS` made in US-0057, and for the same reason: a
      camera-relative bearing computed server-side lags the mouse by the round trip.
- [ ] The distance is a `Quantise.BUCKET_STEP` bucket, so nothing downstream holds exact
      metres.
- [ ] The audio sting is mono and centred, with no 3D emitter. **Unchanged** — the reference's
      proximity cue is non-positional too, and the direction belongs to the marker.
- [ ] The warn tier threshold equals the stun tier threshold, asserted as an invariant
      (§17.8). "I was warned about them" and "I can stun them" stay the same condition.

## Test notes

`test_warning_tier_gate.gd`, `test_warning_names_nobody.gd`,
`test_prey_sting_nonpositional.gd`, `test_warning_thresholds_match.gd`.

`test/arch/test_prey_warning_signal_arity.gd` is re-authored and already green: it now refuses
an *identifying* parameter rather than any parameter, and asserts the tunable and the shipped
profile agree.

## Notes

**The warning says where, never who.** That is the whole of what survives of the old
three-layer rule, and it matters more than the direction did: a persona on this message would
collapse the crowd from seventy-eight candidates to one, permanently, for free, and there
would be nothing left for a Compass lock to earn.

**The tier gate is the reference's rule, not a divergence from it.** Its threat meter depletes
only when the pursuer goes high-profile *in the prey's line of sight*, and the marker appears
only once it has. A competent hunter still produces nothing at all. Direction is what
carelessness costs.

**One divergence remains and is deliberate:** our suspicion accrues globally, so a hunter who
sprints where the prey cannot see them still reveals themselves. Line-of-sight-gated accrual is
an architectural change (per-observer suspicion rather than one scalar) and is priced
separately.
