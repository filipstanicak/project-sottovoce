---
id: US-0008
title: Tuning autoload and hot reload
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-04
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

- [x] Tuning exposes one property per sub-resource.
- [x] `Tuning.ticks(id)` returns precomputed integer ticks for every TUN- duration.
- [x] `reload()` re-reads, re-validates, recomputes ticks and emits EVT-TUNING-RELOADED.
- [x] A reload failing `validate()` is rejected and the previous profile retained.
- [x] `adopt(profile)` applies a server-sent profile.
- [x] Hot reload is stripped from release builds.
- [x] `data/tuning/local/` is gitignored.

## Test notes

`test_tuning_reload_rejects_invalid.gd` — a half-applied tuning change is worse than none.
`test_durations_are_ticks.gd` — systems compare integers, never accumulated floats.

## Notes

Anything holding a derived tuning value must handle EVT-TUNING-RELOADED. Forgetting is the
classic hot-reload bug and a DoD checklist item.

> **Done 2026-08-04.** 86 duration tunables convert to integer server ticks at load,
> including per-ability durations, which resolve through `profile.abilities` rather
> than a section and would have been easy to omit silently.
>
> `TuningIndex` was added to make `ticks(id)` possible at all: GDScript docstrings
> are not readable at runtime, so the `TUN-` ID a field carries in its comment
> cannot be recovered from the loaded resource. The index is the runtime half of
> that link, generated from the same parse of TUNABLES.md as the classes.
>
> Building it surfaced two defects in already-merged work — see the commit.
