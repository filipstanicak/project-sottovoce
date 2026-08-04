---
id: US-0024
title: Feel latency measurement harness
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-02-PLAYER, BIBLE-TEST-PLAN]
---

# US-0024 — Feel latency measurement harness

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-CAMERA` |
| **Systems** | `SYS-PAWN` |
| **Estimate** | S |
| **Depends on** | US-0023 |

## Description

Automated measurement of input-to-visible-animation latency, plus the M1 feel-gate checklist.

## Acceptance criteria

- [ ] `test_feel_latency.gd` measures input to first animation frame change.
- [ ] Measured latency is at or under 80 ms at 60 fps with prediction active.
- [ ] No animation except KillAnim reaches the 1.4 s commitment ceiling.
- [ ] The M1 feel-gate checklist is run and logged: instant slowdown from every state, ten sloppy vaults all resolve, FOV ladder perceptible without nausea.

## Test notes

The automated measurement is a proxy. It can read 78 ms while the game still feels sluggish
because of animation blend curves — so the manual checklist is required alongside it, not
instead of it.

## Notes

If the pawn does not feel good at M1 it will not feel good at M6. Everything after this adds
systems around it; nothing after this improves it.
