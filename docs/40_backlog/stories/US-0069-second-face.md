---
id: US-0069
title: Ability — Second Face
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY]
---

# US-0069 — Ability: Second Face

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY` |
| **Estimate** | M |
| **Depends on** | US-0068 |

## Description

Disguise: adopt the appearance of the nearest visible clone for fifteen seconds.

Exists to reward reading the crowd.

## Acceptance criteria

- [ ] 60 s cooldown, 0.8 s cast, 15 s duration, +10 suspicion.
- [ ] Persona comes from the NEAREST VISIBLE CLONE — never a player choice.
- [ ] Falls back to a random other persona when no clone is visible.
- [ ] Breaks on sprint and on damage.
- [ ] Breaks AFTER kill resolution, so the Masked bonus still applies.
- [ ] The un-morph is as visible as the morph, at 20 m.
- [ ] NEVER affects the Compass — a hunter's bearing to a disguised contract is unchanged.

## Test notes

`test_secondface_nearest_clone.gd`, `test_secondface_compass_unaffected.gd`,
`test_secondface_breaks.gd`.

## Notes

Not choosing is the design. `nearest_clone` makes this a POSITIONAL ability wearing a
transformation ability's clothes: cast beside a lone Lucerna and you become the fifth Lucerna in
an area with four; cast inside a Pesatore cluster and you vanish. It converts crowd literacy into
mechanical advantage.

Second Face fools PEOPLE, never SYSTEMS — and every fooled person had a chance to see the morph.

Casting inside a Cinderfall cloud is permitted and monitored via TEL-SECONDFACE-IN-CLOUD. The
random fallback when no clone is visible is the designed mitigation. Clever combinations should
exist until proven dominant.
