---
id: US-0030
title: SnapshotBuilder — culling and quantisation
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0007, TDD-04-NET]
---

# US-0030 — SnapshotBuilder: culling and quantisation

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-SNAPSHOT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0029 |

## Description

Per-client snapshot construction with distance culling and quantisation. Per-client rather than
broadcast because render_state and compass data are per-observer.

## Acceptance criteria

- [ ] One snapshot built per client per tick.
- [ ] Entities beyond the 70 m cull radius are omitted for that client.
- [ ] The cull radius is greater than or equal to compass range, asserted as an invariant.
- [ ] Culling is POSITIONAL, not visual — no LOS test.
- [ ] render_state computed per observer pair.
- [ ] last_acked_seq included per client.

## Test notes

`test_npc_cull_radius.gd` asserts the invariant.

## Notes

70 m exceeds the 60 m compass range so a culled entity can never affect anything the client could
perceive. Visual relevance culling was considered and rejected: pop-in when LOS is established is
a worse artefact in a game about spotting people than the wallhack it would prevent.
