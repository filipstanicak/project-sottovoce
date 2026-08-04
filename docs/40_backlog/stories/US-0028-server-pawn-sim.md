---
id: US-0028
title: Server-side pawn simulation
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0002, TDD-04-NET, TDD-06-PAWN]
---

# US-0028 — Server-side pawn simulation

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-TRANSPORT` |
| **Systems** | `SYS-PAWN`, `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0027 |

## Description

The server instantiates a PawnServer per peer and drives it with received InputCommands, using
the identical state machine the client predicts with.

## Acceptance criteria

- [ ] One PawnServer per connected peer, spawned on join, freed on leave.
- [ ] Input queued per pawn and applied in sequence order, two substeps per net tick.
- [ ] The server runs the SAME PawnStateMachine and PawnState classes as the client.
- [ ] Missing input for a tick repeats the last command rather than stalling.
- [ ] The server is authoritative over position, velocity and state — the client never writes them.
- [ ] Traversal probes run server-side against the same WORLD layer.

## Test notes

`test_substep_matches_server.gd` asserts a client predicting two 1/60 substeps lands within the
reconcile threshold of a server applying the same two commands.

## Notes

Repeating the last command on a missing input rather than stalling is deliberate: a stalled pawn
produces a position the client cannot have predicted, guaranteeing a reconciliation every time a
packet drops.
