---
id: US-0078
title: Lobby and ready-up
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-09-23
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

## A split is proposed, and it is owner decision 13 (2026-09-23)

**Four things now wait on this story and only one of them wants a lobby**: ADR-0021's
contract portrait, US-0077's results screen (slot labels, because a player has no persona
server-side), `CloneBalance` being told all four personas are in use, and US-0073's
portrait criterion. Each needs a player to **have** a persona, not to have picked one.

The proposal is to deal the persona server-side at the countdown — `MatchContext.rng`,
beside the contract cycle, duplicates permitted — at **M5**, and let
`NET-C2S-LOADOUT`'s `persona:u8` **replace** that deal here at M6. `PawnContext.persona`
already exists and has never had a writer under `scripts/`.

Under that split, what stays in this story is criteria 1, 2, 3, 5, 9 and the unready
cancel from 8. **Criteria 2, 3 and 9 are blocked on US-0071** — a passive must be able to
state its own numeric effect before a screen can print it. **Criteria 7 and the countdown
half of 8 are already built** by US-0079: `TUN-LOBBY-MIN-PLAYERS` with `--min-players`,
and `TUN-LOBBY-COUNTDOWN`.

## Test notes

Verify loadouts never appear in NET-S2C-LOBBY-STATE.

## Notes

A player choosing blind is stuck with a bad pick for eight minutes. The mitigation is not to
unlock loadouts — it is to make the choice informed.

Duplicate personas are GOOD: they add a candidate to each other's crowd.
