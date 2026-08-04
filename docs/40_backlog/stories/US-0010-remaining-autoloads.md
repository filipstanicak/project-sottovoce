---
id: US-0010
title: Remaining autoloads
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-04
depends_on: [TDD-01-ARCHITECTURE]
---

# US-0010 — Remaining autoloads

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-DATA` |
| **Systems** | — |
| **Estimate** | M |
| **Depends on** | US-0009 |

## Description

Net, GameState, Log, Audio and DebugConsole — skeletons only. Each is a permanent global
dependency, so the inventory is fixed at eight and asserted.

## Acceptance criteria

- [x] Exactly eight autoloads: Tuning, EventBus, Net, GameState, Log, Audio, Strings, DebugConsole.
- [x] Log provides structured logging and a TEL- sink interface.
- [x] GameState exposes match phase, local peer id and lobby roster, read-only outside Net.
- [x] DebugConsole is stripped from release exports.
- [x] `test_autoload_inventory.gd` fails if a ninth is added.

## Test notes

`test_autoload_inventory.gd` asserts exactly the eight named.

## Notes

MatchManager, PlayerRegistry, ScoreManager and Utils were all explicitly rejected as autoloads —
read TDD-01 section 2.1 before proposing any of them.

> **Done 2026-08-04.** All eight autoloads are asserted by name, and the guard
> names the four TDD-01 §2.1 rejected them when one reappears rather than only
> reporting that the count changed.
>
> `DebugConsole` strippability is enforced structurally: the guard asserts its
> script lives under `scripts/debug/`, which every export preset excludes. The
> presets themselves arrive with US-0012; this is the half that can be asserted
> now, and it is the half that would silently regress.
>
> `GameState` gained a single `replace()` entry point rather than settable
> fields, so a half-applied update is not expressible, plus a guard that only
> `scripts/net/` may write. That rule is a convention nothing in GDScript
> enforces.
