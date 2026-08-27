---
id: US-0099
title: Streak bonuses — the kill streak and the losing streak
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [ADR-0013, DOC-SCOPE-FENCE, GDD-07-BALANCE, US-0064]
---

# US-0099 — Streak bonuses

| | |
|---|---|
| **Milestone** | **post-MVP — needs an ADR and a payment before it can be scheduled** |
| **Epic** | `EPIC-SCORE` |
| **Systems** | `SYS-SCORE` |
| **Estimate** | M |
| **Depends on** | US-0064 (the `ScoreEvent` fold), US-0065 (the bonus table) |

## Description

A **kill streak** pays escalating bonuses for consecutive kills without dying. A **losing
streak** pays — or grants — for consecutive *lost contracts*. The reference has eight such
bonuses across two slots, and this corpus has none, no `SCORE-` ID reserved for one, and no
concept of a streak anywhere in the scoring fold.

Found by the fidelity re-audit on 2026-08-27. **It is the only wholly absent system that audit
found**: every other divergence was a rule we have and priced differently.

## Read this before scheduling it

**THIS IS NEW SCOPE AND IT IS NOT PAID FOR.** `SCOPE_FENCE.md` IN #5 reads *"scoring with every
bonus in the table"*, and streaks are not in the table. By the fence's own rule this needs an ADR
naming what is cut to pay for it — and the last one of those, `ADR-0014`, cost an MVP ability.
**There is nothing obvious left to cut.** So this is filed post-MVP rather than proposed for M5,
and the story exists so the finding is not lost, not so the work is queued.

**The mechanic and the unlock are separable, and only one of them is blocked.** In the reference
the two streak slots are earned by levelling, which is progression — `SCOPE_FENCE.md` OUT #2, out
for reasons that have nothing to do with streaks (accounts, a backend, and unlocks masking whether
the base loop is fun). **A streak system with a single fixed set available to everyone needs none
of that.** If this is ever pulled in, pull in the mechanic and leave the unlock out.

## Why the losing streak is the interesting half

The kill streak is ordinary: it pays a player who is already winning, which is the shape most
games use and the shape this design has the least need of.

**The losing streak is the one worth having.** It pays a player who keeps *losing contracts* —
being killed, or having their prey escape once `US-0097` lands. Three things recommend it here:

1. **It is a comeback mechanic in a game with no other one.** An 8-minute free-for-all decided by
   score has nothing that helps a player having a bad match, and a player who is losing badly at
   minute three has five minutes of knowing it.
2. **It pays the archetype the balance model says is underpaid.** GDD-07 §4.5 puts the Defender at
   1 823 against the Patient's 3 871. Escape (US-0097) is the mechanical half of that fix; a
   losing streak is the economic half.
3. **It rewards the thing this design is about.** A player losing contracts is a player being
   hunted successfully, and being hunted is the half of the loop the whole emotional design is
   tuned around — GDD-03 §8.3's asymmetry, and playtest Q4 rating above Q5.

**And it must not become a reward for dying.** That is the failure mode and it is the reason this
story is not a one-liner: a bonus paid for losing is a bonus a player can farm by standing still
in the open. The reference's own answer is that its loss-streak bonuses grant *utility* — a
cooldown reset — rather than points. **Utility rather than score is the shape to copy**, and it is
the single most important design constraint in this story.

## Acceptance criteria

- [ ] A `SCORE-` or `PASV-`-adjacent ID grammar exists for streaks, agreed in `NAMING_AND_IDS.md`
      before any is minted. **`SCORE-` may be the wrong prefix** if the losing streak grants
      utility rather than points, and picking the prefix first is how an ID becomes immutable in
      the wrong namespace.
- [ ] A kill streak counts consecutive kills without a death, resets on death, and is server-side.
- [ ] A losing streak counts consecutive **lost contracts** — deaths, and escapes once US-0097
      lands — and resets on a kill.
- [ ] **No losing-streak reward is points.** Each is utility, and each is checked against the
      question *"can a player farm this by dying on purpose?"* with the answer written down.
- [ ] `TEL-SUICIDE-SUSPECTED` fires and is watched during the first playtest that has streaks.
      That event already exists in GDD-07 §8 and has no emitter (US-0080); this story is the
      first thing that would give it a reason to.
- [ ] Every streak value is a `TUN-` in `TUNABLES.md`, and the ladder has a cross-field invariant
      the way the stealth ladder does — invariant 32's shape, so a flattened streak ladder cannot
      ship green.
- [ ] The scoring fold stays pure: streak state is folded from the `ScoreEvent` log (ADR-0004),
      never accumulated in a system as it goes, so a match can be re-folded against new tuning.

## Test notes

**The counterfactual first.** A test that a three-kill streak pays more than a two-kill streak
passes just as happily against a ladder where every rung pays the same, provided the values happen
to ascend. The primary assertion is the **reset**: a streak that never resets is a score multiplier
with a misleading name, and the reset is the only thing that makes it a *streak*.

**And the losing streak needs a farming test, not a correctness test.** Model a player who dies
deliberately every five seconds for a match and assert their score does not exceed a player who
plays normally. That is the assertion this story is actually about.

## Notes

**Do not mint any ID until the ADR is written.** IDs are immutable once merged
(`NAMING_AND_IDS.md`), and this story's whole open question is which namespace they belong in.
Recording the finding costs nothing; recording it *with IDs* would spend something that cannot be
unspent.
