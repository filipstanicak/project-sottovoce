# ADR-0021 — The hunter knows the face from the start

- **Status:** accepted
- **Date:** 2026-09-22
- **Deciders:** owner
- **Supersedes:** ASM-0030 (voided). **Amends:** GDD-03 §8.5's *not told* table (the persona
  row), GDD-06 §B, UI_UX_SPEC §1.1 row B, NETWORK_PROTOCOL §7's withholding table, US-0073's
  portrait criterion; closes owner decision 4
- **Related:** ADR-0013 (the reference wins where a rule diverges), US-0058 (the lock), US-0078
  (persona selection — where the portrait gets something to show), design law 4

## Context

Reported from the controls on 2026-09-22, after the first matches with a timer and the
alone-gain gone: *"der Contract zeigt Unknown und wenn ich in der Nähe bin, identified. Wie
mein Opfer aussieht muss ich von Anfang an wissen … Wie macht das Original es?"*

**What was built.** ASM-0030: the contract portrait is a featureless `UNKNOWN` on assignment
and fills with the contract's persona only when a Compass lock completes — 20 m, 1.6 s of
unbroken view — permanently for that contract, reset on reassignment. GDD-03 §8.5 listed the
persona among the things the hunter is *deliberately not told*, with the strongest word in
the table: *"Critical. If you knew your target was a Lucerna, the crowd would collapse from
60–90 candidates to 8–13."* ASM-0030 added a second reason: the lock's own 1.5 s silhouette
reveal was judged too brief to justify 1.6 s of standing still, and the permanent portrait was
what made locking worth doing.

**What the reference does.** The target's picture is on screen from the moment the contract
is assigned — *"your target's information will appear on screen … Take a look at the
character skin so you know who you are looking for when you get too close to use the
compass."* The uncertainty the reference authors is never *which persona*; it is *which of
the identical figures is the human*, answered by watching how they move. Its lock is a
targeting act (the team bonuses speak of *"a target you locked on"*), not an identity reveal.
The sources are deliberately not reproduced here — every one of them names the franchise and
`ip-guard` fails hard on that (never-do #5). They are in the chat log of 2026-09-22, beside
ADR-0013's audit table.

## Decision

**The contract portrait shows the contract's persona from assignment.** No lock is needed to
learn what your target looks like. The portrait resets on reassignment as before, to the new
contract's persona.

**The lock keeps everything else it does.** The 1.5 s silhouette reveal on completion
(`TUN-COMPASS-REVEAL-DURATION`), the reveal cooldown, `SCORE-FOCUS` riding `can_lock`,
`PASV-COLDREAD`'s faster fill, and the server-side `portrait_revealed` latch all stand. The
latch's *meaning* narrows from "the persona is known" to "a lock has completed for this
contract" — the wire field keeps its slot and its name.

**Nothing in the wire changes in this decision.** `NET-S2C-CONTRACT-ASSIGNED` still carries a
contract slot and a reason. The persona reaches the client when players *have* one: persona
selection is US-0078's lobby (M6), and until then a player has no persona server-side at all
(`server_root._stand_the_crowd_up` says so in its own comment). When it arrives, the persona
travels with the contract — one byte on `NET-S2C-CONTRACT-ASSIGNED` and a `PROTOCOL_VERSION`
bump, recorded there and not here.

## Why the withholding argument does not hold

**The crowd is supposed to collapse to 8–13, and M3 was built for exactly that.** `CloneBalance`
keeps `TUN-CROWD-CLONE-LOCAL-MIN` clones of every player's persona within reach; the clone
parity rules exist so that a persona's clones are indistinguishable from the player at every
LOD; US-0078 says *"duplicate personas are GOOD: they add a candidate to each other's crowd."*
Every one of those is the reference's protection — the one figure among its lookalikes — and
ASM-0030 stacked a second protection on top of it for the same threat.

**The second protection has a real cost, and it falls on the skill the game is about.** A
player cannot learn to read gait, path choice and hesitation if they do not know whose gait to
compare against. Under ASM-0030 the hardest read in the game is unlearnable until the lock
performs it for you, which inverts design law 4: patience did not win the identification,
standing still inside 20 m did.

**And the "lock is not worth it" half was an argument for a payoff, not for this one.** The
lock still answers the question the portrait never could — *which* of the eleven — for 1.5 s,
and it still pays `SCORE-FOCUS`. The reference has no silhouette reveal at all and its lock is
used constantly; ours is more generous, not less.

## What was considered and not done

**A silhouette *class* instead of the full persona** (GDD-06 open question 1, UI_UX_SPEC
open question 2). Halfway to the reference is still a divergence, and the class would need
four new strings, a new wire enum and a new failure mode to watch — for a hedge against a
threat the clone system already covers.

**Keeping `UNKNOWN` until the first snapshot with a persona.** That is what happens anyway
while personas do not exist server-side; it is a fact about the build rather than a rule, and
it is written as such in US-0073.

**Removing the `portrait_revealed` field.** A frozen wire slot costs nothing and the latch
still drives the lock's own feedback (`SFX-COMPASS-LOCK-COMPLETE`, the check on the
portrait); deleting it would be a format change for tidiness.

## Consequences

- ASM-0030 is `void`. Owner decision 4 (`NET-S2C-PLAYER-JOINED`'s persona field *"defeating
  ASM-0030"*) is closed — there is nothing left for it to defeat.
- GDD-03 §8.5 loses its persona row, struck with the reason rather than deleted; the other
  eight rows stand, and the principle beneath the table — *the Compass answers where roughly,
  and nothing else* — is untouched, because the portrait is not the Compass.
- GDD-06 §B, UI_UX_SPEC row B, TDD-11's `CompassVm` note, the bus catalogue's
  `EVT-CONTRACT-PORTRAIT-REVEALED` and US-0073's portrait criterion are amended in place with
  the old rule preserved.
- **The portrait cannot draw a persona until US-0078**, and US-0073's criterion says so; the
  widget's `Identified` check is the lock's feedback and stays.
- GDD-06 failure mode 12 (*"the portrait reveals too much"*) is retired with the assumption:
  what it watched for is now the design.
