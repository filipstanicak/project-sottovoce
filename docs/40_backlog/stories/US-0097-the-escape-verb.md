---
id: US-0097
title: The escape verb — a hunt that can be survived
version: 0.2.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-27
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

## The tunables this needs — proposed, not yet shipped

**Deliberately not added to `TUNABLES.md` by this story.**
`test_tunables_match_the_document.gd` compares the document against the *shipped* profile, so a
documented row with no `.tres` row behind it goes red — and trap 17 says a missing `.tres` row is
indistinguishable from a deliberate zero. They land together, with the implementation.

| Proposed ID | Value | Derivation |
|---|---|---|
| `TUN-PURSUIT-DURATION` | **10.7 s** | `TUN-COMPASS-WARN-RADIUS` ÷ `TUN-SPEED-BLENDWALK` = 15.0 / 1.4. **The chase ends when the prey could have walked out of warning range at civilian speed** — so escaping never requires running, which is design law 1 and ADR-0012 expressed as a duration rather than asserted about one. |
| `TUN-PURSUIT-SIGHT-RANGE` | **25.0 m** | Must exceed `TUN-COMPASS-WARN-RADIUS`, or a chase could not be sustained at the range it opens at. |
| `TUN-PURSUIT-SIGHT-CONE` | **90°** | Wider than `TUN-KILL-FACING-CONE` (60°) and than the lock cone (25°): you can see somebody without staring at them. |
| `TUN-PURSUIT-CLOSECALL-RADIUS` | **5.0 m** | Inside `TUN-STUN-RANGE` × 1.5 — near enough that the prey could have been reached. |
| `TUN-SCORE-ESCAPE` | **+100** | The reference's own value. One base kill: successfully surviving a hunt is worth what successfully ending one is, which is the same statement `TUN-SCORE-STUN` makes. |
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

## Acceptance criteria

- [ ] A chase opens on exactly the prey-warning condition and on no other; a hunter below
      `TUN-COMPASS-WARN-MIN-TIER` never opens one, at any range.
- [ ] Sight of the prey refreshes the bar to full rather than incrementing it.
- [ ] With no sight, the bar empties in `TUN-PURSUIT-DURATION` and not in some multiple of it —
      the timer is in net ticks and uses `Tuning.ticks()`, not `step_ticks()` (trap 9).
- [ ] A blend entered **out of** the hunter's sight conceals the prey; a blend entered **under**
      unbroken sight does not, and the flag clears the moment sight breaks.
- [ ] When the bar empties, the hunter is removed and reinserted through the same
      `ContractCycle` calls a respawn uses, with `Reason.ESCAPE`, announced after
      `TUN-CONTRACT-REASSIGN-DELAY`.
- [ ] The escapee's former hunter is excluded by the existing insertion constraint, so the same
      pairing cannot recur immediately.
- [ ] The cycle is still a single Hamiltonian cycle with no fixed point after an escape —
      asserted by extending `test_contract_cycle_fuzz.gd`'s event mix rather than by a new test,
      so the 10 000-event invariant covers escapes too. **The fuzz must assert it reached at
      least one escape**, or it will pass by never generating one.
- [ ] The pursuit sight test spends **no raycast the Compass lock has not already spent**:
      `test_los_single_query.gd` still finds one query site and still asserts it casts, and a
      new test measures `DetectionSystem.raycasts_last_tick` unchanged with six chases live.
- [ ] Both parties are told: the hunter's own-gameplay block and the prey's each carry
      `pursuit_fraction:u8`. **Nothing in either payload names the other player** — the prey
      learns *a bar is draining*, never whose.
- [ ] `SCORE-ESCAPE` and `SCORE-CLOSECALL` fire as events with the right conditions. **Their
      payout is `SYS-SCORE`'s and is not this story's** — this story emits, US-0064 pays.
- [ ] A chase survives the hunter's tier falling back to Anonymous; only a kill, a death, a
      disconnect or the timer ends one.

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
