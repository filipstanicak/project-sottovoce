---
id: ADR-0014
title: The escape verb — a hunt that can be survived
version: 1.1.0
status: accepted
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [ADR-0013, DOC-SCOPE-FENCE, GDD-03-SOCIAL-STEALTH]
supersedes: none
---

# ADR-0014 — The escape verb, and what the fence pays for it

## Context

The 2026-08-26 fidelity audit against the reference (ADR-0013) found seven mechanics missing
here. Six are ordinary backlog. **The seventh is a verb nobody had noticed was absent, and it
is the largest single divergence in the project: there is no way to escape a hunt.**

In this game a contract ends in exactly one way — the prey dies. `ContractCycle` has three
events, all of them deaths or arrivals: `remove` on a kill, a death or a disconnect, and an
insertion on a respawn or a join. A prey who spots their hunter, breaks the corner, loses
them completely and blends into a market can do nothing better than **postpone**. The hunter's
Compass never stops pointing. Given eight minutes and a bounded 120 × 120 m district, every
hunt eventually resolves in a kill.

**The reference does not work that way.** A pursuer who alerts their target enters a chase;
line of sight refreshes a depleting timer; and if the target stays unseen until it empties,
**the pursuer loses the contract entirely** and waits for a new one. The target is paid for it.
The mechanic is sourced in the owner's external design notes, which name the title, the wiki
pages and the point values.

**Three consequences follow, and all three are already visible in this corpus:**

1. **Three of the reference's scoring bonuses have nothing to fire on here.** Its
   escape-side bonuses pay the prey for surviving a hunt; ours cannot exist, because surviving
   a hunt is not an outcome the graph can represent.
2. **The prey has exactly one answer to a hunter, and it is violence.** Design law 5 says the
   prey must have teeth, and the only tooth is the stun — which ADR-0013 has just made weaker
   by removing its ability to interrupt a committed kill. Escape is the *other* tooth, and it
   is the one that fits the thesis better: it is won by restraint, not by a button.
3. **Being hunted is currently a pure loss of tempo.** You cannot win the exchange, so the
   correct play while hunted is to keep hunting your own contract and accept the death. That
   is why the balance model's Defender archetype scores 1 823 against the Patient's 3 871 —
   defence has no upside except the stun.

## The scope-fence problem, stated rather than stepped around

`SCOPE_FENCE.md` IN #5 reads *"the full loop: Compass, suspicion, blending, detection, kill,
stun, respawn, contract reassignment, scoring with every bonus in the table"*. **Escape is not
in that enumeration and no bonus in the table pays for it**, so by the fence's own rule this
requires an ADR *"naming what is being cut to pay for it"*.

Two readings were considered and the harder one is taken:

- **The lawyerly reading**, rejected: escape is already inside "contract reassignment", which
  is IN, and the enumeration is under-specified rather than exclusive. This is defensible and
  it is how scope quietly accretes. The fence exists precisely to refuse it.
- **The reading taken**: this is new scope, it is worth its cost, it is a *consequence of an
  already-approved ADR* rather than a fresh proposal, and something must pay for it.

## Decision

**Add the escape verb to the MVP.** A hunter who alerts their prey enters a pursuit; sight of
the prey refreshes a timer, absence of sight drains it, and when it empties the hunter is
removed from the cycle and reinserted elsewhere under the constraints that already govern a
respawn. The prey is paid for it. Amend `SCOPE_FENCE.md` IN #5 to name escape explicitly and
bump that document's version.

**Structurally it is a respawn without a death**, which is why it costs so much less than it
looks: `ContractCycle.remove()` and the constrained insertion are built, proven and fuzzed
(US-0049), the reassign breath is built (US-0050), and the line-of-sight query the timer needs
is the one the Compass lock already spends on the same ordered pair.

**What is cut to pay for it was left open here and was decided on 2026-08-27: `ABIL-WHISPERBOLT`.** See *Decision, part two*, below.
Three candidates are priced in the story, `US-0097`. The recommendation is to defer
`ABIL-WHISPERBOLT` from M5 to post-MVP: it is the most expensive of the four MVP abilities to
build correctly — a projectile, a trajectory, two tell channels and a lag-compensated hit —
and the reference's own equivalent is one of eleven optional loadout items rather than a core
verb. Cutting it takes MVP from four abilities to three and buys back an entire half of the
loop.

## Decision, part two — what pays for it (2026-08-27)

**`ABIL-WHISPERBOLT` is deferred to post-MVP.** `SCOPE_FENCE.md` IN #4 reads three abilities,
OUT #18 carries the reasoning, and `US-0068` is re-milestoned rather than deleted.

**It was chosen on engineering cost, not on design merit**, and the argument is stronger than
the recommendation this ADR first made. Whisperbolt is not merely the largest of the four
abilities; it is the only one that needs **netcode this project does not have**:

- **A replicated moving entity.** Nothing in this game currently moves on the wire except
  pawns and NPCs, both of which are known, slotted and delta-encoded. A projectile is a third
  kind, and it is the only one whose lifetime is shorter than a second.
- **Hit validation at an impact 0.55 s after the press.** `RewindClamp` clamps to 100–200 ms
  of RTT at the moment of the *press*, which is the only moment lag compensation in this
  project has ever been asked about. **No rule anywhere says what a half-second-later impact
  resolves against** — the shooter's rewound world, the current world, or something between.
  That is an open netcode question wearing an ability's clothes.
- **Downstream bandwidth**, which sits at **105 %** of a budget missed since M2 (TDD-04
  §7.1.2). A new record type on an over-budget snapshot is a cost the other three do not have.

**And it is the cheapest cut to reverse, which is the property a good cut should have.** Once
`SYS-ABILITY` exists, restoring an ability is a `.tres` and a behaviour: every
`TUN-WHISPERBOLT-*` value, every `SFX-` and `ANIM-` ID, the `ABIL-` ID itself, invariant 11 and
GDD-04 §3.2's full specification stay exactly as written. Cutting the escape verb instead
would cost a rewrite of the contract system's assumptions across four documents — the
asymmetry is the whole reason this is the right way round.

### The two costs, stated rather than hidden

- **Loadout variety halves.** Two abilities of four with three passives is eighteen builds;
  two of three is nine. This is a real loss, and it is a **retention** property rather than a
  **loop** property — the fence's own test is *"is the loop fun with six humans"*, and no
  loadout answers that question. The reference runs two of eleven, so both numbers are far
  from it either way and the MVP was never going to match that shape.
- **Nothing in the MVP can reach a player on a roof.** GDD-04 §3.2 gives this as Whisperbolt's
  entire reason to exist — *"the answer to 'there is a player up there and I cannot get to
  them'"*. Lunge is 6 m and horizontal, Cinderfall is area denial, Second Face is identity. So
  after this cut the roof is priced **economically rather than mechanically**:
  `TUN-SUSPICION-GAIN-ROOF` +18/s holds a camper permanently Exposed, visible through geometry
  to their own hunter and prey, while they score nothing for sitting there. That was always
  true and it was never the *only* answer before. **Revisit if `TEL-TIME-BY-STRATUM` shows
  roof time rising**; the ability is deferred, not designed away.

### One candidate in `US-0097`'s table is now moot

That table offered deferring US-0054's two prop blends as an alternative. **They shipped on
2026-08-26**, so the option no longer exists — and it was already rejected as self-defeating,
since prop blends are exactly what a fleeing prey wants. Recorded because a decision table
with a dead row invites somebody to re-pick it.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Do nothing; escape stays out** | Zero cost. M4 closes sooner. | Leaves the single largest divergence from the reference standing, after an ADR that says the reference wins. Leaves the prey with one tooth, which was just blunted. | Rejected |
| **A Compass cooldown, not a reassignment** — the hunter keeps the contract but the Compass goes dark for N seconds | Cheapest possible. Touches no merged system. | It is a *pause*, not an escape. The hunt resumes, so a hunt still cannot be survived — the thing this ADR exists to fix is untouched. It is also not what the reference does. | Rejected |
| **Reassignment: the hunter loses the contract** | Faithful. Reuses `remove` + constrained insertion, both fuzzed. Makes the prey warning load-bearing. Gives the prey a non-violent win. | New scope. New tunables. A contract can now end without a death, which four documents assume it cannot. | **Taken** |
| **Swap two players' positions in the cycle** | Also cycle-preserving; disturbs fewer relationships. | Chooses a second victim arbitrarily to fix the first, and the swap partner is punished for something they were not part of. No source for it in the reference. | Rejected |

## Consequences

### Positive

- **A hunt becomes a two-sided exchange.** Both players can win it, and the prey's winning
  line is restraint — break the corner, then blend, then wait. That is the thesis, expressed
  as a verb rather than as a score multiplier.
- **`US-0059`'s prey warning becomes load-bearing.** The chase begins exactly when the warning
  fires, so the warning stops being feedback and becomes the opening of a mechanic.
- **The tier gate acquires a third consequence.** A hunter who stays Anonymous never starts a
  chase and therefore can never lose a contract to one. Carelessness now costs the contract
  itself, not merely a marker on the prey's ring.
- **It costs no additional raycasts.** The sight test asks about the hunter and their own
  contract — the same ordered pair the Compass lock already queries.

### Negative — stated honestly

- **A contract can end without a death, and four documents assume it cannot.** GDD-03 §7.3's
  repair table, TDD-10, the `Reason` enum and `NET-S2C-CONTRACT-ASSIGNED`'s `reason:u8` all
  enumerate deaths and arrivals. The enum gains a fifth value at index 4, which does not change
  the field's width or any existing value — but every reader of that table must be updated or
  an escape will report itself as a repair.
- **The prey is told something the design usually refuses.** A draining bar tells the prey
  *he cannot see me right now*, which is certainty about another player's perception. It is
  bounded by the tier gate — an Anonymous hunter starts no chase — and it is what makes the
  verb learnable, but it is a genuine addition to §11's information economy and it is the
  part most likely to need retuning.
- **It costs an MVP ability, and the ability is `ABIL-WHISPERBOLT`** (2026-08-27). MVP drops from four abilities to three and loadout variety halves; the roof stratum loses its only mechanical answer. See *Decision, part two*.
- **Two of the reference's escape bonuses can never fire here, by construction.** Its
  multi-escape bonuses require two and three simultaneous pursuers; a Hamiltonian cycle gives
  every player exactly one incoming edge, so no player is ever hunted by two. This is a
  divergence we keep: the cycle's single-pursuer guarantee is what makes the whole repair
  story sound (US-0049), and trading it for two bonuses would be a bad trade.

### Neutral / follow-on work required

- **Chase breakers are not in this ADR.** The reference's level furniture that delays a
  pursuer — a gate that drops, a cart that spills — is level design against `MAP-VETRAIO` and
  is recorded as owed in GDD-05, not built here.
- **`TUN-PURSUIT-*` values are proposed in `US-0097` and are not yet in `TUNABLES.md`.**
  Documenting them before they ship would fail `test_tunables_match_the_document.gd`, which
  compares the document against the shipped profile. They land with the implementation.

## Compliance

- `SCOPE_FENCE.md` IN #5 names escape, and the document's version is bumped.
- `ContractSystem.Reason` has a fifth value and `NET-S2C-CONTRACT-ASSIGNED`'s reason table in
  `NETWORK_PROTOCOL.md` lists five.
- The pursuit sight test spends no raycast that the Compass lock has not already spent:
  `test_los_single_query.gd` still finds exactly one query site under `systems/`, `net/` and
  `server/`, and it still asserts that the chokepoint casts.
- An escape reaches `ContractCycle` through the same `remove` and constrained insertion a
  respawn uses. A second insertion path would be a divergence in a fuzzed invariant.

## Revisit trigger

**`TEL-ESCAPE-RATE`.** If more than one hunt in three ends in an escape, the pursuit timer is
too long or the sight test too strict, and the hunter's Compass stops meaning anything. If
fewer than one in twenty does, the verb is decorative and the ability that paid for it should
come back.
