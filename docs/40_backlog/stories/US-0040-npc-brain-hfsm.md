---
id: US-0040
title: NpcBrain five-state HFSM
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0003, TDD-08-CROWD, GDD-03-SOCIAL-STEALTH]
---

# US-0040 — NpcBrain five-state HFSM

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-CORE` |
| **Systems** | `SYS-NPC-AI` |
| **Estimate** | M |
| **Depends on** | US-0039 |

## Description

Stroll, Idle, WalkingGroup, Startle and Gawk as a flat hierarchical state machine, with Startle
as a global interrupt.

A behaviour tree was rejected: per-tick tree traversal across 90 agents in GDScript is thousands
of virtual calls for five behaviours.

## Acceptance criteria

- [ ] Exactly five states; a sixth requires an ADR.
- [ ] Startle is enterable from all four other states and always wins.
- [ ] Per-agent per-tick cost is one integer compare, one timer decrement and one small call.
- [ ] `step()` allocates NOTHING after warm-up.
- [ ] Every state-event pair is either handled or explicitly listed as ignored.
- [ ] NPC stroll speed equals player blend-walk speed exactly, asserted as an invariant.

## Test notes

`test_npc_no_alloc.gd`, `test_npc_transition_table.gd`, `test_startle_global_interrupt.gd`,
`test_npc_speed_matches_blendwalk.gd`.

## Notes

Startle being uninterruptible means a gawking NPC abandons a corpse when startled, destroying a
standing information object. Accepted: it reads correctly, and the corpse itself persists
regardless.

The silent no-op transition is the classic FSM bug; the completeness test is the standard defence.
