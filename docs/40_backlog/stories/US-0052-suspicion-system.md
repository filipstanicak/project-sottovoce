---
id: US-0052
title: SuspicionSystem and impulses
version: 0.2.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-25
depends_on: [TDD-07-SUSPICION, GDD-03-SOCIAL-STEALTH]
---

# US-0052 — SuspicionSystem and impulses

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-SUSPICION` |
| **Systems** | `SYS-SUSPICION` |
| **Estimate** | M |
| **Depends on** | US-0051 |

## Description

The server system driving the integrator, applying impulses, and replicating own-value and tier.

## Acceptance criteria

- [x] Runs once per net tick, AFTER the crowd resolves.
- [x] Nearest-NPC distance comes from the shared spatial hash, not a physics query.
- [x] Impulses queue and drain at a fixed pipeline position, so ordering is deterministic.
      **Amended: they queue on the SYSTEM, not the pawn** — `PawnContext` is replayed during
      prediction reconciliation, so a queue there would be walked once per replayed command.
      TDD-07 §2.2.1.
- [x] NPC bump debounced at 0.8 s — one shove is not five stacked charges.
      **The rule is built and tested; nothing calls it.** `npc_server.tscn` and
      `pawn_server.tscn` both mask `WORLD` only, so a pawn and an NPC pass through each other
      and there is no contact to report. See the notes.
- [ ] Witnessed kill applies only if another PLAYER had line of sight at initiation.
      **Blocked twice over:** `has_los()` is `SYS-DETECTION`'s (US-0056) and there is no kill to
      witness until `SYS-KILL` (US-0060). `SuspicionImpulses.queue()` is the entry point.
- [x] Own suspicion and tier replicate to the owning client only.
- [x] Active source bitfield replicates, driving the HUD source list.
      The HUD itself is US-0084; the byte is on the wire and correct.
- [x] Suspicion is NEVER predicted client-side.

## Test notes

`test_suspicion_impulse_debounce.gd` asserts both directions: five bumps inside the window are
one charge, and five spaced a cooldown apart are five. A debounce test that only asserts the
first passes on an implementation that refuses every bump after the first forever.

`test_suspicion_additive.gd` was never written under that name and is not written now — the
property is `test_suspicion_math.gd`'s `test_sources_sum_additively`, which asserts sprint plus
roof plus open sums to 49/s and reaches Exposed inside two seconds. A third copy of an
assertion is worse than a missing one; TDD-07 §7 records where each named test actually lives.

## Notes

Crowd must resolve before suspicion. Computing against last tick's crowd would let a player
accrue alone-suspicion inside a pocket that has already re-formed — the player believes they are
blended and is not.

The active-source list exists because a player who cannot attribute their suspicion cannot learn
from it, and the total alone is not attributable.

---

## What was found building it

**THE SOURCE LIST AND THE NUMBER ARE ONE DECISION NOW, NOT TWO.** `SuspicionSources.of()` is the
only place the five conditions are applied and `SuspicionMath.gain_rate()` returns the sum of the
rates of exactly the bits it sets. Written as two functions they would drift the first time a
condition was retuned — no error, and the symptom is a player reading "sprinting" while the value
climbs because they are alone. `test_suspicion_sources.gd` sweeps all 48 combinations of
state × roof × alone × blending and asserts the two agree, **then asserts the sweep reached every
bit** — an `of()` that always returned nothing would satisfy the agreement perfectly.

**THE SPEED READ IS HORIZONTAL, AND IN THREE AXES `PASV-STILLNESS` WOULD HAVE BEEN DEAD ON
ARRIVAL.** A grounded `CharacterBody3D` carries a small downward velocity from its floor snap,
comfortably above `TUN-PASV-STILLNESS-SPEED-CEILING` 0.15 — so every standing player in the game
would silently lose the passive they equipped. Nothing would have errored and no existing test
touches it.

**AND THE TEST FOR THAT FAILED FIRST, ON THE HARNESS RATHER THAN THE CODE.** Run as two
sequential halves on one pawn it compares 42.00 against 37.20, because `ticks_since_gain` survives
a reset of the value: the second half decays for the eighteen ticks the first spent arming the
delay. **4.8 points is exactly `TUN-SUSPICION-DECAY-BASE` over `TUN-SUSPICION-DECAY-DELAY`**, and
it reads like a finding about the axis under test. The two halves run side by side in one pass now.

**AN IMPULSE RE-ARMS THE DECAY DELAY**, which the documents do not say either way.
`ticks_since_gain` means *ticks since this player last did something suspicious*, and without the
re-arm a shove taken by an already-decaying player is refunded from the tick it lands on — so two
players sitting at 15, one from running and one from a bump, would decay differently. A decay
curve carrying information about how the value was earned is a channel nothing in the design
intends. TDD-07 §2.2.1.

**A GUARD SCANNED FOR A STRING LITERAL AND PASSED ON EVERY FILE.** The first version of
`test_suspicion_is_wired_into_the_server.gd` looked for `&"suspicion"` in the system's source —
and `SourceScanner` **blanks string literals** so a guard is never tripped by its own
documentation, which is exactly why it exists. It matched the blank. Caught because it failed on
correct code; it asks the object for its stage now. Trap 3's family, third instance in a guard.

**`MatchContext` GAINED `pawn_contexts`, AND THE DRIFT IS ASSERTED RATHER THAN HOPED FOR.**
`ctx.pawns` holds `CharacterBody3D`s, which is what the four crowd consumers want; a system
wanting velocity, state and elevation had nowhere to reach — `PawnHost.context_for()` is
plumbing, not a dependency. The two are written and erased on adjacent lines in `PawnHost` and
`test_pawn_host.gd` asserts their key sets never differ. A peer present in one and not the other
is a player whose suspicion never moves while everything else about them works.

**NOTHING CAN BUMP AN NPC, AND THE BLOCKER IS PHYSICAL RATHER THAN A MISSING CALLER.** Both
scenes mask `WORLD` only, so a pawn and an NPC pass through each other with no contact of any
kind. Charging `TUN-SUSPICION-GAIN-NPC-BUMP` +15 for an overlap the player felt nothing from
would be an impulse with **no tell**, which design law 3 forbids as firmly for a cost as for an
ability. Making the crowd solid changes how movement through a dense pocket feels and is the
owner's — TDD-07 §9 question 5.
