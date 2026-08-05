---
id: US-0014
title: Centralised transition table
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-05
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

- [x] PawnStateMachine.TRANSITIONS declares every legal edge.
- [x] An illegal request asserts in debug, push_errors and is ignored in release.
- [x] Interrupt priorities: NORMAL 0, COMBAT 10, FATAL 20.
- [x] KillAnim is stun-interruptible before the contact frame and not after.
- [x] Stunned rejects everything below FATAL for its full duration.
- [x] Blended yields to everything — blend protects anonymity, never the body.

## Test notes

`test_pawn_transitions.gd` asserts TRANSITIONS matches the GDD-02 section 3 Mermaid diagram edge
for edge. The diagram is normative.

## Notes

If the code and the diagram disagree, the diagram is right until an ADR says otherwise.

> **Done 2026-08-05.** 115 edges across all fifteen states, matching the normative
> GDD-02 §3 diagram **in both directions**. The table is hand-declared and never
> reads the document, so `test_pawn_transitions.gd` compares two genuinely
> independent representations — a match means they agree, not that one was derived
> from the other. Both failure directions proven against planted edges.
>
> Declared in the shape the diagram is drawn: GDD-02 groups the six locomotion
> states as `Loco` and draws edges against the group, so `LOCO_MARKER` expands the
> same way. Ninety hand-written rows would have been unreadable and no more correct.
>
> The three interrupt rules landed as real states rather than as comments:
> `KillAnimState` is stun-interruptible only before `TUN-KILL-CORPSE-SPAWN-DELAY`,
> `StunnedState` refuses everything below FATAL for its full duration, and
> `BlendedState` yields to everything — blend protects anonymity, never the body.
>
> The remaining twelve states arrive with US-0015 onward.
