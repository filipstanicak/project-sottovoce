---
id: US-0078
title: Lobby and ready-up
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-06-UI-AUDIO, TDD-11-UI]
---

# US-0078 — Lobby and ready-up

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-MATCHFLOW` |
| **Systems** | `SYS-LOBBY` |
| **Estimate** | M |
| **Depends on** | US-0077 |

## Description

Direct-IP host and join, persona and loadout selection, ready-up and countdown.

The lobby is an INFORMATION SURFACE, not a menu, because loadouts lock for the whole match.

## Acceptance criteria

- [ ] Host and join by direct IP with a port field; failures show a reason.
- [ ] Every ability shows cooldown, suspicion cost and ITS TELL, in one sentence each.
- [ ] Every passive shows its exact numeric effect, not a description.
- [ ] Persona selections are VISIBLE to all players.
- [ ] Loadout selections are HIDDEN from all other players.
- [ ] Duplicate personas are permitted.
- [ ] Minimum four players to start.
- [ ] 5 s countdown, cancelled if anyone unreadies.
- [ ] A recommended default loadout is pre-selected for first-time players.

## Test notes

Verify loadouts never appear in NET-S2C-LOBBY-STATE.

## Notes

A player choosing blind is stuck with a bad pick for eight minutes. The mitigation is not to
unlock loadouts — it is to make the choice informed.

Duplicate personas are GOOD: they add a candidate to each other's crowd.
