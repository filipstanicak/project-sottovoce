---
id: US-0055
title: Detection — per-observer render state
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-07-SUSPICION]
---

# US-0055 — Detection: per-observer render state

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-DETECTION` |
| **Systems** | `SYS-DETECTION` |
| **Estimate** | M |
| **Depends on** | US-0054 |

## Description

The anonymity rule: for every ordered observer-subject pair, compute what that observer sees.

## Acceptance criteria

- [ ] Anonymous subjects render PLAIN to everyone.
- [ ] A Noticed subject renders TINTED to their hunter only.
- [ ] An Exposed subject renders HARD to their hunter, and to their prey.
- [ ] Everyone else sees PLAIN regardless of the subject's suspicion.
- [ ] Computed server-side, per observer, every tick. A client NEVER computes another player's state.
- [ ] Early-outs keep the cost to a handful of raycasts, not 30.
- [ ] The Exposed outline is the only through-geometry effect in the game.

## Test notes

`test_render_state_per_observer.gd`: one player at suspicion 100 must be PLAIN to four observers
and HARD to their hunter and prey.

## Notes

Suspicion is not a broadcast. At six players, four of five observers see nothing — which is what
stops the game collapsing into everyone converging on the visible player.

The same player at the same suspicion is rendered differently to different observers
simultaneously. This is a per-observer snapshot field, not a material swap.
