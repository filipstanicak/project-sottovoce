---
id: US-0058
title: Compass lock, reveal and portrait
version: 0.2.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-26
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-07-SUSPICION]
---

# US-0058 — Compass lock, reveal and portrait

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-DETECTION` |
| **Systems** | `SYS-COMPASS` |
| **Estimate** | M |
| **Depends on** | US-0057 |

## Description

The lock arc, the silhouette reveal, and the permanent contract-portrait fill (ASM-0030).

## Acceptance criteria

- [x] Lock requires the contract within a 25 degree cone, within 20 m, with server-side LOS.
      The cone is gated on the hunter's **own yaw**, not the wobbled Compass bearing — otherwise a
      hunter aiming at the drifted cone would fail to lock a contract standing where they point.
- [x] Fill time 1.6 s, reduced by the Cold Read passive.
      **`PASV-COLDREAD` has no reader**: `NET-C2S-LOADOUT` is unbuilt and `PawnContext` has no
      passives field, the same blocker as `PASV-STILLNESS`. `CompassLock` takes the flag as an
      argument and is tested both ways, so it is one call site the day a loadout exists.
- [x] A broken lock DRAINS 1.4x faster than it filled.
- [x] Completion reveals a silhouette for 1.5 s, with a 4 s re-reveal cooldown.
      **Nothing draws the silhouette** — that is `render_state`'s channel and the HUD's, US-0084.
- [x] Completion ALSO fills the contract portrait PERMANENTLY for that contract.
      The server-side latch is built and asserted. **What the portrait would show does not exist**:
      no client renders a player's persona at all, and there is a protocol leak that would make it
      free if it did — see the notes.
- [x] The portrait resets to UNKNOWN on reassignment.
- [x] A lock cannot complete through a walking group's incidental gaps.

## Test notes

`test_lock_through_crowd.gd`, `test_lock_decay_faster.gd`, `test_portrait_permanent.gd`.

---

## What was found building it

**THE 50/50 PEEK TEST DOES NOT PIN 1.4, AND FALSIFYING IT IS HOW THAT SURFACED.** Planting a decay
rate of 1.0 left `test_peeking_never_completes_however_long_it_goes_on` **green**: at 1.0 an
alternating view nets exactly zero, which never reaches full either. That test proves
`decay >= fill` and nothing more.

The assertion that actually pins the number is the **duty cycle**. At rate `r` the break-even is
`r / (1 + r)` — 0.583 at 1.4 and 0.500 at 1.0 — so a hunter watching **55 % of the time**
completes a lock under the weaker rule and never does under the tuned one.
`test_watching_barely_more_than_half_the_time_still_never_completes` is that, and it goes red
against the planted rate.

**THE ARC HAD TO TRACK ITS OWN CONTRACT, SEPARATELY FROM THE PORTRAIT.** The first version
inferred a reassignment from `portrait_for` alone, so a hunter who had half-filled an arc and
never completed it carried that half onto their next contract — free progress toward identifying
somebody they had stopped hunting. Caught by `test_reassignment_also_empties_the_arc`, which
read 0.52 against an expected 0.

**`NOBODY` IS DELIBERATELY NOT A REASSIGNMENT.** `TUN-CONTRACT-REASSIGN-DELAY` points a killer at
nobody for three seconds; clearing the portrait on that would make the breath itself destroy an
identification earned before it.

**AND A TEST THAT ASSERTED NOTHING WAS COUNTED AS RISKY RATHER THAN PASSING.**
`test_completing_a_lock_fills_it` called a helper that returns on success and asserted nothing of
its own. GUT reports a zero-assertion test as risky, which is how the omission surfaced — the
unit suite's `pending` count going 7 to 8 with nothing red.

---

## A protocol leak that would defeat ASM-0030, reported rather than fixed

`NET-S2C-PLAYER-JOINED` is specified as `peer_id:u8, persona:u8`, and `NET-S2C-CONTRACT-ASSIGNED`
as `contract_peer:u8`. **A client holding both can join them and read its contract's persona
directly**, on the tick the contract is assigned, with no lock.

That defeats this story's whole payoff, contradicts GDD-03 §8.5, contradicts NETWORK_PROTOCOL §5's
own "not sent" table, and contradicts §9's checklist line *"No payload contains the contract's
persona"* — four places that all say the opposite of what the two payloads together do.

**Neither message is implemented**; both are lobby work in M5/M6, so nothing leaks today. It is
not fixed here because changing a merged `NET-` ID's payload is the owner's call. TDD-07 §4.5.2
carries the two candidate fixes.

## Notes

Fill time deliberately exceeds one NPC stride cycle, so a lock needs a genuinely clear view. A
shorter fill would let hunters lock through crowds, making the crowd cosmetic.

Drain being faster than fill pushes the hunter toward standing still and watching — which also
keeps their own suspicion at zero. The mechanic and the thesis agree.

The permanent portrait is what makes a lock worth its 1.6 s cost; the 1.5 s reveal alone is not.
