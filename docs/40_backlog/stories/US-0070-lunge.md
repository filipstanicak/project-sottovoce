---
id: US-0070
title: Ability — Lunge
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-09-02
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY, ADR-0017]
---

# US-0070 — Ability: Lunge

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY` |
| **Estimate** | M |
| **Depends on** | US-0069 |

## Description

A six-metre committed dash that auto-initiates a kill on arrival.

The "I have been made, commit now" button.

## Acceptance criteria

- [x] 30 s cooldown, 0.25 s wind-up, 6 m at 9 m/s, +40 suspicion applied at wind-up.
      **`TUN-LUNGE-WINDUP` HAD NO READER AND THAT IS THIS STORY'S LARGEST FINDING** — see
      below. The dash length is `TUN-LUNGE-DISTANCE` over `TUN-LUNGE-SPEED`, **derived
      rather than stored**, so no third number can contradict the first two.
- [x] Direction LOCKS at wind-up — no steering mid-dash. `LungingState.step` does not read
      its `InputCommand` at all, asserted against a command fighting it at every rung of
      the speed ladder. **Geometry may still deflect a dash that grazes a wall**, which is
      what `move_and_slide` does for every state and is not steering.
- [x] Auto-initiates the kill only against the caster's own contract. **The effect decides
      none of that** — it queues an arrival and `SYS-KILL` judges it with `KillRules`, the
      announced contract, the cloud and the contest, exactly as it judges a press.
- [x] STUNNABLE for the entire wind-up and dash. **This also closes US-0061's ninth
      criterion, open since M4 for want of a state to be mid-.** The wind-up is spent in a
      locomotion state; the dash is interruptible and absent from
      `StunSystem._is_stunnable`'s exclusions. Both halves are asserted, because both are
      **absences** and an absence is what a later reader deletes by accident.
- [x] A whiff costs a 1.2 s stagger in the open. **UNBLOCKED 2026-09-01: `Staggered` exists** (ADR-0017), it is entered by writing `PawnContext.arm_stagger` and transitioning, and it is **interruptible** — which is what makes GDD-04 §3.4's *"stun it"* counterplay pay off, since a prey who dodges the dash converts 1.2 s into a 4 s freeze and a 12 s exile.
- [x] Startles NPCs within 7 m along the dash path. **One wave covers it and that is measured rather than claimed**: `TUN-LUNGE-STARTLE-RADIUS` 7.0 m against a `TUN-LUNGE-DISTANCE` 6.0 m dash reaches every point on the path from the destination, asserted at eleven samples along it so a retune of either tunable reddens rather than quietly opening a gap.

## Test notes

`test_lunge_stunnable.gd`, `test_lunge_unsteerable.gd`, `test_lunge_contract_only.gd`.

## What building it found

### `TUN-LUNGE-WINDUP` was in the resource and nothing read it

`AbilitySystem._cast_ticks` read `AbilityData.cast_time` alone, and its own docstring said
*"Lunge has no `cast_time` at all"* — **true of the field and false of the ability**.
`TUN-LUNGE-WINDUP` 0.25 s lives in `AbilityData.windup`, which had **no reader anywhere in
the project**.

**A Lunge would have burst on the press tick with no telegraph.** That deletes design law
3's *perceivable chance to read it* and with it this ability's entire counterplay: GDD-04
§3.4 prices it as *"0.92 s of telegraphed, unsteerable approach against a 0.7 s stun"*, and
without the wind-up it is 0.67 s and undodgeable. `ANIM-LUNGE-WINDUP` was authored against
the same 0.25 s and would have had nothing to play over.

**Trap 14's shape, and the comment is what stopped anybody checking.**
`AbilityRules.windup_of` is the reader now, and it takes whichever of the two fields an
ability populates — `AbilityRules.reach_of`'s own rule, in a second place. Whisperbolt's
`TUN-WHISPERBOLT-WINDUP` 1.00 s would have had the same problem.

### The dash needed a state, and the reason is prediction rather than tidiness

ADR-0017 left this question here and set the rule it had to follow. The answer is a state,
because **`AbilityEffect` lives in `scripts/systems/`, which is stripped from every client
export** — a dash driven from there is 6 m the client never predicted, corrected on all
twenty of its ticks at 0.3 m each, on the most decisive action in the game.

**And the locked direction is `ctx.velocity`, so there is no new field and no new wire
row.** `own_velocity` is already full floats in the own-pawn block precisely because it is
what prediction reconciles against. That matters more than it looks: **`PredictedState.apply_to`
assigns `state_id` directly and never runs `enter()`**, so anything captured on entry would
be captured on the server alone and a client forced into the state would dash in a
direction it invented.

**It does not drive its own position**, which is the opposite call from `Vault`, `Climb`
and `Drop`. Those own theirs because the probes *measured* what they traverse and
`PawnMotion` skips `move_and_slide()` for them entirely; a dash is aimed at open ground
nobody measured, so owning its position would send a player through a wall at 9 m/s.

### An arrival is a press the player did not have to make

The first version gave the auto-kill its own `_resolve_arrivals` and `_judge_arrival`,
duplicating the verdict, the contest claim and the ordering — the *rule implemented twice*
this project keeps finding. **The file-length guard is how it was noticed**: 448 lines.

It joins `_requests` with `ARRIVAL_ORDINAL` -1, which sorts it ahead of every press in the
tick. `KillContest` resolves by who committed first, and a Lunge committed 0.92 s ago.

**The one difference an arrival makes is what a refusal costs.** `_reject` charges
`TUN-SUSPICION-GAIN-FAILED-KILL` +30, right for somebody who pressed at nothing and wrong
for somebody who spent a 30 s cooldown, +40 suspicion and a 6 m telegraph to arrive a metre
short. GDD-04 §3.4 prices a miss at the whiff stagger and nothing else.

### Two rules were written twice, and the length guard found both

`_enter` was fourteen identical lines in `KillSystem` and `StunSystem`, including the same
warning text — `CombatEntry.into` is the one home. The rewind moved to `KillRewind` for the
same reason, and **the arch guard naming ADR-0010's two rewind call sites fired on it,
correctly.** Widening a filename allowlist is how a guard gets hollowed out, so the rule is
restated as *ownership*: exactly one class may hold a `KillRewind`, which is strictly
stronger than the list it replaced.

### And a fixture was wrong in a way worth keeping

`test_lunge_effect.gd` first ticked only the ability system, so the dash never ended and no
arrival was queued. **The fixture was wrong and the guard was right**: `LungingState` is
driven at the `pawn` stage, and `LungeEffect.end` queues only when the pawn came back to
locomotion. That is US-0067's *one clock, not two* lesson, and it is asserted deliberately
now rather than left as a fixture detail.

## What ADR-0017 settled, and what it deliberately did not

**The whiff has a state.** `Staggered` is the fifteenth, added 2026-09-01, and it is the
home for this story's fifth criterion.

**Whether the DASH needs one is still this story's question.** TDD-09 §5.1 used to answer
it — *"only Lunge needs a dash, which already exists"* — and no dash exists; that row is
amended and no longer answers it for you. What has to be decided here: a 6 m committed
displacement at 9 m/s **drives its own position**, which `PawnState.drives_position()`
exists for and which `Vault` and `Drop` already do. Overloading `Drop` was priced and
rejected in the corpus — US-0061's *"a player mid-Lunge is stunnable"* would then make
everybody mid-gap-jump stunnable, which is one state carrying two meanings.

**If it needs one, it is appended to `PawnStateId.ALL` and to GDD-02 §3.1, never
inserted.** That array's order is the wire (`Snapshot.state_index`); `Staggered` consumed
index 14 and `test_pawn_state_count.gd` refuses an insertion before it.

## Notes

A prepared defender ALWAYS beats a Lunge: 0.92 s of telegraphed, unsteerable approach against a
0.7 s stun with a 120 degree cone, and the +40 at wind-up guarantees the lunger is at least
Noticed, which satisfies the stun tier gate.

Sprint is deliberately awkward to enter because it is for PLANNED speed. Lunge is the answer to
UNPLANNED speed — one press, no timing, when your target has turned and you have one second to
decide whether to abandon the hunt or spend everything on it.

Watch TEL-KILLS-BY-METHOD. Above ~15 percent of kills means the approach phase is being
short-circuited.
