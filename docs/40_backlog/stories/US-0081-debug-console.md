---
id: US-0081
title: Debug console and visualisers
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-12-BUILD, ADR-0002, ADR-0010]
---

# US-0081 — Debug console and visualisers

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-TOOLING` |
| **Systems** | `SYS-DEBUG` |
| **Estimate** | M |
| **Depends on** | US-0080 |

## Description

Live tuning overrides, state visualisers and the two commands that earn the console's existence.

## Acceptance criteria

- [ ] `tune` sets a live override; the SERVER BROADCASTS so a playtest never has mixed values.
- [ ] `tune reload` and `tune diff`.
- [ ] `show suspicion`, `show cycle`, `show crowd`, `show budget`.
- [ ] `show lagcomp` draws the REWOUND WORLD at the last kill or stun validation.
- [ ] `noprediction` disables client prediction.
- [ ] `netsim` injects synthetic latency and packet loss.
- [ ] `set phase final` jumps to the Final Contract.
- [ ] `dump scorelog` writes the event log as JSON.
- [ ] Entirely stripped from release exports.
- [ ] Overhead at most 0.05 ms per frame in debug builds.

## Test notes

`test_debug_stripped.gd` asserts no debug symbol survives a release export.

## Notes

`noprediction` is the only way to tell a feel bug from a prediction bug. `show lagcomp` is the
only practical way to diagnose a disputed kill. Both diagnose classes of bug that are otherwise
nearly undiagnosable from a player report — that is why the console is worth its cost.

Console overhead must not distort the profiling it exists to support.
