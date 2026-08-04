---
id: US-0080
title: Telemetry sink and TEL events
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-07-BALANCE, TUN-BALANCE-MODEL]
---

# US-0080 — Telemetry sink and TEL events

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-TOOLING` |
| **Systems** | `SYS-TELEMETRY` |
| **Estimate** | M |
| **Depends on** | US-0079 |

## Description

Every TEL- event from GDD-07 section 8, with an append-only sink and JSON export.

Without this the balance model is unfalsifiable and every tuning argument is an opinion.

## Acceptance criteria

- [ ] Every TEL- event emits with its documented fields.
- [ ] TEL-MATCH-START records the TUNING PROFILE HASH, so archived logs stay interpretable.
- [ ] TEL-LOBBY-FILL-TIME is recorded — the single most important post-MVP metric.
- [ ] Telemetry carries only a per-match peer index, never a persistent identity.
- [ ] `--record` dumps the ScoreEvent log and telemetry on match end.
- [ ] Archived logs can be RE-FOLDED under candidate tuning values as a pure function.

## Test notes

`test_refold_historical.gd` re-scores an archived log under alternative ScoringTuning.

## Notes

Re-folding screens candidates cheaply before anyone plays a session to test them — but it holds
BEHAVIOUR constant. It answers "what would this match have scored", never "how would players have
played differently". Necessary for screening, insufficient for validation.

No tuning value changes without a TEL- measurement justifying it, recorded in DECISION_LOG.
