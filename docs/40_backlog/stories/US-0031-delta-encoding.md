---
id: US-0031
title: Delta encoding and rate LOD
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0007, TDD-04-NET, BIBLE-PERF-BUDGET]
---

# US-0031 — Delta encoding and rate LOD

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-SNAPSHOT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0030 |

## Description

Send only entities whose quantised state changed since the client's last acknowledged snapshot,
and send distant entities at a reduced rate.

## Acceptance criteria

- [ ] Per-client acknowledged-snapshot bookkeeping.
- [ ] An entity whose quantised state is unchanged is omitted.
- [ ] Entities beyond 45 m are sent at 10 Hz rather than 30 Hz.
- [ ] A lost ack degrades to a full send rather than corrupting state.
- [ ] Measured downstream is within 96 kbit/s at 6 players and 90 NPCs.

## Test notes

`test_crowd_bandwidth.gd` runs a 60 s synthetic worst case.
`test_upstream_bandwidth.gd` is EXPECTED TO FAIL until input coalescing lands.

## Notes

Upstream currently measures ~18 kbit/s against a 16 kbit/s budget. The cause is packet overhead,
not payload — 28 bytes of header carrying 9 bytes of input at 60 Hz. The fix is coalescing two
commands per packet, at up to 16 ms added latency against an 80 ms feel budget. Measure before
committing.
