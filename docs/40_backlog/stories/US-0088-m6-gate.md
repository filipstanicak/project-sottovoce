---
id: US-0088
title: M6 gate — playable MVP
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [BACKLOG-ROADMAP, BIBLE-DOD, BIBLE-RISK-REGISTER]
---

# US-0088 — M6 gate: playable MVP

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-BALANCE` |
| **Systems** | all |
| **Estimate** | S |
| **Depends on** | US-0087 |

## Description

Final verification and the continuation decision.

## Acceptance criteria

- [ ] A full match runs lobby to lobby: countdown, 8 minutes, Final Contract, results, back to lobby.
- [ ] Three external playtests logged.
- [ ] Every TEL- event emitting, archived with the tuning profile hash.
- [ ] p99 frame time within 16.6 ms in the standard scenario, on Windows AND Linux.
- [ ] COVERAGE_MATRIX has no gap rows.
- [ ] Every document exercised by a milestone reviewed for drift; survivors promoted from draft to review.
- [ ] Risk register re-scored; RISK-POPULATION and RISK-BALANCE-UNFALSIFIABLE updated.
- [ ] The six continuation conditions in GDD-08 section 6 assessed against the thresholds, not vibes.
- [ ] Tag `m6-mvp` pushed.

## Test notes

Full suite green: unit, arch, integration, metrics.

## Notes

If conditions 1, 2 and 4 hold and 5 does not, the game is good and the problem is population —
proceed to the mitigation ladder.

If 1 or 4 fails, the loop is not working, and no amount of content or population will fix it.
That outcome is a legitimate result, and detecting it here rather than two years later is the
entire point of building in this order.
