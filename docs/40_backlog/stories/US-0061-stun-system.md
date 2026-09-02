---
id: US-0061
title: StunSystem, lockout and anti-spam
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-26
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-10-SCORING]
---

# US-0061 — StunSystem, lockout and anti-spam

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-COMBAT` |
| **Systems** | `SYS-STUN` |
| **Estimate** | M |
| **Depends on** | US-0060 |

## Description

The prey's counterplay: freeze the pursuer, exile them, and force them Exposed.

## Acceptance criteria

- [x] Valid ONLY against the stunner's own pursuer — found by reverse lookup on the
      **announced** contracts, so nobody may be stunned during the reassign breath for a hunt
      they have not been told about.
- [x] The pursuer must be at least Noticed — an ANONYMOUS pursuer is unstunnable at any range.
      Swept over five ranges from 0.5 m to 2.9 m, because one sample cannot tell a tier gate
      from a range gate that is tighter than the sample.
- [x] Range 3.0 m, which EXCEEDS kill range, asserted as an invariant — **and swept as a rule**,
      because the invariant compares two tunables and would pass over a `StunRules` reading the
      wrong field.
- [x] Facing cone 120 degrees — wide, because the player is turning in panic. Asserted as
      *wider than the kill's* rather than as a number.
- [x] Freeze 4.0 s, uninterruptible; the target loses camera control. `StunnedState` already
      held all three and had **no way to be entered** until now.
- [x] Contract lockout 12 s, reduced by the Second Wind passive. Per **(hunter, target)** pair:
      the exiled hunter may still hunt anybody else the cycle hands them, which is asserted.
- [x] Second Wind reduces LOCKOUT ONLY, never the freeze. *`PASV-SECONDWIND` has no reader —
      `NET-C2S-LOADOUT` is unbuilt — so the flag is an argument and is tested both ways, the
      same treatment `PASV-COLDREAD` and `PASV-STILLNESS` have.*
- [x] Target forced to maximum suspicion for the freeze duration. **The hold is
      `SuspicionSystem`'s** (US-0053) and what this story added is a way to reach the state it
      watches for; the join is asserted rather than assumed.
- [x] Stunning a non-pursuer: zero points, 2.0 s self-stagger, +20 suspicion, target UNAFFECTED.
      *"Zero points" is vacuous until `SYS-SCORE` exists (US-0064) — nothing appends a
      `ScoreEvent` yet, and this story deliberately fabricates none.*
- [x] A player mid-Lunge is stunnable for the entire wind-up and dash. **CLOSED 2026-09-02 by
      US-0070**, after four milestones blocked on there being no state to be mid-. The wind-up is
      spent in a locomotion state, which was always stunnable; `LungingState` is interruptible and
      is absent from `_is_stunnable`'s three exclusions. **Both halves are asserted rather than
      claimed**, because both are *absences* — and an absence is what a later reader deletes by
      accident. `test_stun_system.gd` names this criterion at each.
- [x] **A stun does NOT interrupt a committed kill.** ADR-0013: `KillAnimState` declines every
      COMBAT-priority request, so a stun landing after the hunter has pressed kill saves
      nobody. Built in US-0060; this story did not re-open it, and `KillSystem` still has no
      `report_interrupt` to call. **This story added the half US-0060 could not test**:
      `test_stun_system.gd` now drives a real stun at a committed hunter, from the prey's
      side, and asserts the kill still lands — and that the late press costs the prey
      nothing. *Ticked at the 2026-08-26 checkpoint; the criterion was true when US-0061
      merged and the scripted edit that ticked the other ten did not reach this one, which
      is trap 15's family in a checklist.*

## As built, 2026-08-26 — ten of eleven

**IT IS NOT A `GameSystem`, AND TDD-01 §4's DIAGRAM DECIDED THAT.** `MatchDirector` permits one
system per stage and box 7 of that diagram is a single node reading **"Kill / Stun"**, so
`StunSystem` is a plain object `KillSystem` owns and ticks — `SuspicionSystem`/`BlendSystem`'s
shape. A new `stun` stage was considered and rejected for the reason the blend stage was: it
would amend a normative diagram six documents reference, to express an ordering that diagram
already expresses. TDD-10 §7's interface is amended.

**THE KILL RESOLVES FIRST WITHIN A TICK, AND THAT IS WHERE ADR-0013 IS DECIDED.** A hunter and
their prey pressing on the *same* tick resolve for the hunter, because `KillSystem.tick` judges
its own presses and *then* calls the stun. That is the reference's contested initiation
expressed as **sequencing rather than as a comment**, and it makes GDD-03 §10.1.1's table true
at its narrowest moment.

**AND A STUN AT A COMMITTED HUNTER COSTS THE PREY NOTHING.** It returns `TARGET_COMMITTED`, with
no stagger and no suspicion: the press was correct and merely late, and charging for correct
play at the last instant is the shape of weakening stun that never-do #13 forbids. It is an
**explicit verdict rather than a failed transition**, because `KillAnimState` would decline the
state change silently while the exile still armed.

**THE `stun_ready` HINT NEEDED THE TIER GATE TOO, AND LEAVING IT OUT WAS AN ANONYMITY LEAK.**
The first version gated the hint on relationship, range and cone alone — so it would have lit
up for an **Anonymous** pursuer standing in a crowd, saying *that one is hunting you*, for free,
with no lock and no warning. Found by a test rather than by review. The bit has existed in
`Snapshot` since US-0029 and had no writer until now.

**EVERY REFUSAL COSTS THE SAME AND LOOKS THE SAME, WHICH IS A RULE AND NOT A SIMPLIFICATION.**
A refusal that reported its reason would turn the stun button into a **free identity probe** —
press it at a stranger and read whether the answer means *not your pursuer* or *your pursuer,
being careful*. So `StunVerdict.PENALISED` includes `TOO_CALM` and `NO_TARGET` as well as
`WRONG_TARGET`: §10.3's stated case is a non-pursuer, but its stated *reason* is that mashing
must never be optimal, and a press at empty air would otherwise be free.

**I NEARLY SHIPPED A STATE THAT CONTRADICTED A NORMATIVE TABLE.** `StunAnimState` first returned
`true` from `is_interruptible`, reasoned from ADR-0013 being "exactly one state wide". GDD-02
§3.1's interrupt column has read **"No below FATAL"** for `StunAnim` since M0. The table is
normative and the inference was not; both combat animations decline COMBAT and admit FATAL, and
they are symmetric rather than deliberately different.

**THE PUBLISHED BAND IS 2.5–3.0 m AND THE VALIDATED ONE IS 2.85–3.35 m.** Both rules add
`TUN-KILL-VALIDATION-GRACE`, so the window a player actually experiences is shifted — **and its
width is identical at 0.50 m, which is only true because the grace is shared.** A second grace
for the stun would be one that gets retuned alone, and the day it drifted below the kill's the
range advantage would quietly narrow. Asserted.

**AND THE LAG-COMP RING RETURNS THE *STALE* FRAME IF A TICK IS RECORDED TWICE.**
`LagCompHistory._frame_at` returns the **first** frame it finds for a tick, so a fixture that
placed a pawn, filled the ring, moved the pawn and filled again rewinds to where the pawn *used
to be* — and every geometry assertion in the file is then about the wrong position. It reads
exactly like a rule that does not work. Cost an hour; `_settle()` clears before refilling and
says why.

## Test notes

| File | Asserts |
|---|---|
| `test/unit/core/combat/test_stun_range_exceeds_kill.gd` | The two **rules** swept in centimetres, not the two tunables: no killable distance is outside stun reach. Plus the shared grace, the wider cone and the three-dimensional reach |
| `test/unit/core/combat/test_stun_reads_one_yaw.gd` | The pursuer's facing is irrelevant — **source-scanned**, because a behavioural test passes a rule that reads the yaw and happens to ignore it |
| `test/unit/core/combat/test_combat_lockouts.gd` | The exile binds one pair and no other hunt; both timers extend rather than shorten; a departing peer leaves nothing behind **in either direction** |
| `test/unit/core/combat/test_secondwind_freeze_unchanged.gd` | The passive shortens the exile to exactly §10.4's 8 s floor and cannot reach the freeze |
| `test/unit/systems/combat/test_stun_system.gd` | The gates, the freeze, the exile, the camera, the join with `SuspicionSystem`'s hold, and that a committed kill is not saved |
| `test/unit/systems/combat/test_stun_invalid.gd` | The anti-spam, and that **a careful pursuer and a stranger are indistinguishable** — the assertion that stops the button being an identity probe |

**Falsified against four planted defects**, each reddening the assertions it should and no
others: the tier gate defeated (five range assertions), `StunRules.reach` reading the kill's
range (the sweep, the band and the shared-grace check), `CombatLockouts.exile` made a no-op (the
exile and the kill refusal), and the `TARGET_COMMITTED` check removed (the same-tick contest).

## Notes

**RE-AUTHORED 2026-08-26 (ADR-0013).** One criterion added and nothing removed: the stun no
longer rescues a victim from a kill already in progress, because the reference resolves a
contested initiation for the killer. Everything else about stun is untouched and never-do #13
still forbids trading any of it away.

**Where the counterplay lives now.** In the approach, entirely. A revealed hunter is stunnable
from 3.0 m for the whole time they are closing, and they cannot strike until 2.5 m — so the
prey's window is the distance between those two numbers, every second of it, rather than a
reaction at the moment of commitment.

Stun range exceeding kill range is the most important geometric relationship in the game: a
hunter who closes to kill range has ALREADY entered stun range. Recklessness is punished by
geometry before it is punished by scoring.

Invalid-stun stagger exceeds the valid-stun animation, so flailing is strictly worse than doing
nothing. The strategy punishes itself with the thing it was trying to prevent.

If hunters find stun frustrating, the fix is to make the Anonymous approach more reliable. Never
weaken stun.
