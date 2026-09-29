---
id: ADR-0023
title: Cinderfall catches everyone in it, and the caster may kill there
version: 1.0.0
status: accepted
owner: Lead Game Designer
last_updated: 2026-09-25
depends_on: [ADR-0013, ADR-0017, GDD-04-ABILITIES]
---

# ADR-0023 — Cinderfall catches everyone in it, and the caster may kill there

- **Status:** accepted. **The rule is decided and the build is US-0104.** Until that story
  lands, the shipped `.tres` still blocks the kill.
- **Date:** 2026-09-25
- **Deciders:** owner. Asked *"keep ours or take the reference's?"*, the owner answered *"Bitte
  wie es im Original ist umändern."*
- **Supersedes:** GDD-04 §3.1's *"the design detail that carries the ability"* (the caster's
  own kill-block). **Amends:** GDD-04 §3.1, §3.5 and the §7 pair audit; `TUN-CINDERFALL-BLOCKS-KILL`
  true → **false** and `TUN-CINDERFALL-BLOCKS-LOS` true → **false**, both neutralised rather
  than removed; `TUN-CINDERFALL-SUSPICION` 40 → **0**; invariant 12's reason;
  `TUN-CINDERFALL-DURATION`'s meaning (how long a caught figure is held)
- **Related:** ADR-0013 (the reference wins where a rule diverges), ADR-0017 (the `Staggered`
  state), ADR-0018 (the prey's teeth), ADR-0019 (a stun costs the contract), ADR-0022 (what a
  kill pays), design laws 3 and 5

## Context

**Ours is a pure escape.** A 5 m cloud at the caster's feet blocks line of sight and forbids
any kill initiated inside it, the caster's included. GDD-04 §3.1 calls that symmetry the thing
that makes the ability defensive, and says without it *"the dominant play would be 'cloud, then
kill inside it', and a kill nobody can see is a legibility-law violation."*

**In the reference, "cloud, then kill inside it" is the ability's main use, and it is legible.**
A recorded match shows the hunter using it three times as an ambush:

- a burst beside the contract, then a kill in the cloud;
- a burst on landing from above, then a kill in the cloud;
- a burst at arm's length, with the contract doubled over coughing, then a kill that paid the
  **top** stealth rung.

A strategy guide describes it the same way: everybody around the caster keels over coughing and
can neither run nor fight back; it is *"the perfect chance to have your way with them or make
your escape"*, and a pursuer caught in it is a free 200-point stun. The recording and the guide
are in the chat log of 2026-09-25, never here (never-do #5).

**The legibility worry does not hold, because the victim is the one who coughs.** The burst is
the loudest tell in the kit and is unchanged: a crack audible at 25 m and a 9 m Startle. A
contract caught in the cloud sees it, is doubled over inside it, and knows exactly what
happened. What GDD-04 feared was a kill *nobody can see*. This is a kill whose victim watched
it arrive.

## Decision

1. **The cloud catches everyone inside `TUN-CINDERFALL-RADIUS` except the caster, for as
   long as it stands.** That means anyone there at the burst and **anyone who walks in
   afterwards** (open question A, answered by the owner). A caught figure coughs **until the
   cloud ends** (open question B, answered): no movement, no kill, no stun, no cast, but able
   to be killed. So `TUN-CINDERFALL-DURATION` is a gameplay number again, and no separate catch
   duration is needed. The candidate state is ADR-0017's `Staggered`, which already means *a
   timed incapacitation that is not a stun*.
2. **NPCs in the radius are caught too, with the same animation.** This is clone parity rather
   than a guess about the reference (GDD-03 §6.5): if only players coughed, the cloud would name
   every player inside it.
3. **A caught pursuer of the caster counts as stunned by the caster**: `SCORE-STUN`, the
   contract loss (ADR-0019), everything a pressed stun does. This is the guide's *free
   200-point stun*, and it is a tooth for the prey in design law 5's sense.
4. **The kill-block goes.** `TUN-CINDERFALL-BLOCKS-KILL` becomes false, for the caster and for
   everyone else.
5. **The line-of-sight block goes too.** `TUN-CINDERFALL-BLOCKS-LOS` becomes false. The guide
   says the ability *guarantees* a Focus kill, which a cloud that breaks line of sight could
   never allow.
6. **Using it is not high-profile.** `TUN-CINDERFALL-SUSPICION` becomes 0, because the recorded
   ambush kill still paid the top rung. The Startle wave and the crack remain the honest cost.
   The owner confirmed on 2026-09-25 that no ability use is high-profile (ADR-0022 B).
7. **Unchanged:** the burst at the caster's feet (ADR-0013 already took this from the
   reference), the radius, the 45 s cooldown (the recording reads roughly 40–50 s) and every
   tell.

## Open questions (sourcing)

- ~~**A. Does the cloud catch people who walk in after the burst?**~~ **Yes** (owner,
  2026-09-25).
- ~~**B. How long are the caught incapacitated?**~~ **For the whole of the cloud** (owner,
  2026-09-25).
- **C. `TUN-CINDERFALL-DURATION` is now how long a caught figure is held, and it is 6.0 s.**
  The owner raised it from 4.0 at the controls on 2026-09-03, when the cloud was only cover.
  Now it holds a caught pursuer longer than a pressed stun (`TUN-STUN-FREEZE` 4 s). The
  reference's cloud lasts about 3 s, or 4 s for the stronger variant the recording shows.
  **Left at 6.0 and put to the owner**, because they set it by hand.

## What this costs, said plainly

- **GDD-04 §3.5 loses its only pure escape.** Cinderfall's role becomes *escape and ambush*,
  its *best used* row gains *at arm's length*, and the §7 pair audit (Cinderfall + Lunge
  especially) has to be redone.
- **A hunter who reaches arm's length with Cinderfall ready wins.** The counterplay is the
  reference's: the burst is loud and short-ranged, so a contract who reads a figure closing
  steps away, or stuns first.
- **Invariant 12 keeps its inequality and changes its reason.** It no longer *denies* a kill.
  It makes sure the radius can catch somebody standing at kill range.

## Consequences

US-0104 builds it: the catch, the pursuer-as-stun, both flags, the suspicion cost and the
invariant, tested at the system's seam (a kill in the caster's own cloud lands, a caught
pursuer pays `SCORE-STUN`, an NPC in the radius is caught). GDD-04 §3.1 is rewritten there, not
here, so the document and the behaviour change in one commit.
