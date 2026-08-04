---
id: US-0082
title: One-click 3-client local playtest
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-12-BUILD, BIBLE-DOD]
---

# US-0082 — One-click 3-client local playtest

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-TOOLING` |
| **Systems** | — |
| **Estimate** | S |
| **Depends on** | US-0081 |

## Description

An editor tool script launching a headless server plus three auto-connecting, auto-readying
clients, tiled so all are visible at once.

## Acceptance criteria

- [ ] Launches one headless server and three clients from the editor.
- [ ] All three auto-connect and auto-ready.
- [ ] Windows are tiled so all three are visible simultaneously.
- [ ] Accepts a fixed seed for reproducible sessions.
- [ ] Cleans up all processes on stop.

## Test notes

`test_local_playtest_launches.gd` verifies one server and three clients connect.

## Notes

Highest ratio of value to effort in the project. It turns "let me test the netcode" from a
five-minute setup into a keypress, which is the difference between testing multiplayer every day
and testing it before milestones.

Simultaneous visibility is necessary for observing prediction artefacts and for checking that the
same player renders PLAIN on one client and HARD on another — the per-observer render state is
the easiest thing to break and the hardest to notice.
