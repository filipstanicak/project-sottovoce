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

**Taken 2026-09-24 and built as [US-0100](US-0100-persona-deal.md)**: the persona is dealt at
the countdown, and `NET-C2S-LOADOUT` below replaces that deal rather than enabling it. All nine
criteria stayed here. The analysis that led to it follows.

**Four things now wait on this story and only one of them wants a lobby**: ADR-0021's
contract portrait, US-0077's results screen (slot labels, because a player has no persona
server-side), `CloneBalance` being told all four personas are in use, and US-0073's
portrait criterion. Each needs a player to **have** a persona, not to have picked one.

The proposal is to deal the persona server-side at the countdown — `MatchContext.rng`,
beside the contract cycle, duplicates permitted — at **M5**, and let
`NET-C2S-LOADOUT`'s `persona:u8` **replace** that deal here at M6. `PawnContext.persona`
already exists and has never had a writer under `scripts/`.

**The split moves no criterion out of this story.** What it extracts is the
**precondition** the story implies without stating — that a player has a persona at all.
All nine criteria below stay at M6. Corrected 2026-09-23 after review; the first version
of this note read as though criteria moved.

**The wire cost is two things.** ADR-0021's byte on `NET-S2C-CONTRACT-ASSIGNED` feeds the
**portrait** alone: it reaches one hunter and names one contract. `MatchEndReport` carries
`anonymous_ticks`, `kits` and `events` and **no persona**, so US-0077's results table
needs its own transport — a persona per result row, or a **stable persona roster**. The
roster is also the only thing that can answer criterion 4, *persona selections are VISIBLE
to all players*: a per-contract message cannot make a selection public.

**What blocks what, with the real reason for each:**

| Criterion | Blocked by |
|---|---|
| 1 — host and join by direct IP | the lobby screen itself |
| 2 — every ability shows cooldown, suspicion cost and its tell | **not US-0071**: `AbilityData` and TUNABLES hold every figure today. The screen, and one string per ability |
| 3 — every passive shows its exact numeric effect | **US-0071** — a passive has no reader, so it cannot state a number |
| 4 — persona selections are VISIBLE to all players | a **roster broadcast**. The M5 deal does not satisfy this, and neither does the contract byte |
| 5 — loadout selections are HIDDEN from others | the lobby screen and `NET-S2C-LOBBY-STATE`'s exclusion rule |
| 6 — duplicate personas are permitted | a rule of the **selection**; the deal allowing duplicates does not discharge it |
| 7 — minimum four players to start | **already built** — `TUN-LOBBY-MIN-PLAYERS`, `--min-players` (US-0079) |
| 8 — 5 s countdown, cancelled if anyone unreadies | the countdown is **built** (`TUN-LOBBY-COUNTDOWN`); the **unready cancel** is not |
| 9 — a recommended default loadout is pre-selected | **US-0071**, for a different reason than 3: there is no loadout to recommend until `NET-C2S-LOADOUT` defines one |

## Test notes

Verify loadouts never appear in NET-S2C-LOBBY-STATE.

## Notes

A player choosing blind is stuck with a bad pick for eight minutes. The mitigation is not to
unlock loadouts — it is to make the choice informed.

Duplicate personas are GOOD: they add a candidate to each other's crowd.
