---
id: US-0039
title: NPC pool and seeded roster
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0007, TDD-08-CROWD]
---

# US-0039 — NPC pool and seeded roster

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-CORE` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0038 |

## Description

Pre-allocate 90 NPCs during countdown and assign personas deterministically from the match seed.

## Acceptance criteria

- [ ] All 90 allocated before the first PLAYING tick, sized to the maximum regardless of player count.
- [ ] NO NPC is instantiated or freed between match start and end.
- [ ] Inactive NPCs are hidden and skipped, never freed.
- [ ] Persona assignment derives from match seed plus index, identically on every peer.
- [ ] Clone quota respected: 8 to 12 per persona, remainder filler archetypes.
- [ ] Three peers derive identical rosters from one seed.

## Test notes

`test_clone_roster_parity.gd` hashes the derived roster on three peers and asserts equality.
`test_no_midmatch_instantiate.gd`.

## Notes

Instantiating a CharacterBody3D with a NavigationAgent3D mid-match is a frame spike, and a frame
spike in a game decided at 2.5 m is a lost kill.

Appearance is derived rather than replicated so every peer agrees without spending bandwidth —
if two players saw different clone distributions, "I saw a Lucerna by the furnace" becomes a lie.
