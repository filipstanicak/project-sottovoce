---
id: US-0061
title: StunSystem, lockout and anti-spam
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-10-SCORING]
---

# US-0061 — StunSystem, lockout and anti-spam

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-COMBAT` |
| **Systems** | `SYS-STUN` |
| **Estimate** | M |
| **Depends on** | US-0060 |

## Description

The prey's counterplay: freeze the pursuer, exile them, and force them Exposed.

## Acceptance criteria

- [ ] Valid ONLY against the stunner's own pursuer.
- [ ] The pursuer must be at least Noticed — an ANONYMOUS pursuer is unstunnable at any range.
- [ ] Range 3.0 m, which EXCEEDS kill range, asserted as an invariant.
- [ ] Facing cone 120 degrees — wide, because the player is turning in panic.
- [ ] Freeze 4.0 s, uninterruptible; the target loses camera control.
- [ ] Contract lockout 12 s, reduced by the Second Wind passive.
- [ ] Second Wind reduces LOCKOUT ONLY, never the freeze.
- [ ] Target forced to maximum suspicion for the freeze duration.
- [ ] Stunning a non-pursuer: zero points, 2.0 s self-stagger, +20 suspicion, target UNAFFECTED.
- [ ] A player mid-Lunge is stunnable for the entire wind-up and dash.

## Test notes

`test_stun_range_exceeds_kill.gd`, `test_stun_tier_gate.gd`, `test_stun_invalid.gd`,
`test_secondwind_freeze_unchanged.gd`.

## Notes

Stun range exceeding kill range is the most important geometric relationship in the game: a
hunter who closes to kill range has ALREADY entered stun range. Recklessness is punished by
geometry before it is punished by scoring.

Invalid-stun stagger exceeds the valid-stun animation, so flailing is strictly worse than doing
nothing. The strategy punishes itself with the thing it was trying to prevent.

If hunters find stun frustrating, the fix is to make the Anonymous approach more reliable. Never
weaken stun.
