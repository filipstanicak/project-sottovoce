---
id: US-0017
title: Traversal probes
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-06-PAWN, GDD-02-PLAYER]
---

# US-0017 — Traversal probes

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-TRAVERSAL` |
| **Systems** | `SYS-TRAVERSAL` |
| **Estimate** | M |
| **Depends on** | US-0016 |

## Description

Three forward raycasts at chest, waist and foot plus one downward gap probe, refreshed once per
physics frame into a ProbeResult.

## Acceptance criteria

- [ ] Probe origins at 1.35, 0.85 and 0.25 m; length 0.9 m, all from tunables.
- [ ] A downward probe from 0.6 m ahead, 5 m deep, distinguishes gap from drop.
- [ ] Probes mask the WORLD layer ONLY — not PAWN, not NPC.
- [ ] ProbeResult exposes waist_hit, chest_hit, foot_clear, ground_ahead, gap_distance, obstacle_top, clear_beyond, surface_is_climbable.
- [ ] Refreshed once per physics frame, before step().

## Test notes

`test_probes_mask_world_only.gd` is the important one.

## Notes

Masking WORLD only is a determinism requirement, not an optimisation. Static geometry is
identical on every peer; NPC and player positions are interpolated on clients and authoritative
on the server, so a probe that could hit a moving body would resolve differently on the two
machines and produce a different traversal.
