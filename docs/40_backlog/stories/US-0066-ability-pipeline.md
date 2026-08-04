---
id: US-0066
title: Ability pipeline and validation
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY]
---

# US-0066 — Ability pipeline and validation

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY` |
| **Estimate** | M |
| **Depends on** | US-0064 |

## Description

Request, server validation, effect application, replication and presentation — plus the
AbilityEffect base class.

## Acceptance criteria

- [ ] Five validations: equipped, cooldown, global cooldown, legal pawn state, aim range.
- [ ] Aim is CLAMPED server-side, not rejected, when out of range.
- [ ] Cooldowns are integer tick deadlines on the server; the client mirrors optimistically.
- [ ] Cooldowns start at ACTIVATION, not at effect end.
- [ ] Cooldowns reset on death.
- [ ] NET-S2C-ABILITY-STARTED broadcasts to ALL clients within tell radius, reliably.
- [ ] The TELL is predicted locally and cancelled on denial; the EFFECT is not predicted.
- [ ] Other players' cooldowns are never replicated.

## Test notes

`test_ability_validation.gd`, `test_ability_aim_clamped.gd`, `test_cooldown_authority.gd`,
`test_ability_started_broadcast.gd`.

## Notes

Clamping rather than rejecting means a rounding difference between predicted and server aim
produces the outcome the player intended rather than a denial.

Tell latency is a NETCODE issue, not a balance one. If Lunge proves unstunnable in practice,
check NET-S2C-ABILITY-STARTED delivery time before touching tunables.
