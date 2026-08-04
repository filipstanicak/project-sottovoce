---
id: US-0008
title: Tuning autoload and hot reload
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0005, TDD-05-DATA]
---

# US-0008 — Tuning autoload and hot reload

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-DATA` |
| **Systems** | `SYS-TUNING` |
| **Estimate** | M |
| **Depends on** | US-0007 |

## Description

The Tuning autoload, duration-to-tick precomputation, and debug-build hot reload emitting
EVT-TUNING-RELOADED.

Hot reload is the feature the whole data architecture exists for: in a live 3-client playtest one
keypress re-tunes the running game, turning a next-session task into a next-round task.

## Acceptance criteria

- [ ] Tuning exposes one property per sub-resource.
- [ ] `Tuning.ticks(id)` returns precomputed integer ticks for every TUN- duration.
- [ ] `reload()` re-reads, re-validates, recomputes ticks and emits EVT-TUNING-RELOADED.
- [ ] A reload failing `validate()` is rejected and the previous profile retained.
- [ ] `adopt(profile)` applies a server-sent profile.
- [ ] Hot reload is stripped from release builds.
- [ ] `data/tuning/local/` is gitignored.

## Test notes

`test_tuning_reload_rejects_invalid.gd` — a half-applied tuning change is worse than none.
`test_durations_are_ticks.gd` — systems compare integers, never accumulated floats.

## Notes

Anything holding a derived tuning value must handle EVT-TUNING-RELOADED. Forgetting is the
classic hot-reload bug and a DoD checklist item.
