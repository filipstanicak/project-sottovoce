---
id: US-0066
title: Ability pipeline and validation
version: 1.0.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-28
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY]
---

# US-0066 — Ability pipeline and validation

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY` |
| **Estimate** | M |
| **Depends on** | US-0064 |

## Description

Request, server validation, effect application, replication and presentation — plus the
AbilityEffect base class.

## Acceptance criteria

> **NO CLIENT COULD REACH ANY OF THIS UNTIL 2026-09-02.** Every criterion below was true
> of `SYS-ABILITY` and **none of them was reachable by pressing a key**:
> `NET-C2S-ABILITY-REQUEST` had its RPC, its authority row, its channel, its router hop
> and its `server_root` wiring, and **nothing on the client ever called it**. Q and F did
> literally nothing through this story, US-0067 and US-0070. Found by the owner pressing
> F; `test_every_c2s_message_has_a_sender.gd` is the guard.
>
> **The criteria are not being untickd**, because each is true of the system and was
> tested against it. What was missing is a hop no criterion here names — which is the
> lesson: **a story can be honestly complete and its feature still unreachable.**

- [x] Five validations: equipped, cooldown, global cooldown, legal pawn state, aim range.
      `AbilityRules.check` is pure and answers with **the first rung that fails**,
      which is also the order a player would want to hear: *you do not have that*
      before *not yet*, and both before anything about their body. The state check
      is a **denylist** — the legal states are every other one, and an allowlist
      would silently forbid each future locomotion state nobody remembered.
- [x] Aim is CLAMPED server-side, not rejected, when out of range.
      And the direction is normalised in **one** place, so a zero, a NaN or a
      400-long vector cannot reach an effect. Four effects each writing their own
      guard is four chances for one to forget.
- [x] Cooldowns are integer tick deadlines on the server; the client mirrors optimistically.
      The owner's own two ride the snapshot's existing `cooldown_a_tick` /
      `cooldown_b_tick`, so a mispredicted cooldown self-corrects within 33 ms.
- [x] Cooldowns start at ACTIVATION, not at effect end.
      Asserted by running past the effect's own duration and checking the cooldown
      has been ticking throughout — Second Face lasts 15 s, and starting its
      cooldown at expiry would make the real interval 45 s against a published 30.
- [x] Cooldowns reset on death.
      **And not in `PawnContext.reset_for_spawn`, which is where US-0062 expected
      it.** That object is replayed during prediction reconciliation, so a cooldown
      living there would be rewound and re-applied on every correction — the third
      time this finding has appeared, after the suspicion impulse queue and the
      patient speed ring. This closes US-0062's last open criterion.
- [x] NET-S2C-ABILITY-STARTED broadcasts to ALL clients within tell radius, reliably.
      **The one broadcast in `MatchAnnouncer`**, and the only message in this game
      whose recipient list exists to make sure nobody is left out rather than to
      withhold something. Reliable, because a dropped snapshot costs a frame of
      smoothness and a dropped tell costs the victim their only warning.
- [ ] The TELL is predicted locally and cancelled on denial; the EFFECT is not predicted.
      **Blocked on a client that can cast.** The server half is done —
      `NET-S2C-ABILITY-DENIED` carries its reason — and the local tell needs
      `AbilitySlots` and an input path, which are US-0071's and US-0073's. The
      half that is here is the half that cannot be added later: the denial arrives
      with something to cancel *on*.
- [x] Other players' cooldowns are never replicated.
      Asserted on the **format** rather than on a filter: there is no field
      anywhere in `Snapshot` for another player's cooldown, and a missing field
      cannot be bypassed by a later caller. Kit-reading is a skill (GDD-04 §5.1).

## Test notes

`test_ability_validation.gd`, `test_ability_aim_clamped.gd`, `test_cooldown_authority.gd`,
`test_ability_started_broadcast.gd`.

## What this story does NOT do

**No ability does anything yet.** `AbilityData.effect_script` is null for all four
`.tres` files, so a cast runs the whole pipeline — validation, cooldown, suspicion
cost, tell broadcast — and changes nothing in the world. Cinderfall, Lunge and
Second Face are US-0067, US-0070 and US-0069.

**The loadout is a placeholder that says so.** `NET-C2S-LOADOUT` and the lobby are
US-0071's; until then `server_root` gives every joiner the two MVP actives, because
a pipeline nobody can reach is a pipeline nobody can test. Validation 1 is
implemented and tested against the table either way.

**`AbilityDenial.Why.OUT_OF_RANGE` and `NO_LOS` are declared and unreachable.**
Aim is clamped rather than refused, and none of the MVP three needs line of sight —
Cinderfall is thrown, Lunge is a dash, Second Face is on the self. They exist
because the protocol row does, and so that an ability which genuinely needs a hard
limit reaches for the reason that already means what it means.

## Notes

Clamping rather than rejecting means a rounding difference between predicted and server aim
produces the outcome the player intended rather than a denial.

Tell latency is a NETCODE issue, not a balance one. If Lunge proves unstunnable in practice,
check NET-S2C-ABILITY-STARTED delivery time before touching tunables.
