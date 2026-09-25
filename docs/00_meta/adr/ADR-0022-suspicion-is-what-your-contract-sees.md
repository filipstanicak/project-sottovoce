---
id: ADR-0022
title: Suspicion is what your contract sees
version: 1.0.0
status: proposed
owner: Lead Game Designer
last_updated: 2026-09-25
depends_on: [ADR-0013, ADR-0014, GDD-03-SOCIAL-STEALTH, GDD-06-UI-AUDIO]
---

# ADR-0022 — Suspicion is what your contract sees

- **Status:** proposed
- **Date:** 2026-09-25
- **Deciders:** owner. **Asked for by the owner on 2026-09-25** (*"Bereite die ADR vor"*),
  answering owner decision 11, which recommended waiting for the first playtest with human
  hunters. The owner overruled the wait on the evidence of a recorded reference match.
- **Supersedes, once accepted:** ADR-0020 (its one neutralised source becomes moot). **Amends:**
  design law 1's wording; GDD-03 §2 (the rendering rule), §3 (the whole scalar), §4's crush,
  §7.7.1 (what opens a chase), §9.1 (the prey warning) and §10.2 point 2 (the stun floor);
  GDD-06 §2.2 A and C; GDD-07's stealth ladder; TUNABLES §3 and §11; invariants 18 and 32;
  NETWORK_PROTOCOL §4's own-gameplay block; closes owner decision 11
- **Related:** ADR-0013 (the reference wins where a rule diverges), ADR-0014 (the chase),
  ADR-0019 (a stun costs the contract), ADR-0020, ADR-0021

## Context

**Our suspicion is one number per player, and everybody reads it.** `SYS-SUSPICION` integrates
a player's own high-profile actions wherever they happen — run, sprint, climb, the roof
stratum, a bump, a loud ability — and that one value feeds seven consumers: the stealth ladder
(`SCORE-SILENT`, `-HALFSEEN`, `-RECKLESS`), the chase trigger (§7.7.1), the prey warning
(§9.1), the render matrix's tint and outline (§2.1), the stun floor (`TUN-STUN-MIN-TIER`), the
HUD tier widget with its source list and vignette, and the results screen's time spent
Anonymous.

**The reference keeps one meter per relationship, and only the contract's eyes move it.** A
hunter's meter drains when *they* act high-profile *in their contract's line of sight*; what
they do anywhere else is free. Its top stealth bonus is earned by *never* having acted
high-profile in the contract's sight, the second by having done so briefly, the third by having
done so for longer without being revealed. The meter does **not** recover within a contract
(recovery was the sequel's change). When it empties the hunter is revealed and a chase begins,
and a kill in a chase pays the base only. The prey's side is its mirror: a red marker over a
pursuer who acts high-profile in sight, and an arrow at the compass during a chase.

**A recorded match showed it plainly, which is why the owner stopped waiting.** A hunter ran
across roofs and through a crowd out of the contract's sight, dropped, killed, and was paid the
top rung (+300). Under our rules the roofs alone cost +18/s and the run +14/s, so that kill
would have paid the 50 rung or nothing. The meter sits beside the contract portrait, and the
owner's own reading of it on 2026-09-25 is the one this ADR adopts: *"how close we are to being
revealed to our contract, and only by what happens near or in its sight."* The recording, the
wiki pages and the frame times are in the chat log of 2026-09-25, never here (never-do #5).

**The reference's point values already match ours, measured rather than inferred.** The
recording's results screen gives each bonus's count and total: 300, 200 and 50 for the three
rungs, the last of which TUNABLES called *"the weakest-sourced number in this table"*. What
differs is what moves the meter, not what it pays.

## Decision (proposed)

### 1. Suspicion becomes a relationship

`SYS-SUSPICION` keeps one value per **ordered pair (hunter, contract)**, from 0 to 100, **reset
to 0 when a contract is assigned**. It rises only while **both** hold:

- the hunter is performing a **high-profile act** (see open question C for the list), and
- the contract has **line of sight** to the hunter within `TUN-SUSPICION-SIGHT-RANGE` (new,
  ours, not sourced).

**It never falls within a contract.** No decay, no blend crush. Those were answers to a global
meter: nobody needs to calm down in front of people who are not watching.

What a player does outside their contract's sight costs nothing: running, climbing, the roofs,
the loud abilities. **Speed stays spent anonymity, but only in front of the person you are
hunting.**

### 2. The ladder reads the pair, and stays a partition

| At initiation | Pays | ID |
|---|---|---|
| value exactly 0: never high-profile in the contract's sight | **+300** | **a new score ID**, working name *Unseen*, minted at acceptance |
| 0 < value ≤ `TUN-SUSPICION-SILENT-BAND` | +200 | `SCORE-SILENT` (condition amended) |
| above the band, below 100 | +50 | `SCORE-HALFSEEN` (condition amended) |
| 100 reached: chase open | 0, event still fires | `SCORE-RECKLESS` (condition amended) |

Exactly one of the four fires per kill, as today. **`SCORE-PATIENT` is deprecated** (TUNABLES
§19): its 100 existed only to make Silent + Patient sum to the reference's 300, and a real top
rung replaces the arithmetic. Invariant 18 becomes *top rung ≥ 3 × `CONTRACT`*. Invariant 32
becomes *top rung > `SILENT` > `HALFSEEN` > `RECKLESS`* with `HALFSEEN > 0`.

**The ID is deliberately not written out here.** Every `SCORE-` id under `docs/` is harvested
into `Ids` (trap 1), and a proposed ADR must not mint one.

### 3. The pair opens the chase

§7.7's pursuit (ADR-0014) starts **when the pair reaches 100**. The prey-warning radius and
tier are no longer its trigger, which is the reference's rule: *being revealed* starts the
chase, not being careless nearby.

### 4. The prey sees what the reference shows

- A **red marker over the pursuer's head** while that pursuer's pair value is rising. The
  marker is on the pursuer, and it is *your* pursuer, so it is the relationship marker ADR-0013
  already permits under never-do #12.
- An **arrow on the Compass ring during a chase** only. This replaces §9.1's
  15 m / Noticed bearing.

**The marker names a body, and `test_warning_names_nobody.gd` exists to refuse exactly that.**
It must be amended in the same commit as the marker, citing this ADR. It is not weakened
before then.

### 5. The global consumers retire, each for a named replacement

| Retires | Replaced by |
|---|---|
| The render matrix's tint and outline (§2.1) | The marker in §4. The reference draws nothing at a stranger |
| The HUD tier widget, its source list and the Exposed vignette | **The arc at the contract portrait**: the pair value, with the rung word beside it, as the reference draws it |
| The own-gameplay block's `suspicion`, `tier`, `active_sources` | The pair value and rung for your own contract, plus the set of pursuers currently marked. **A `PROTOCOL_VERSION` bump** |
| `anonymous_ticks` on the results screen | Undecided. US-0077's criterion needs a new line or a new meaning |
| The music stems keyed to tier (GDD-06 §7, unbuilt) | Keyed to the pair and the chase |

### 6. Built in slices, each shippable

1. The pair meter, computed beside the old one and read by nothing, with its own measurement.
2. The ladder switches.
3. The chase trigger and the prey marker.
4. The HUD and the wire.
5. The stun floor goes (open question A, answered).
6. The global tunables are neutralised on ADR-0020's pattern, IDs kept.

## Open questions (sourcing, not preference)

- ~~**A. Can an unrevealed pursuer be stunned?**~~ **ANSWERED 2026-09-25 by the owner: yes.**
  In the reference any pursuer you have identified can be stunned, whatever they have done.
  `TUN-STUN-MIN-TIER` and GDD-03 §10.2 point 2 (*an Anonymous hunter is unstunnable*) go in
  slice 5. That strengthens the prey, so never-do #13 does not stand in the way. What still
  protects a patient hunter is that the prey has to **pick them out of the crowd** first.
- ~~**B. Is ability use high-profile?**~~ **ANSWERED 2026-09-25 by the owner: no.** Using an
  ability is not a high-profile act, the disguise and the charge included. The recording
  already showed it for the Cinderfall equivalent. What an ability *does* may still be one: a
  Lunge's dash is a sprint.
- **C. The exact high-profile list.** Running, sprinting, climbing and freerunning jumps are;
  walking on a roof apparently is not. The bump and a whiffed kill are unknown.
- **D. What is "in sight"?** Line of sight within a range is certain. Whether the contract's
  facing matters is not, and the server does know every client's camera yaw.
- **E. The Silent band's width** (*"a short amount of time"*). Ours to tune.
- **F. A kill during a chase:** does it lose only the stealth rung, or every situational bonus
  too? The wiki's wording is *"only be able to attain a Kill bonus"*.

## What this costs, said plainly

- **Design law 1 changes wording, and the thesis shifts with it.** *"Speed is spent anonymity"*
  becomes *"speed in your contract's sight is spent anonymity."* A sprint behind your
  contract's back is free. That is the reference, and the owner chose it.
- **The crowd's mechanical role narrows.** Blending no longer lowers a number. It hides a
  **body** from a hunter who is looking, which is the reference's reason to blend (the hidden
  bonus, the escape), and GDD-03 §4.3's patience rule has to be re-argued on those terms.
- **The prey loses a warning a careless hunter used to give.** A hunter sprinting 10 m behind
  you out of your sight raised a bearing on your ring; now nothing tells you. The reference's
  answer is audio (the proximity whisper), which is unbuilt.
- **Seven consumers move and one wire format changes.** It is the largest rule change since
  M4, which is why §6 slices it.

## What was considered and not done

- **Keeping the global meter and adding a sight multiplier.** Rejected: the recording's roof
  kill would still have paid less than the top rung. The difference is structural, not a rate.
- **Letting the pair recover.** That was the sequel's rule. The reference this project follows
  does not, and a meter that recovers lets a hunter who blundered in front of the contract
  simply wait it out.
- **Waiting for the playtest, as decision 11 recommended.** Overruled by the owner.

## Consequences

Owner decision 11 closes when this is accepted. Until then **nothing may be built on it**
(DECISION_LOG §2.1), apart from slice 1's meter that nothing reads. ADR-0020 is superseded on
acceptance. The Cinderfall change is ADR-0023, and it depends on open question B here only for
what its kill pays.
