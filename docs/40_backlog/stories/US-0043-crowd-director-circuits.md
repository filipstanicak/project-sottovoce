---
id: US-0043
title: CrowdDirector and walking-group circuits
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-08-CROWD, GDD-05-LEVEL]
---

# US-0043 — CrowdDirector and walking-group circuits

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-BEHAVIOUR` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0042 |

## Description

The director owns everything with global correctness requirements: formation slots, the four
circuits, and clone redistribution.

## Acceptance criteria

- [ ] Four circuits with periods 55 to 75 s, from MapData.
- [ ] Groups of four NPCs in loose formation at 1.3 m spacing, with a joinable slot.
- [ ] No two circuits are within 8 m of each other simultaneously.
- [ ] No circuit enters the empty plaza.
- [ ] The director runs on a 2 s timer, never on the per-tick path.
- [ ] Formation slots are assignable to and revocable from a player.

## Test notes

`test_circuit_separation.gd` samples both circuits at 0.5 s intervals over the LCM of their
periods.

## Notes

Two adjacent groups would form a super-pocket and a trivially safe travelling corridor.

The empty plaza stays empty — that is its entire function.
