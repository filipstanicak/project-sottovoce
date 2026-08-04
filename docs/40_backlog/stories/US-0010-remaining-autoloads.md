---
id: US-0010
title: Remaining autoloads
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
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

- [ ] Exactly eight autoloads: Tuning, EventBus, Net, GameState, Log, Audio, Strings, DebugConsole.
- [ ] Log provides structured logging and a TEL- sink interface.
- [ ] GameState exposes match phase, local peer id and lobby roster, read-only outside Net.
- [ ] DebugConsole is stripped from release exports.
- [ ] `test_autoload_inventory.gd` fails if a ninth is added.

## Test notes

`test_autoload_inventory.gd` asserts exactly the eight named.

## Notes

MatchManager, PlayerRegistry, ScoreManager and Utils were all explicitly rejected as autoloads —
read TDD-01 section 2.1 before proposing any of them.
