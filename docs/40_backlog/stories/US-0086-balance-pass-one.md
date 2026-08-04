---
id: US-0086
title: Balance pass 1 — measurement driven
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-07-BALANCE, TUN-BALANCE-MODEL]
---

# US-0086 — Balance pass 1: measurement driven

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-BALANCE` |
| **Systems** | `SYS-SCORE`, `SYS-SUSPICION` |
| **Estimate** | M |
| **Depends on** | US-0085 |

## Description

Check the balance model's eight predictions against real telemetry, and pull levers only where
measurement justifies it.

## Acceptance criteria

- [ ] Player-matches classified into archetypes by MEASURED mean speed terciles, never self-report.
- [ ] All eight predictions checked; each confirmed, refuted, or explicitly left open with a reason.
- [ ] Candidate changes screened by RE-FOLDING archived logs before anyone plays a session.
- [ ] Levers pulled in the documented order, ONE AT A TIME, re-measuring between each.
- [ ] Every changed value has a TEL- measurement justifying it, recorded in DECISION_LOG.
- [ ] TUNABLES.md and BALANCE_MODEL.md updated in the same commit as any value change.

## Test notes

`test_tuning_docs_sync.gd` must pass after every change.

## Notes

The model predicts patience beats aggression ~2.5x, above the ~60 percent design target. The
first three levers close the gap WITHOUT touching the thesis bonuses; Blended is last and must
never invert the bonus hierarchy.

Sensitivity analysis says the balance risk sits in COUNTERPLAY, not scoring: the only two inputs
that can flip the conclusion are the aggressor stun-failure rate and how fast an Exposed player
is found. If the game turns out unbalanced, the scoring table is probably not the place to look
first.
