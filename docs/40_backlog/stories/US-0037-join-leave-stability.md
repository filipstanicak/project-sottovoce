---
id: US-0037
title: Join and leave stability
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-04-NET]
---

# US-0037 — Join and leave stability

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0036 |

## Description

Mid-match join and leave without orphaned entities, stale bookkeeping or desync.

## Acceptance criteria

- [ ] A joining peer receives welcome, tuning sync if needed, match start and a full snapshot.
- [ ] A leaving peer's pawn is freed and its per-client delta bookkeeping released.
- [ ] A timeout is handled identically to a clean disconnect.
- [ ] Five minutes of repeated join and leave churn leaves no orphaned entities.
- [ ] Remaining clients see no stutter when a peer joins.
- [ ] Below the minimum player count the match ends gracefully with results shown.

## Test notes

`test_join_leave_stable.gd` runs the churn scenario and asserts entity counts return to baseline.

## Notes

Contract cycle repair on disconnect arrives at M4. At M2 there is no cycle to repair — this story
covers transport-level lifecycle only.
