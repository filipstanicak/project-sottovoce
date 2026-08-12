---
id: US-0065
title: All twelve scoring bonuses
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-07-BALANCE, TDD-10-SCORING, TUN-BALANCE-MODEL]
---

# US-0065 — All twelve scoring bonuses

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-SCORING` |
| **Systems** | `SYS-SCORE` |
| **Estimate** | **L** |
| **Depends on** | US-0064 |

## Description

Every bonus condition, evaluated at kill INITIATION, plus the two windows that need real buffers.

## Acceptance criteria

- [ ] All twelve implemented: Contract, Silent, Patient, Masked, Focus, From Above, Blended, Poisoned, Long Hunt, Vendetta, Variety, Reckless. Plus Stun.
- [ ] All evaluated at initiation, not at resolution.
- [ ] Patient uses a 300-tick speed-history ring — one tick above `TUN-SCORE-PATIENT-SPEED` anywhere in the window denies it.
- [ ] Focus tolerates a 0.4 s LOS lapse without resetting the streak.
- [ ] Long Hunt measures from contract assignment OR first lock, whichever is later.
- [ ] Variety counts types earned for the first time this life, excluding itself, Contract and Reckless.
- [ ] Poisoned is implemented and tested but DORMANT — no MVP ability triggers it.
- [ ] Death awards and deducts ZERO points.
- [ ] Stun scores exactly one base kill, asserted as an invariant.

## Test notes

`test_patient_window.gd`, `test_focus_grace.gd`, `test_death_zero_points.gd`.

## Notes

Focus without the grace window is UNEARNABLE in a crowd — which is exactly where it should be
earned.

Known finding carried from BALANCE_MODEL section 4: at ~1.0 kills per life, Variety behaves as a
flat +50 per bonus type rather than a variety reward. It is ratio-neutral, so this is a
truth-in-naming problem. The fix — reset on contract instead of on death — is one line and
changes no tuning value. Gated on TEL-KILLS-PER-LIFE; do not apply it blind.
