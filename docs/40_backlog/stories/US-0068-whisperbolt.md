---
id: US-0068
title: Ability — Whisperbolt
version: 0.2.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY, ADR-0010]
---

# US-0068 — Ability: Whisperbolt

| | |
|---|---|
| **Milestone** | **post-MVP — deferred 2026-08-27** (was M5) |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY` |
| **Estimate** | M |
| **Depends on** | US-0067 |

> **DEFERRED TO POST-MVP ON 2026-08-27. THIS IS THE CUT THAT PAYS FOR THE ESCAPE VERB.**
> `ADR-0014` added escape to `SCOPE_FENCE.md` IN #5 and the fence's rule is that new scope
> arrives naming what is cut for it; this story is that payment. **Nothing here is deleted** —
> the specification in GDD-04 §3.2, every `TUN-WHISPERBOLT-*` value, invariant 11, the four
> `SFX-` IDs, the two `ANIM-` IDs and `ABIL-WHISPERBOLT` itself all stay exactly as written, so
> restoring the ability once `SYS-ABILITY` exists is a `.tres` and a behaviour.
>
> **It was chosen on engineering cost rather than design merit.** It is the only one of the
> four that needs a replicated moving entity, client interpolation for it, and hit validation
> at an **impact 0.55 s after the press** — and `RewindClamp` clamps to 100–200 ms of RTT at
> the moment of the *press*, with no rule anywhere for what a half-second-later impact resolves
> against. Criterion 5 below (*"LOS at release AND at impact, validated against the
> lag-compensated world"*) is that open question written as an acceptance criterion, which is
> the clearest evidence that this is netcode work wearing an ability's clothes.
>
> **What the deferral costs**: MVP loadout variety halves, and **nothing in the MVP can reach a
> player on a roof**, which is the job the Description below gives this ability. The roof stays
> priced by `TUN-SUSPICION-GAIN-ROOF` and by scoring nothing while you sit there. **Revisit if
> `TEL-TIME-BY-STRATUM` shows roof time rising.** `SCOPE_FENCE.md` OUT #18 is the record.

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
