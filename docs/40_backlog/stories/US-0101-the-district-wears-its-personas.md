---
id: US-0101
title: The district wears its personas
version: 0.1.0
status: done
owner: Lead Game Designer
last_updated: 2026-09-24
depends_on: [GDD-03-SOCIAL-STEALTH, BIBLE-ART, BIBLE-NET-PROTOCOL]
---

# US-0101 — The district wears its personas

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-MATCHFLOW` |
| **Systems** | `SYS-CROWD`, `SYS-HUD` |
| **Estimate** | M |
| **Depends on** | US-0100, US-0079 |

## Description

**Asked from the controls on 2026-09-24, after US-0100's playtest passed on every point:**
*"Du kannst bereits den NPCs unterschiedliche Farben geben. Damit ist es noch besser zu
tracken."* The contract portrait has named a persona since US-0100, and nothing on screen
looked like one: every NPC and every player was the same generic grey body.

ART_BIBLE §3 already reserved four identity hues, one per persona, and `data/personas/*.tres`
had held them since US-0046, read by nothing. `PersonaBody` had built the four silhouettes since
US-0046 and been instantiated only by a tool. This story puts both on every figure.

**The crowd cannot be dressed without the players, and that is the whole design of it.** A
coloured crowd around grey players names every player; grey clones around coloured players do
the same from the other side. So a client dresses **nobody** until it holds both halves — the
seed (`NET-S2C-MATCH-START`, at `ACTIVE`) for the crowd and the roster
(`NET-S2C-LOBBY-STATE`, from the countdown) for the players — and then everybody at once.

## Acceptance criteria

- [x] Every persona body wears its `PersonaData.identity_hue` on its clothing; the props stay
      neutral. A player and a clone of one persona are the same class and the same colours, so
      GDD-03 §6.3 rule 6 holds by construction. `test_persona_body.gd`.
- [x] NPC clones are dressed from the seed with the **server's own** derivation arguments —
      `CrowdRoster.PLAYABLE` and `TUN-LOBBY-MAX-PLAYERS` — and filler archetypes stay undressed.
      `test_wardrobe.gd` holds the client's derivation to the server's call site.
- [x] Every player's persona reaches every client on `NET-S2C-LOBBY-STATE`, re-sent on the deal,
      on every join and on every departure; `PROTOCOL_VERSION` 3 → 4.
      `test_lobby_state_wire.gd`, `test_the_personas_reach_every_client.gd`.
- [x] **Nobody is dressed until everybody can be**: the seed alone dresses nobody, the roster
      alone dresses nobody, both dress the crowd, the other players and the local pawn in one
      pass, a body admitted later is dressed on arrival, and **a lost server or a failed
      connection undresses everybody through `Net.stop()`** — asserted through ENet's own
      signals, because `GameState.clear()` had no production caller until review of #232 found it.
- [x] `NpcView` never dresses a body itself, so nothing can go around the gate.

## Test notes

Falsified, one plant at a time against the suite that owns each, all six red by name: the gate
opened on the seed alone; the crowd derived from the dealt set instead of `PLAYABLE`; the torso
drawn neutral; a departure not announced; a short roster packet read; `NpcView` dressing a body;
and, after review, `Net.stop()` not clearing the mirror — three tests red, including the next
lobby being dressed from the last match's seed.

`tools/persona_lineup.tscn` renders the four side by side, windowed. It became a scene here:
`PersonaBody` now asks `CrowdRoster.PLAYABLE` whether it is dressed, `CrowdRoster` reads
`Tuning`, and a `-s` script has no autoloads — `test_a_script_tool_gets_no_autoloads.gd` said so
before the tool was ever run.

## Notes

**`GreyboxBody` is retired.** A `PersonaBody` with no persona draws the same generic figure, and
one class that can change what it wears is one place the size and the facing must agree, where
swapping between two classes was two.

**`NET-S2C-LOBBY-STATE` was reused rather than a new id minted.** Its row has described
`players[]{peer_id, persona, ready}` since M0, which is exactly the roster US-0078's criterion 4
asks for (*persona selections are VISIBLE to all players*). `ready` is left out until the lobby
gives it a writer.

**`SessionWire` split out of `EventWire`**, which reached `.gdlintrc`'s twenty public methods.
The line was already there: `NET-S2C-MATCH-START` rode `SESSION` in a class whose docstring
called itself the `EVENT` doorway.

**What is still not the design.** Colour makes a persona readable at a glance, which is a
placeholder for art that does the same thing with a costume. What it must never become is a way
to tell a player from a clone, and nothing here does: the Noticed tint and the Exposed outline
(GDD-03 §2) are still unbuilt on the client, so the hue is the same on every figure of a persona
whatever its tier.
