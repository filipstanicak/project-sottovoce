---
id: US-0053
title: Blend actions — pocket and walking group
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-07-SUSPICION]
---

# US-0053 — Blend actions: pocket and walking group

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-SUSPICION` |
| **Systems** | `SYS-BLEND` |
| **Estimate** | M |
| **Depends on** | US-0052 |

## Description

The two crowd-dependent blend actions: standing in a pocket of at least four NPCs, and occupying
a walking-group formation slot.

## Acceptance criteria

- [ ] Pocket requires at least 4 NPCs within 3.5 m, RE-VALIDATED EVERY TICK.
- [ ] Group requires an assigned slot and staying within 0.8 m of it.
- [ ] Entry takes 0.35 s; exit 0.30 s.
- [ ] Suspicion crushes to zero over 1.2 s.
- [ ] Exceeding stroll speed, taking damage, or being stunned breaks the blend.
- [ ] A pocket dropping below four NPCs breaks the blend THAT TICK.
- [ ] Blend grace of 1.0 s after exit arms the Blended bonus.
- [ ] The player adopts the persona-appropriate clone idle — a parity-set clip.

## Test notes

`test_blend_revalidated.gd` is the critical one. `test_blend_grace.gd` asserts 0.9 s after exit
qualifies and 1.1 s does not. `test_blend_not_cover.gd` asserts a blended pawn is killable.

## Notes

A blend is not a state you enter and keep — it is a condition re-validated every tick. A blend
that silently keeps working after its conditions lapse is the "I thought I was hidden" bug class.

Blend protects anonymity, never the body.
