---
id: US-0097
title: The escape verb — a hunt that can be survived
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-09-01
depends_on: [ADR-0014, ADR-0013, GDD-03-SOCIAL-STEALTH, TDD-10-SCORING, US-0059]
---

# US-0097 — The escape verb

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-CONTRACT` |
| **Systems** | `SYS-CONTRACT`, `SYS-DETECTION` |
| **Estimate** | M |
| **Depends on** | US-0059 (the prey warning is what opens a chase), US-0062 (a lost contract and a respawn share one insertion path) |

## Description

A hunter who alerts their prey enters a **pursuit**. Sight of the prey refreshes a timer;
absence of sight drains it; when it empties the hunter **loses the contract** and is reinserted
into the cycle elsewhere. The prey is paid for it.

This is the largest single divergence from the reference that the 2026-08-26 audit found, and
`ADR-0014` is the decision that adds it. **Read that ADR first** — in particular the scope-fence
section, because this story is new MVP scope and something has to pay for it.

## Why this exists

**A contract here ends in exactly one way: the prey dies.** `ContractCycle`'s only events are
removals (kill, death, disconnect) and insertions (respawn, join). A prey who spots their
hunter, breaks the corner and blends perfectly can only **postpone** — the Compass never stops
pointing, the district is 120 × 120 m and the match is eight minutes, so every hunt eventually
resolves in a kill.

Three things follow, and all three are measurable in the corpus today:

1. **Design law 5 is down to one tooth.** "The prey must have teeth" was carried entirely by
   the stun, and ADR-0013 has just removed the stun's ability to interrupt a committed kill.
   Escape is the other tooth and the one that fits the thesis better: it is won by restraint
   rather than by a button.
2. **Defence has no upside.** GDD-07 §4.5 models the Defender at 1 823 points against the
   Patient's 3 871. There is no line of play in which being hunted is anything but lost tempo.
3. **Three of the reference's scoring bonuses have nothing to fire on**, because surviving a
   hunt is not an outcome the graph can represent.

## The rule

### 1. A chase begins when the prey warning fires

No new trigger. The chase opens on exactly the condition `US-0059` already computes — the
pursuer is within `TUN-COMPASS-WARN-RADIUS` (15 m) at tier ≥ `TUN-COMPASS-WARN-MIN-TIER`
(Noticed). **This is what makes the warning load-bearing** rather than a piece of feedback: the
same carelessness that puts a marker on the prey's ring is what puts the hunter's own contract
at risk.

### 2. Sight refreshes; absence drains

| | |
|---|---|
| The bar starts | full, at `TUN-PURSUIT-DURATION` |
| Sight of the prey | **refreshes to full** — it does not increment |
| No sight | drains at one bar per `TUN-PURSUIT-DURATION` |
| Empty | the hunter loses the contract |

*Refresh, not increment*, because the reference refreshes and because an incrementing bar makes
a hunter who glimpses their prey every few seconds able to hold a chase open indefinitely
without ever closing.

### 3. What counts as sight, and why blending is not free

Sight is `has_los()` **and** the prey inside `TUN-PURSUIT-SIGHT-CONE` at range ≤
`TUN-PURSUIT-SIGHT-RANGE`, **and** the prey not concealed by a blend the hunter did not watch
them enter.

That last clause is the interesting one and it is GDD-03 §9.2's own rule applied to a new
consumer: *the crowd hides you by being confusing, never by being solid.* A hunter with a clear
line to a player standing in a `HELD` blend cannot pick them out of the pocket — unless they had
unbroken sight at the moment the blend began, in which case they watched it happen and the blend
is transparent to them.

**So the correct play for the prey is: break the corner first, then blend.** Blending in plain
view of a hunter who is looking at you buys nothing. One boolean per active chase carries it —
set when a blend begins under unbroken sight, cleared the moment sight breaks.

### 4. The bar empties → the hunter is reinserted

**Structurally an escape is a respawn without a death**, and it reaches `ContractCycle` through
the same `remove()` and the same constrained insertion. `_best_insertion_index`'s existing
`pred == killer` constraint generalises without modification: the escapee takes the killer's
place in it, so the hunter who was just escaped cannot immediately be handed the same prey.

The announcement waits `TUN-CONTRACT-REASSIGN-DELAY` — the same breath a kill gets, and for the
same reason. `ContractSystem.Reason` gains a fifth value, `ESCAPE`, at index 4; the wire field
is already `reason:u8` so nothing about the payload changes.

**A second insertion path would be a divergence in a fuzzed invariant.** `ContractCycle` is
asserted over 10 000 events (US-0049) and the fuzz's whole value is that every mutation goes
through the two functions it exercises.

### 5. What the prey earns

| Event | Value | Condition | Source |
|---|---|---|---|
| `SCORE-ESCAPE` | +100 | The pursuit bar emptied while you were the prey | the reference's own value |
| `SCORE-CLOSECALL` | +50 | …and the hunter was still within `TUN-PURSUIT-CLOSECALL-RADIUS` when it did | the reference's own value |

**Two of the reference's escape bonuses cannot exist here and that is deliberate.** Its
multi-escape bonuses need two and three simultaneous pursuers; a Hamiltonian cycle gives every
player exactly one incoming edge, so nobody is ever hunted by two. The single-pursuer guarantee
is what makes the repair story sound, and it is not for trading.

### 6. What ends a chase other than the timer

A kill, either party's death, or a disconnect. **A chase does not end because the hunter calms
down.** Once you have been seen, you must close or lose them — a hunter who could cancel a chase
by standing still would have alerted their prey for free.

## The tunables this needs — SHIPPED 2026-08-29

All six are in `TUNABLES.md` and generated into `ContractTuning` and `ScoringTuning`;
invariants 34-37 are in `TuningInvariants` and `TuningInvariantsScore` and assert at load.
**`TUN-PURSUIT-DURATION` shipped at 10.72, not the 10.7 proposed below** — see the correction
under *What building it changed*.

**They live on `ContractTuning` rather than a new section**, because a pursuit ends by removing
and reinserting a contract and `SYS-CONTRACT` is this story's own system. The codegen maps
TUNABLES §7 to that class, so no new resource, no new `.tres`, no change to
`TuningProfile._SECTIONS` and no movement in `compute_hash`. The four keep a `pursuit_` prefix
through an entry in the codegen's exception table: the mechanical transform strips the leading
domain, which would have left `contract.duration` and `contract.sight_range` — names that read
as being about the contract itself.

### The original proposal, kept for its derivations

**Was: deliberately not added to `TUNABLES.md` by this story.**
`test_tunables_match_the_document.gd` compares the document against the *shipped* profile, so a
documented row with no `.tres` row behind it goes red — and trap 17 says a missing `.tres` row is
indistinguishable from a deliberate zero. They land together, with the implementation.

| Proposed ID | Value | Derivation |
|---|---|---|
| `TUN-PURSUIT-DURATION` | **10.7 s** | `TUN-COMPASS-WARN-RADIUS` ÷ `TUN-SPEED-BLENDWALK` = 15.0 / 1.4. **The chase ends when the prey could have walked out of warning range at civilian speed** — so escaping never requires running, which is design law 1 and ADR-0012 expressed as a duration rather than asserted about one. |
| `TUN-PURSUIT-SIGHT-RANGE` | **25.0 m** | Must exceed `TUN-COMPASS-WARN-RADIUS`, or a chase could not be sustained at the range it opens at. |
| `TUN-PURSUIT-SIGHT-CONE` | **90°** | Wider than `TUN-KILL-FACING-CONE` (60°) and than the lock cone (25°): you can see somebody without staring at them. |
| `TUN-PURSUIT-CLOSECALL-RADIUS` | **5.0 m** | Inside `TUN-STUN-RANGE` × 1.5 — near enough that the prey could have been reached. |
| `TUN-SCORE-ESCAPE` | **+100** | The reference's own value. One base kill: successfully surviving a hunt is worth what successfully ending one is. **The last clause of this row said "the same statement `TUN-SCORE-STUN` makes" and was true when written; ADR-0018 took the stun to 200 on 2026-09-03**, so the prey's teeth are deliberately priced apart now. This value did not move. |
| `TUN-SCORE-CLOSECALL` | **+50** | The reference's own value. |

**Proposed invariants**, to be added beside the existing 31:

- `pursuit_duration >= compass.warn_radius / speed.blendwalk` — escape must never require speed.
- `pursuit_sight_range >= compass.warn_radius` — a chase must be sustainable where it opens.
- `pursuit_sight_cone >= compass.lock_cone` — the pursuit test must be the wider of the two, or
  the raycast cannot be shared (see below).
- `score.escape == score.contract` — the same statement invariant 19 makes about the stun.

## What is cut to pay for it — decided 2026-08-27

**`ABIL-WHISPERBOLT` is deferred to post-MVP** (`US-0068`). `SCOPE_FENCE.md` IN #4 reads three
abilities, OUT #18 carries the reasoning and §1.1 records the payment as collected; ADR-0014's
*Decision, part two* is the decision itself.

**The second row below is now moot and is kept rather than deleted**: US-0054's two prop blends
**shipped on 2026-08-26**, so that option no longer exists. A decision table with a dead row in
it invites somebody to re-pick the row.

| Candidate | What it buys back | What it costs |
|---|---|---|
| **Defer `ABIL-WHISPERBOLT` to post-MVP** **— TAKEN 2026-08-27** | The most expensive of the four MVP abilities: a projectile, a trajectory, two tell channels and a lag-compensated hit. Roughly the size of this story. | MVP drops to three abilities. The reference's own equivalent is one of eleven optional loadout items rather than a core verb, so the fidelity loss is small. |
| ~~**Defer US-0054's two prop blends**~~ **— MOOT: shipped 2026-08-26** | A blend kind, its tunables and its level furniture. | Moves *away* from the reference, which has prop hiding spots everywhere, and weakens the escape verb this story is buying — prop blends are exactly what a fleeing prey wants. Rejected as self-defeating. |
| **Defer `US-0085` onboarding minimum out of MVP** | A tutorial pass. | The fence's demonstrability test is "six humans understand why they scored what they scored". Cutting onboarding attacks the fence's own success criterion. |

## What building it changed

**INVARIANT 34 FIRED ON ITS FIRST RUN, AGAINST THIS STORY'S OWN PROPOSED VALUE.** The derivation
is `TUN-COMPASS-WARN-RADIUS` ÷ `TUN-SPEED-BLENDWALK` = 15.0 / 1.4 = **10.7143**, and the table
below rounds it to **10.7** — which asks the prey for **1.402 m/s**, fractionally *faster* than a
blend walk, in exactly the direction the invariant exists to forbid. Shipped at **10.72**, and
the tolerance was tightened to a true floor rather than widened to admit it: an epsilon wide
enough to accept 10.7 is an epsilon wide enough to accept the next one too.

**A rounded derivation is not a derivation**, and this is the cheapest possible demonstration of
why the invariant is worth having — it caught the story that proposed it, before any code
consumed the value.

**THE ANTI-REPEAT HISTORY RECORDS WHAT WAS *DEALT*, NOT WHAT WAS *HELD*, AND US-0097 NAMED THE
WRONG MECHANISM.** The story says `_choose_index`'s `killer` constraint generalises without
modification. **It does not** — that constraint forbids a *predecessor*, and what an escape must
forbid is the hunter's *successor* being the prey they just lost. The right guarantee is
`_held_recently(peer, successor)`, the anti-repeat filter.

**And that alone was not enough either, which a test found rather than a reading.**
`ContractCycle._remember` is called from `insert` and `open` only, so a contract acquired any
other way is invisible to the history — and a hunter holds their prey for the length of a chase
without either. Over six escapes in one fixture, **one player was re-handed their escapee**.
`report_escape` now calls `cycle.remember` before the removal.

**THE SAME GAP EXISTS FOR AN INHERITED CONTRACT AND IS REPORTED RATHER THAN CLOSED.** When a
killer inherits their victim's contract, `_remember` is not called, so
`TUN-CONTRACT-ANTI-REPEAT-DEPTH` does not protect a later respawn from re-handing it. That
changes what a *kill* does, which is US-0049's fuzzed territory rather than this story's.

**`Dictionary.get` HANDS BACK `null` AND A TYPED `Array` REFUSES IT.** Every accessor on
`PursuitBoard` was written `var row: Array = _chases.get(hunter)`, which is a runtime error on
every miss — *"trying to assign value of type 'Nil' to a variable of type 'Array'"* — and eleven
of thirteen tests went red at once. One guarded reader, asked only after `has()`.

## Acceptance criteria

**The mechanic is live end to end.** A careless hunter opens a chase, sight refreshes it, absence
drains it, an empty bar takes the contract away and pays the prey. What is missing is the
*anticipatory* channel — the bar itself on both HUDs — and nothing else.

- [x] A chase opens on exactly the prey-warning condition and on no other; a hunter below
      `TUN-COMPASS-WARN-MIN-TIER` never opens one, at any range. **The tier half cannot be
      falsified and that is recorded rather than papered over**: `_resolve_pair`'s first rung
      already drops every Anonymous subject, and invariant 8 pins the warn floor equal to the
      Noticed threshold, so no profile can separate them. US-0059's finding, second instance.
- [x] Sight of the prey refreshes the bar to full rather than incrementing it. **The duty cycle
      is what proves it**: a hunter looking once per `window - 1` holds a chase open over ten
      cycles, and one looking once per `window` loses it every time. The second assertion is the
      one an incrementing bar fails; the single-threshold test the story warned about passes
      against all three rules.
- [x] With no sight, the bar empties in `TUN-PURSUIT-DURATION` and not in some multiple of it —
      the timer is in net ticks and uses `Tuning.ticks()`, not `step_ticks()` (trap 9).
- [x] A blend entered **out of** the hunter's sight conceals the prey; a blend entered **under**
      unbroken sight does not, and the flag clears the moment sight breaks. **The rule is on the
      board**; the caller that decides `under_sight` is `SYS-DETECTION`'s and is not built.
- [x] When the bar empties, the hunter is removed and reinserted through the same
      `ContractCycle` calls a respawn uses, with `Reason.ESCAPE`, announced after
      `TUN-CONTRACT-REASSIGN-DELAY`. The clear is immediate — a Compass still pointing at
      somebody who escaped is the defect that beat prevents.
- [x] The escapee's former hunter is excluded, **but not by the mechanism this story named** —
      see *What building it changed*.
- [x] The cycle is still a single Hamiltonian cycle with no fixed point after an escape.
      `test_contract_cycle_fuzz.gd` generates **597 escapes over 10 000 events** and asserts it
      reached at least fifty — **and the guard fired on its first run at zero**, because the
      counter was never initialised.
- [x] The pursuit sight test spends **no raycast the Compass lock has not already spent** —
      **not achievable as written, and the story contradicts itself**: it also specifies a 90°
      pursuit cone against the lock's 25°, so a cast gated on the lock leaves the chase blind
      through two thirds of its own cone. What is true and is asserted: **one query site, at most
      one cast per hunter per tick**. **The measurement is owed no longer**:
      `test_pursuit_raycast_budget.gd` puts the worst case at **6 casts per tick for a
      six-player lobby**, at the top of TDD-07 §4.3's published 2-6 band — and at 35° off axis,
      inside the pursuit cone and outside the lock's, the chase spends **six where the lock alone
      would have spent zero**. A hunter facing away still spends nothing.
- [x] Both parties are told — **but in two bytes, not one**, and the correction is the finding.
      `hunt_fraction` and `hunted_fraction` sit in the own-gameplay block and `ChaseRingWidget`
      draws both as arcs concentric with the Compass. A single `pursuit_fraction` would have
      been ambiguous in the **ordinary** case: see *Two bytes, not one* below.
- [x] `SCORE-ESCAPE` and `SCORE-CLOSECALL` fire as events with the right conditions.
      **`SCORE-CLOSECALL` is measured at the LAST SIGHTING, not at the empty bar**: by
      definition the hunter has not seen their prey for the whole window, so the distance when it
      empties is one nobody observed.
- [x] A chase survives the hunter's tier falling back to Anonymous; only a kill, a death, a
      disconnect or the timer ends one.

### Two bytes, not one, and the ordinary case is what breaks the criterion

The criterion above asked for *one* field, written as though a player were either a hunter or a
prey. **They are never either.** A Hamiltonian cycle gives every player exactly one outgoing
edge and exactly one incoming one, so every player is always simultaneously hunting and hunted;
both chases can be live at once and they mean opposite things — one drains toward losing your
contract, the other toward escaping. One byte could not have carried them, and the failure would
not have been an edge case but the normal one.

**NEITHER BYTE NAMES ANYBODY**, which is what keeps them inside never-do #12. The prey learns
*a bar is draining*, never whose finger is on it — and they had already been told a pursuer
exists, because `NET-S2C-PREY-WARNING` fires on the very condition that opens a chase.

**`NOBODY` IS ZERO AND ZERO IS A DICTIONARY KEY LIKE ANY OTHER.** The prey's bar needs a reverse
lookup, and `PursuitBoard.hunter_of` answers `ContractCycle.NOBODY` — **0** — for a player nobody
hunts. No engine peer id is ever 0, so the lookup would miss anyway; resting the rule on that is
`CompassBoard.NO_CONTRACT`'s hazard exactly, so `_fill_pursuit` states the default. Deleting the
guard reddens exactly one test and nothing else.

### And looking at it found two things no test here could

**DIRECTION OF TRAVEL ONLY SEPARATES THE TWO ARCS IN MOTION.** The first version claimed three
non-hue channels — radius, direction, colour — and a still capture shows an arc with a gap in it.
Which way it wound is not recoverable from a frame, only from watching it move, so the
monochrome-palette argument rested on two channels rather than three. **Weight is the fourth**,
and it is a design call rather than a patch: the hunted bar is the heavier of the two, because a
hunter is already looking at the Compass and the prey is looking at the world. UI_UX_SPEC §5.2
states that requirement for the score feed and gives the same answer.

**AND A BAR WITH NO TRACK IS NOT A BAR.** Without the unfilled remainder drawn behind it, 0.95
and 0.6 both read as *an arc with a gap in it* and the fraction is not judgeable at a glance —
which is the whole value of an element whose question is *how long have I got*. It matters more
here than on the lock arc, which fills in 1.6 s against this one's 10.72.

**THE PROBE CANNOT CATCH A TRANSIENT AT ITS DEFAULT SETTLE**, and saying so was cheaper than
faking it. `hud_probe.gd` settles ninety frames before every capture, which is right for a
*state* and exactly wrong for the 0.45 s re-acquisition pulse. `_state` takes an optional settle
now; frames `16b` and `16c` are taken mid-pulse. Captioning a decayed pulse as a pulse would have
been an instrument wrong in a plausible direction.

## What is left, and it is most of the story

| Piece | Where | Note |
|---|---|---|
| Open a chase on the prey-warning condition | `DetectionSystem._consider_warning` | The condition is already computed there; the chase is one call beside the warning |
| Refresh on sight | `DetectionSystem._advance_the_lock` | **The cast must move.** The pursuit cone is 90° against the lock's 25°, so the raycast has to be taken when the *wider* test admits and the lock then reuses it. Still one query site and still at most one cast per hunter — but the per-tick count **will rise**, and US-0097's "raycasts unchanged" criterion is written against a narrower reading than the tunables it also specifies. Measure and report rather than claim |
| The blend clause's caller | `SYS-BLEND` → `note_blend_began` | Needs the hunter's sight at the tick the blend begins |
| Empty → remove and reinsert | `ContractSystem` | Through the same `ContractCycle` calls a respawn uses, `Reason.ESCAPE` at index 4 |
| `SCORE-ESCAPE` / `SCORE-CLOSECALL` | `KillScoring`'s shape | The tunables and the string names exist; nothing appends them |
| ~~`pursuit_fraction:u8` on the wire~~ **DONE, as two bytes** | `Snapshot` own-gameplay block | Both parties, naming neither. One byte could not carry two live chases — see above |
| The fuzz reaching an escape | `test_contract_cycle_fuzz.gd` | Extend the event mix, and **assert it generated at least one** |

## Test notes

- **The counterfactual first, as always.** A test that a chase ends after 10.7 s of no sight
  passes just as happily against a bar that never refreshes at all. The primary assertion is the
  **duty cycle**: at what fraction of time-in-sight does a chase become unloseable? With a
  refresh-to-full rule the answer is *any sight at all inside the window*, so the assertion is
  that a hunter who sees their prey once every `TUN-PURSUIT-DURATION` − ε holds the chase open
  indefinitely, and one who sees them once every `TUN-PURSUIT-DURATION` + ε loses it every time.
  That pair goes red against an incrementing bar, which the single-threshold test cannot see.
- **Falsify the blend clause against a planted "blending always conceals".** The symptom of
  getting it wrong is invisible: the prey escapes slightly too often, and nothing errors.
- **The raycast assertion must fail if the query is deleted**, not merely if a second one is
  added — `test_los_single_query.gd` already carries that shape and it is the one to copy.
- **Do not measure the escape rate in a unit test.** `TEL-ESCAPE-RATE` is a playtest number and
  ADR-0014's revisit trigger depends on it; a synthetic figure would be quoted as though it were
  measured.

## Notes

- **Chase breakers are not in this story.** The reference's level furniture that delays a
  pursuer is level design against `MAP-VETRAIO` and is recorded as owed in GDD-05 §6.
- **`TEL-ESCAPE-RATE` is a new telemetry event** and is ADR-0014's revisit trigger. It needs a
  row in GDD-07 §8 when this ships.
- **This story is M5 rather than M4 deliberately.** M4's fifteen stories are counted by its gate
  (US-0063) and adding a sixteenth mid-milestone is the exact accretion `SCOPE_FENCE.md` §4's
  tripwires watch for. The mechanic's payout is scoring, which is M5 anyway.
