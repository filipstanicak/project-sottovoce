# ADR-0020 — Walking alone costs nothing

- **Status:** accepted
- **Date:** 2026-09-15
- **Deciders:** owner
- **Supersedes:** nothing. **Amends:** GDD-03 §3.2's source table and §3.3's formula,
  §4's *what breaks it* row and §5.3's empty plaza; GDD-05's context note and Campanile
  rows; TDD-07 §2.1; `TUN-SUSPICION-GAIN-OPEN` 6.0 → **0.0**, neutralised rather than
  removed (TUNABLES §19)
- **Related:** ADR-0013 (the reference wins where a rule diverges), US-0051 and US-0052
  (the integrator and its sources), design laws 1 and 2

## Context

Reported from the controls on 2026-09-15, after the first full match with a timer on
screen: *"Ich bin bereits exposed wenn ich mal alleine laufe ohne Gruppe. Das ist ja im
Original auch nicht so."*

**It was true, and it was designed.** `SuspicionSources.of()` set the `OPEN` bit whenever
no NPC stood within `TUN-SUSPICION-OPEN-RADIUS` 6 m, at any speed including standing
still, and the bit paid `TUN-SUSPICION-GAIN-OPEN` 6.0/s. Because no decay runs while any
source pays (ASM-0008, and `SuspicionMath.decay_rate` returns 0 on `gain > 0`), a player
walking alone at the civilian speed reached **Noticed in 5 s and Exposed in 11.7 s**
without running, climbing, bumping anybody or pressing anything. GDD-03 §3.2 published
both figures as the feature: *"the mechanic that makes an empty plaza a danger zone and
makes crowd-seeking a constant background pressure."*

**The reference charges nothing for being alone.** Its detection is a meter on the
*relationship*: the pursuer's high-profile actions deplete the target's threat meter while
the target is in sight — *"any high profile actions you make will deplete their threat
meter"*, *"if your pursuer has performed too many high profile actions while in sight of
you, your threat meter will deplete and they will be revealed"* — and walking is low
profile wherever it happens. Groups and hiding places bear on the *escape* (the pursuit
bar depletes faster in hiding) and on the `Hidden` and `Incognito` bonuses; they have no
bearing on whether a walker is noticed. The sources are deliberately not reproduced here —
every one of them names the franchise and `ip-guard` fails hard on that (never-do #5).
They are in the chat log of 2026-09-15, beside ADR-0013's audit table.

**The empty plaza is still dangerous there — visually.** A hunter scanning an empty
square has one thing to look at. GDD-03 §4 already makes exactly this argument for the
concealment props: *"a bench in an empty street is visually conspicuous even while
mechanically anonymous."* The alone gain was a second, mechanical answer to a question
the crowd itself answers.

## Decision

**`TUN-SUSPICION-GAIN-OPEN` is 0.0.** Walking, standing or sitting alone costs no
suspicion at any speed. The sources that remain — run, sprint, climb, the roof stratum,
the bump, the loud abilities, the failed and the witnessed kill — are all either
high-profile actions or acts, which is the reference's own line.

**Neutralised, not removed, on ADR-0013's `TUN-SCORE-RECKLESS` pattern.** The ID, the
generated field and the condition are all retained. `SuspicionSources.of()` still reads
the radius and sets the `OPEN` bit **only while the rate is above zero**, because a HUD
word beside a value that is not rising is precisely the drift that file exists to refuse
(*"the list and the number are one decision"*). The bit keeps its wire slot — bit 3 of
`active_sources`, NETWORK_PROTOCOL §4 — so no client on any build misreads a byte.
Restoring the number restores the mechanic in one edit, and the tests that prove the
crowd query is wired run with the number restored — the Core tests on a duplicated
`SuspicionTuning`, the system test on the live profile for its own duration, put back in
`after_each` — so the day it returns nothing has rotted.

**`TUN-SUSPICION-OPEN-RADIUS` stays live.** `SpatialHash` sizes its cells from it and
`SYS-SUSPICION` still answers the nearest-NPC query against it every tick; the reading is
cheap and the field on `SuspicionState` is what a restored gain would read.

## What this costs, said plainly

**Design law 2 loses a line, not a law.** *"The crowd is a mechanic, not a backdrop"*
was served by this source in one direction — it made *leaving* the crowd cost something.
The crowd still does everything else it does: the blend crush, the group blend, the
pocket, clone parity, the startle wave, the onlookers. What is gone is the background
pressure toward company on an ordinary walk, and the reference shows a social-stealth
game standing without it: the pressure toward company there is that a lone figure is
*readable*, which is design law 6's kind of uncertainty rather than a number.

**Design law 1 is untouched.** Speed still costs anonymity at every rung above stroll,
which was the thesis; the alone gain was never about speed.

**Two level-design promises are now visual rather than mechanical.** GDD-03 §5.3's
Piazza Secca and GDD-05's Campanile were both written as *"accrues `TUN-SUSPICION-GAIN-OPEN`"*
spaces. The Campanile still pays the roof toll — 18/s, Exposed in 3.9 s — and the plaza
is still an unbroken sightline with no blend action in it. Both rows are amended to say
what they still are. `TUN-CROWD-COUNT-MIN`'s rationale leaned on this gain and now stands
on the blend argument alone; the floor is unchanged.

**The balance model is not re-derived.** GDD-07's *Parked* archetype listed *"quiet
corners accrue +6/s"* among its punishments; it keeps the other three, and the Compass
beacon was always the load-bearing one.

## What was considered and not done

**A per-relationship, line-of-sight-gated meter — the reference's actual structure.** Our
value is one number per player, read by everybody; the reference's is one meter per
(pursuer, target) pair, moved only by what the target can see. That is not a tunable, it
is `SYS-SUSPICION`'s model, and the Compass warning, the stun gate and the render matrix
are all built on the one-number reading. It is **owner decision 11** in `CLAUDE.md`,
raised by this ADR and deliberately not decided by it.

**Lowering the gain rather than zeroing it.** A rate that makes a walker Noticed in 30 s
rather than 5 s is the same rule the reference does not have, slower. Half a divergence is
still a divergence, and it would keep the HUD printing *alone* under a number that then
needs explaining.

**Deleting the source outright** — the bit, the field, the radius. The wire byte's bit
order is frozen, the radius has two live readers, and a mechanic the owner may want back
for a different map is cheaper to keep dormant than to re-derive.

## Consequences

`test_suspicion_math.gd` carries the report as a test: twelve seconds alone at stroll on
the shipped profile leaves the value at zero, and restoring 6.0 in the profile reddens it
by name. `test_suspicion_sources.gd` asserts that the shipped profile lists nothing and
charges nothing for being alone, in every movement state, and that the two agree.
`test_suspicion_system.gd` proves the same at the system's seam and keeps the crowd-query
proofs by restoring the number on the live profile for their own duration — the one write
to `Tuning` under `test/`, scoped and put back in `after_each`.

**The match timer's first playtest also asked what the `×2` is** —
`TUN-MATCH-FINALPHASE-MULT`, the Final Contract's doubled scoring. It is this project's
rule, not the reference's: the reference's session clock turns red at one minute and
nothing else changes. Same shape as this decision, and **owner decision 12** rather than
a change made in passing.
