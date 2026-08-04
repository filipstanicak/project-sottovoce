---
id: US-0014
title: Centralised transition table
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0008, TDD-06-PAWN, GDD-02-PLAYER]
---

# US-0014 — Centralised transition table

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-PAWN-STATES` |
| **Systems** | `SYS-PAWN` |
| **Estimate** | S |
| **Depends on** | US-0013 |

## Description

The declared from-to edge table plus validation and interrupt priorities.

The state-object pattern's real weakness is that the transition graph exists only in the reader's
head. Centralising it fixes that: step() REQUESTS a transition, the machine VALIDATES it.

## Acceptance criteria

- [ ] PawnStateMachine.TRANSITIONS declares every legal edge.
- [ ] An illegal request asserts in debug, push_errors and is ignored in release.
- [ ] Interrupt priorities: NORMAL 0, COMBAT 10, FATAL 20.
- [ ] KillAnim is stun-interruptible before the contact frame and not after.
- [ ] Stunned rejects everything below FATAL for its full duration.
- [ ] Blended yields to everything — blend protects anonymity, never the body.

## Test notes

`test_pawn_transitions.gd` asserts TRANSITIONS matches the GDD-02 section 3 Mermaid diagram edge
for edge. The diagram is normative.

## Notes

If the code and the diagram disagree, the diagram is right until an ADR says otherwise.
