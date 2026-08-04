---
id: US-0074
title: HUD — score feed
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-06-UI-AUDIO, TDD-11-UI]
---

# US-0074 — HUD: score feed

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-HUD` |
| **Systems** | `SYS-SCOREFEED` |
| **Estimate** | S |
| **Depends on** | US-0073 |

## Description

The game's teacher: named bonuses arriving as a readable sequence at the instant they are earned.

## Acceptance criteria

- [ ] Shows bonus NAMES, not just values.
- [ ] Bonuses from one kill stagger by 0.12 s.
- [ ] At most four simultaneous lines; each persists 4.0 s, raisable to 8 s.
- [ ] Penalties use a visually DISTINCT treatment.
- [ ] Tabular numerals so values do not reflow as digits change.
- [ ] Right side above centre — readable WITHOUT being looked at.
- [ ] Subscribes to EVT-SCORE-EVENT-APPENDED; never polls a total.
- [ ] Shows only the local player's events. NO global kill feed.

## Test notes

`test_scorefeed_stagger.gd`, `test_scorefeed_cap.gd`.

## Notes

Four bonuses arriving simultaneously is ONE event. Arriving 0.12 s apart they are FOUR, each
individually readable — and paired with the audio pitching up per position, a four-bonus kill
ASCENDS. Cheapest high-value feedback in the project.

Tabular numerals matter more than they sound: differing widths produce horizontal jitter in
peripheral vision, which reads as motion and pulls the eye.
