---
id: US-0105
title: The HUD shows what the reference shows
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-09-25
depends_on: [ADR-0024, GDD-06-UI-AUDIO, US-0073]
---

# US-0105 — The HUD shows what the reference shows

| | |
|---|---|
| **Milestone** | M5 (the parts that need player names: M6) |
| **Epic** | `EPIC-HUD` |
| **Systems** | `SYS-COMPASS`, `SYS-SCORE`, `SYS-NET-*` |
| **Estimate** | L — several PRs, in the dependency order below |
| **Depends on** | ADR-0024 (accepted); US-0078 for names; owner decisions 14 and 15 for two lines |

## Description

**Owner decision, 2026-09-25: *"Bleiben dem Original so treu wie möglich."*** ADR-0024 lifts the
global kill feed, player names in the HUD and a permanent own placement from never-do #12, and
lists what the reference's HUD shows that ours does not. This story builds it.

## Acceptance criteria

- [ ] **The Compass says up or down** when the contract is above or below the hunter, and
      **glows while the contract is in sight**. Buildable now.
- [ ] **One-line notices**: a new pursuer on you, and you take the lead. Strings in the table.
- [ ] **Your own placement** is always on screen, with **one icon per pursuer** beneath it
      (always one until owner decision 15).
- [ ] **The contract's placement** beside the portrait. Needs every player's score on the wire,
      as a new message with a `PROTOCOL_VERSION` bump.
- [ ] **A global kill feed**, *"A killed B"* and *"A joined"*, for every player. Blocked on
      player names (US-0078).
- [ ] **The contract's player name** beside the portrait and on the assignment card. Blocked on
      names.
- [ ] **A death card**: the killer's name, the points your death paid them, and the bonuses they
      earned for it. `test_no_global_score_feed.gd` is amended for that one kill, citing ADR-0024.
- [ ] *"Your pursuer killed a civilian"*, once owner decision 14 makes a wrong kill possible.

## Open (ADR-0024)

The death camera (framed on the killer, as the reference's is?) and the death card's
one-line hint, *how you were caught*.
