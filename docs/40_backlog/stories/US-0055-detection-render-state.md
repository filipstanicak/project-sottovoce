---
id: US-0055
title: Detection — per-observer render state
version: 0.2.0
status: done
owner: Technical Director
last_updated: 2026-08-25
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

- [x] Anonymous subjects render PLAIN to everyone.
- [x] A Noticed subject renders TINTED to their hunter only.
- [x] An Exposed subject renders HARD to their hunter, and to their prey.
- [x] Everyone else sees PLAIN regardless of the subject's suspicion.
- [x] Computed server-side, per observer, every tick. A client NEVER computes another player's state.
- [x] Early-outs keep the cost to a handful of raycasts, not 30.
      **It costs none at all** — the rule is `tier × relationship` and the Exposed outline is drawn
      *through* geometry, so occlusion must not gate it. `raycasts_last_tick` publishes the number.
- [x] The Exposed outline is the only through-geometry effect in the game.
      `RenderState.draws_through_geometry()` is where that prohibition lives; **nothing draws it
      yet**, because no client renders a remote player's state until the HUD work.

## Test notes

`test_render_state_per_observer.gd`: one player at suspicion 100 must be PLAIN to four observers
and HARD to their hunter and prey.

## Notes

Suspicion is not a broadcast. At six players, four of five observers see nothing — which is what
stops the game collapsing into everyone converging on the visible player.

The same player at the same suspicion is rendered differently to different observers
simultaneously. This is a per-observer snapshot field, not a material swap.
