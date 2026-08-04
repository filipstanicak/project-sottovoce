---
id: US-0073
title: HUD — tier, portrait, crosshair, abilities, timer
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [BIBLE-UI-UX, TDD-11-UI]
---

# US-0073 — HUD: tier, portrait, crosshair, abilities, timer

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-HUD` |
| **Systems** | `SYS-HUD` |
| **Estimate** | M |
| **Depends on** | US-0072 |

## Description

The remaining widgets, each a pure renderer fed by a view model.

## Acceptance criteria

- [ ] Tier indicator encodes SHAPE and COLOUR and WORD simultaneously.
- [ ] Tier indicator lists ACTIVE SUSPICION SOURCES whenever any contributes.
- [ ] The numeric suspicion value appears NOWHERE in the shipping HUD.
- [ ] Exposed adds a screen-edge vignette — the only full-screen effect in the game.
- [ ] Contract portrait shows UNKNOWN until a lock completes, then the persona permanently.
- [ ] Crosshair ring appears IF AND ONLY IF pressing kill would succeed, from a SERVER flag.
- [ ] A distinct crosshair treatment for a valid stun target.
- [ ] Ability slots show radial cooldown sweeps, LINEAR so remaining time is readable by angle.
- [ ] The passive is NOT shown in the HUD.
- [ ] Timer shows the final-phase bar and a persistent 2x marker.
- [ ] Nothing occupies the centre 60 percent of the screen except the 3 px crosshair.

## Test notes

`test_crosshair_truth.gd` asserts agreement with server kill validity across 500 randomised
poses. `test_tier_monochrome.gd`.

## Notes

The active-source list answers "why am I visible?" before the player asks. A player who cannot
attribute their suspicion cannot learn from it.

A lying crosshair is worse than no crosshair. If prediction and server validation disagree, fix
the agreement or make the ring server-confirmed.
