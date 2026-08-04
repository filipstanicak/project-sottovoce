---
id: US-0001
title: Project scaffold and engine pin
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-04
depends_on: [ADR-0001, TDD-02-STRUCTURE]
---

# US-0001 — Project scaffold and engine pin

| | |
|---|---|
| **Milestone** | M0 |
| **Epic** | `EPIC-SCAFFOLD` |
| **Systems** | — |
| **Estimate** | S |
| **Depends on** | — |

## Description

Create `project.godot` configured for Forward+, pin the engine version, and lay down the complete
folder tree from TDD-02 §1 with `.gdkeep` in empty folders.

The tree lands complete and empty rather than growing organically, because the layer rule is
enforced by folder membership and a missing folder invites a file in the wrong place.

## Acceptance criteria

- [x] `project.godot` sets `rendering/renderer/rendering_method = "forward_plus"`.
- [x] `project.godot` sets `physics/common/physics_ticks_per_second = 60`.
- [x] `.godot-version` contains the pinned version and matches what CI installs.
- [x] Every folder in TDD-02 §1 exists.
- [x] `godot --headless --editor --quit-after 200` completes with no errors.
- [x] No `.csproj` or `.sln` exists (ADR-0001 compliance).

## Test notes

`test_folder_structure.gd` asserts every declared folder exists and no script sits outside one.

## Notes

Engine upgrades are a deliberate, tested operation with an ADR — never background drift.
