---
id: US-0059
title: The prey warning
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
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

The prey's only warning: a directionless flash and sting when their pursuer is close AND
careless.

## Acceptance criteria

- [ ] Fires when the pursuer is within 15 m AND at least Noticed.
- [ ] An ANONYMOUS pursuer fires NO warning at any range.
- [ ] Re-trigger cooldown 2.5 s prevents strobing at the tier boundary.
- [ ] NET-S2C-PREY-WARNING carries a tick and NOTHING ELSE.
- [ ] The EventBus signal takes ZERO parameters.
- [ ] The audio sting is mono and centred, with no 3D emitter.
- [ ] The warn tier threshold equals the stun tier threshold, asserted as an invariant.

## Test notes

`test_warning_tier_gate.gd`, `test_warning_payload_empty.gd`,
`test_prey_sting_nonpositional.gd`, `test_warning_thresholds_match.gd`.

## Notes

Directionlessness is enforced at three layers: no protocol field, no signal parameter, no
positional emitter. A rule enforced once in a widget does not survive refactoring.

The tier gate means a competent hunter never triggers it — the most dangerous approaches are
silent. And since it shares a threshold with stun, the warning is functionally an instruction:
turn around and stun.
