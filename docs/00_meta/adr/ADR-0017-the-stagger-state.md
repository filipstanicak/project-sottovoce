---
id: ADR-0017
title: The fifteenth pawn state — a failed action leaves you Staggered
version: 1.0.0
status: accepted
owner: Lead Game Designer
last_updated: 2026-09-01
depends_on: [ADR-0008, ADR-0013, GDD-02-PLAYER-CONTROLLER, GDD-04-ABILITIES, US-0060, US-0061, US-0070]
---

# ADR-0017 — The stagger state

## Context

**Three shipped tunables describe a state the machine does not have.** They have been in
`TUNABLES.md` since M0 and the corpus has carried the gap as an open owner decision since US-0060:

| Tunable | Value | What it says happens |
|---|---|---|
| `TUN-KILL-CONTEST-STAGGER` | 1.5 s | *"The loser of a contest is staggered. Not stunned: no points to anyone, no lockout. Losing a race should cost **tempo**, not the match."* |
| `TUN-STUN-INVALID-STAGGER` | 2.0 s | *"Stunning a non-pursuer… Longer than `TUN-STUN-ANIM-DURATION` so **flailing is strictly worse than doing nothing**."* |
| `TUN-LUNGE-WHIFF-STAGGER` | 1.2 s | *"Missing leaves you standing in the open, Noticed, **unable to act**."* |

**What is built instead is an initiation lockout** — `CombatLockouts.stagger`, a per-peer tick
deadline that blocks kill and stun presses. US-0060 chose it deliberately and recorded why: a
sixteenth state amends a normative diagram, and an initiation lockout expresses *"losing should
cost tempo, not the match"* without one.

**It does not express the other two.** A player serving a lockout can still walk, run, sprint,
vault, climb and blend. So "unable to act" is false, and "flailing is strictly worse than doing
nothing" is false too: a flailer who can immediately sprint out of the space has paid two seconds
of *buttons*, not two seconds of *exposure*.

**And `ABIL-LUNGE` cannot be built at all.** US-0070's fourth and fifth criteria are *"stunnable
for the entire wind-up and dash"* and *"a whiff costs a 1.2 s stagger in the open"*, and
`test_pawn_state_count.gd` compares `PawnStateId.ALL` against GDD-02 §3.1's normative table name
for name. A `Lunge` state fails that test and the "fix" would be to edit a normative design
document with no decision behind it — which is exactly what this file is for.

> **TDD-09 §5.1 says a new pawn state is not needed "because a dash already exists".**
> **No dash exists.** Trap 14's shape in a technical table: a claim that stops anybody checking.
> §5.1 is amended by this ADR.

## The argument that decides it, and it is not any of the three tunables

**A lockout has no tell, and a punishment nobody can see teaches nobody anything.**

`state_id` is on the wire in every remote pawn record. `CombatLockouts` is on nobody's wire at
all. So today, a prey who reads a Lunge, sidesteps it and watches the hunter whiff sees the hunter
**stand up and walk away normally**. The read was correct, the punishment landed, and the player
who earned it cannot perceive that it did.

Design law 3 is written about abilities — *no ability resolves without the victim having had a
perceivable chance to read it* — and the same principle runs the other way. GDD-02 §9's failure
mode 7 is *"kill feels unresponsive"*, and its shape is a player pressing a button the HUD
promised would work; **this is its mirror**: a player earning an advantage the world refuses to
show them.

That argument is stronger than the three tunables, because it is about what the **other** player
perceives, and the other player is the one whose skill the mechanic exists to reward.

## Reference fidelity

ADR-0013 makes the reference the arbiter where a rule here diverges. Two things were sourced
rather than recalled, and one of them is a finding rather than a confirmation.

**The reference family has a short recovery that is distinct from the stun.** In the sequel to the
reference title, a simultaneous kill-and-stun leaves the prey dead and the other party *"dazed for
a short while"* — a recovery separate from the full stun, and paired with its own scoring bonus.
So a brief, self-inflicted, non-stun recovery is faithful.

**And `TUN-KILL-CONTEST-STAGGER` models a mechanic the reference title itself does not have.**
The contested kill and its bonus are the *sequel's*, not the reference's. That is a divergence
ADR-0013's audit did not flag, and it is **reported here rather than acted on**: it is a merged
`TUN-` ID and a merged rule, and changing either is the owner's. Nothing in this ADR depends on
it — the state is needed by the other two tunables and by Lunge regardless.

**THE CITATIONS ARE NOT IN THIS FILE, AND THAT IS NEVER-DO #5 RATHER THAN AN OMISSION.**
Four sources were read before either paragraph above was written — a franchise wiki's perks
page, a strategy site's ability guide, and two press hands-on pieces about the sequel's
multiplayer. **Every one of them names the reference in its title, its URL or both**, so
reproducing them here would put the franchise name in the repository, which CI fails hard on.
This is ADR-0013's own handling: the full fidelity audit *"names the reference in every row and
therefore lives outside the repo, in the owner's design notes"*, and the same rule governs a
citation.

**THE LINKS WERE GIVEN TO THE OWNER IN CHAT AND BELONG IN THE DESIGN NOTES.** What is recorded
here is what the sources *said*, which is the part a future reader needs and the part that
carries no franchise term.

**AND THE FIRST VERSION OF THIS FILE GOT IT WRONG.** It carried four markdown links and
`ip-guard` refused the build — the guard working exactly as designed, on the one class of
mistake review here has never caught. Worth knowing before the next ADR needs a source: the
standing instruction to always cite an in-game reference and never-do #5 collide, and the
resolution is **chat and the owner's notes, never a file**.

## Decision

**GDD-02 §3's normative state machine gains `Staggered`.** Fourteen states become fifteen.

| Property | Value | Why |
|---|---|---|
| **Entry** | A committed action failed: a lost kill contest, a refused stun, and — when US-0070 lands — a whiffed Lunge | The three tunables above, and nothing else. It is never entered by input |
| **Exit** | `PawnContext.stagger_ticks` elapsed → `Idle` | `StunAnim`'s shape |
| **Interruptible?** | **Yes** | See below. This is the one property with a real argument on both sides |
| **Priority** | COMBAT | It is a combat outcome |
| **Camera** | **Kept** | `Stunned` is the only state that takes the camera and that must stay true — see below |
| **Suspicion** | none of its own | The action that caused it already charged (`TUN-STUN-INVALID-SUSPICION` +20, `TUN-LUNGE-SUSPICION` +40) |
| **Drives position?** | No | It does not move the pawn; it stops it, the way `KillAnim` does |

### It is interruptible, and that is never-do #13 rather than a preference

A state that declined a stun would be **narrowing what a stun can reach**. A whiffed lunger would
otherwise be in a locomotion state, which is stunnable; putting them somewhere stun cannot follow
would be a weakening dressed as an addition, and never-do #13 forbids weakening stun to make
hunting feel better.

It is also the whole payoff of the read. GDD-04 §3.4 names the counterplay to Lunge as **"stun
it"**, and a prey who dodges the dash and stuns the whiff converts a 1.2 s stagger into
`TUN-STUN-FREEZE` 4.0 s plus a 12 s exile. That is design law 5's teeth, on the one mechanic
built to bypass the approach phase.

**It is asymmetric with `StunAnim`, and the asymmetry is a rule rather than an accident: you are
protected while *doing* something, not while *paying* for having done it.** `KillAnim`,
`StunAnim` and `Stunned` all decline COMBAT — the first two because commitment is the mechanic,
the third because a re-stunnable player could be chain-locked out of the match by two opponents.
None of those is true of a 1.2–2.0 s recovery the staggered player caused themselves.

### It keeps the camera, and `Stunned` must remain the only state that does not

`StunnedState`'s own docstring: *"the teeth are not merely that the hunter stops moving: it is
that for the whole freeze they cannot even choose where to look while their target walks away."*
That is the stun's signature and nothing else may borrow it. A staggered player watches their prey
leave **and can look at them**, which is a materially smaller punishment and reads as one.

### It is `Staggered`, not `Dazed`, and the reference's own word lost

`Staggered` sits one letter's distance from `Stunned`, which is the transposition hazard this
corpus keeps finding. The reference's word — *dazed* — is more distinct and was rejected anyway,
because **three merged `TUN-*-STAGGER` ids name the thing** and a state whose name disagrees with
the tunables that cause it is the drift `GLOSSARY.md`'s one-term-one-meaning rule exists to
prevent.

The distinction a reader needs is one line, and it is in the state's docstring and in §3.1:
**`Stunned` is done to you by another player; `Staggered` is done to you by your own failed
action.**

### The duration lives on the context, and the client's copy is a ceiling rather than a prediction

Three causes, three durations, one state. `PawnContext.stagger_ticks` carries the total, written
by whichever system entered the state.

**All three entries are server knowledge** — whether a stun was valid, who won a contest, whether
a dash landed — so a client cannot predict entry, exactly as it cannot predict `Stunned` or
`Dead`. `Reconciler.forced` (US-0060) is what applies a server-forced state, and it exists.

What a client *can* get wrong is the **exit**, because the wire carries the elapsed timer and not
the total. So `PawnContext`'s default is the **longest of the three staggers**, derived rather
than chosen, and the consequence is stated rather than discovered: **a client's stagger can only
ever end late, never early.** The server's snapshot ends it. That is UI_UX_SPEC §3.3's own rule —
information *newer* than the simulation is forbidden, information older is fine — applied to a
state instead of to a HUD element.

**No new tunable.** A fourth number here could be set to a value the first three contradict; the
ceiling is `max` of the three that already exist.

### The lockout stays, and the two are not one rule written twice

`CombatLockouts.stagger` is **the rule**: may this player initiate? `Staggered` is **the tell and
the tempo**: what are they doing, and what can be done to them? They answer different questions,
they are written on adjacent lines at each of the two call sites, and a test asserts they are set
together. Deleting the lockout would mean both combat systems had to ask the pawn — which they
cannot do when there is no state machine, which is every unit fixture.

### `ALL`'s order is the wire, so the state is appended

`Snapshot.state_index` encodes `state_id` as an index into `PawnStateId.ALL`: *"appending is safe,
reordering silently remaps every remote pawn's animation to a different state."* `Staggered` is
appended to `ALL` and to §3.1's table, and `PawnStateId`'s docstring now says the order is the
protocol rather than that it is document order — which was true by coincidence and is the weaker
statement.

## What is NOT decided here

> **CLOSED 2026-09-02, AND THE RECOMMENDATION UNDERSTATED IT.** Both edges are in, and
> the defect was not cosmetic: `KillSystem._land` announced the kill whether or not the
> transition was legal, so the victim was scored, corpse-spawned and repaired around while
> `CombatTargets.is_dead` still answered **false**. What follows is the original text.

**The two missing `Dead` edges stay missing.** GDD-02 §3's diagram has no `Drop -> Dead` and no
`StunAnim -> Dead`, so a player killed while falling or mid-stun-swing cannot enter `Dead`;
`KillSystem._enter` reports it and the pawn keeps walking. `Staggered -> Dead` **is** added here,
because a stagger that could not be killed out of would be a bug in the state this ADR adds — but
the other two change whether a falling player can die, which is a separate design question with no
rule behind it either way.

**Recommendation: add both.** Nothing in the corpus argues a falling or swinging player should be
undeathable, `KillSystem` already wants to make the transition, and the current behaviour — the
death resolves while the pawn keeps walking — is worse than either answer.

## Consequences

- **`ABIL-LUNGE` (US-0070) is unblocked.** Its whiff has a state, and its `depends_on` no longer
  needs a decision that does not exist.
- **US-0071's `depends_on` clears**, which makes its three passives buildable; its other two
  criteria remain behind M6's lobby and countdown.
- **Three staggers stop being lockouts wearing a state's name.** A staggered player is stationary,
  visible as staggered to everybody who can see them, and stunnable.
- **Fifteen states, again.** The count was fifteen until the `Jog` rung was deprecated on
  2026-08-12; §3.1's *"Corrected 2026-08-05: fifteen, not fourteen"* note is now true a second
  time for a different reason, and says so.
- **One protocol index is consumed.** `Staggered` is index 14 and nothing may be inserted before
  it.
- **The reference's contested-kill divergence is on the record** and is the owner's to rule on.
