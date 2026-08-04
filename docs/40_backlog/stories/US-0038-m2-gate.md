---
id: US-0038
title: M2 gate — netcode verification
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [BACKLOG-ROADMAP, BIBLE-TEST-PLAN]
---

# US-0038 — M2 gate: netcode verification

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | `SYS-NET-PREDICTION`, `SYS-NET-REPLICATION` |
| **Estimate** | S |
| **Depends on** | US-0037 |

## Description

Run and log the full M2 exit verification. This story exists so the gate is somebody's explicit
deliverable rather than an assumption.

## Acceptance criteria

- [ ] Three clients plus a headless server, replicated movement, verified by hand.
- [ ] `test_prediction_reconciliation.gd` passes at all four latency profiles.
- [ ] `test_frame_rate_independence.gd` passes at 30, 60 and 144 fps.
- [ ] `test_join_leave_stable.gd` passes over five minutes of churn.
- [ ] Downstream bandwidth within budget, measured.
- [ ] Upstream miss recorded with its failing test and the coalescing decision logged.
- [ ] Feel check: the local pawn still feels local at 180 ms RTT.
- [ ] Risk register re-scored; RISK-NETCODE and RISK-BANDWIDTH updated.
- [ ] Tag `m2-net` pushed.

## Test notes

The feel check is manual and cannot be automated. A pawn can pass every latency test and still
feel wrong.

## Notes

The upstream budget miss is expected here, not a surprise. Decide on coalescing with the latency
measurement in hand rather than deferring it silently.
