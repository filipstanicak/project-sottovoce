---
id: US-0071
title: Passives and loadout locking
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY]
---

# US-0071 — Passives and loadout locking

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-LOADOUT` |
| **Estimate** | S |
| **Depends on** | US-0070 |

## Description

Stillness, Cold Read and Second Wind, implemented as queries at the point of use rather than as
state — plus match-long loadout locking.

## Acceptance criteria

- [ ] Stillness multiplies suspicion decay while stationary, read by the integrator.
- [ ] Cold Read multiplies lock fill rate, read by detection.
- [ ] Second Wind reduces stun LOCKOUT only, NEVER the freeze.
- [ ] No passive changes what another player perceives.
- [ ] Loadouts lock at countdown and are immutable for the whole match, INCLUDING across respawns.
- [ ] The lobby selection buffer is cleared after locking, so nothing remains to read.

## Test notes

`test_secondwind_freeze_unchanged.gd` — being stunned must always be catastrophic in the moment.
`test_loadout_lock.gd` asserts a death does not reopen selection.

## Notes

Passives have no tell, which is permissible ONLY because none affects another player's
perception. A passive that changed your visibility would need a tell and would therefore not be a
passive.

Locking across respawn is the load-bearing part. If loadouts could change on death, kit knowledge
would decay to nothing every ~90 seconds and the deduction it enables — the most social skill in
the game — would disappear. It would also make death a counter-pick opportunity.
