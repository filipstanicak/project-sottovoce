---
id: US-0065
title: All twelve scoring bonuses
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-28
depends_on: [GDD-07-BALANCE, TDD-10-SCORING, TUN-BALANCE-MODEL]
---

# US-0065 — All twelve scoring bonuses

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-SCORING` |
| **Systems** | `SYS-SCORE` |
| **Estimate** | **L** |
| **Depends on** | US-0064 |

## Description

Every bonus condition, evaluated at kill INITIATION, plus the two windows that need real buffers.

## Acceptance criteria

- [x] All twelve implemented: Contract, Silent, Patient, Masked, Focus, From Above, Blended, Poisoned, Long Hunt, Vendetta, Variety, Reckless. Plus Stun.
      **Thirteen: `SCORE-HALFSEEN` was added on 2026-08-27, after this story was
      written.** The suspicion ladder is now a partition — exactly one of Silent,
      Halfseen and Reckless fires on every kill, asserted rather than assumed.
      **Two are dormant and for different reasons**: Poisoned by design (ASM-0016,
      below) and **Masked because there is no `AbilitySystem` to ask** —
      `ABIL-SECONDFACE` is US-0069. Both are rules with tests and no source; the
      day either arrives it is one assignment in `KillScoring.facts_at`.
      **`SCORE-ESCAPE` and `SCORE-CLOSECALL` are not here and should not be**:
      GDD-07 §3 says they are the only two rows not evaluated at a kill, and they
      are US-0097's.
- [x] All evaluated at initiation, not at resolution.
      `KillSystem._begin` captures a `KillScoreFacts` onto its pending row and
      `_resolve_contact_frames` pays it 0.9 s later. **Both directions are
      asserted**: a hunter who was Anonymous when they pressed keeps Silent through
      an animation they cannot cancel, and one who pressed while Exposed cannot
      launder it by standing still afterwards.
- [x] Patient uses a 300-tick speed-history ring — one tick above `TUN-SCORE-PATIENT-SPEED` anywhere in the window denies it.
      **On `MatchContext`, not on `PawnContext` — TDD-10 §2.1 is amended.** That
      object is replayed during prediction reconciliation, so a client replaying
      twenty commands would push twenty duplicate samples into a gameplay buffer.
      **A window that has not filled yet reads as clean, deliberately**: "never
      exceeded the speed in the 10 s before initiation" is true of a player who has
      only existed for three of them.
- [x] Focus tolerates a 0.4 s LOS lapse without resetting the streak.
      The grace **preserves** the streak rather than pausing it, and re-arms on
      every seen tick — otherwise it is a budget for the whole streak and Focus
      becomes unearnable after the second NPC walks past. **It rides `can_lock`,
      which diverges from TDD-10 §2's literal "unbroken LOS"** and is recorded
      there: it asks for unbroken *watching*, costs zero extra raycasts, and closes
      US-0056's last open criterion.
- [x] Long Hunt measures from contract assignment OR first lock, whichever is later.
      A max, not an overwrite — a lock completed on the *previous* contract must
      not lengthen a hunt that has not started. **Two rungs under one id, and the
      upper replaces the lower**: GDD-07 §3 prices the +100 step as compensation
      for 25 seconds of foregone scoring, so paying 50 + 150 would compensate twice.
- [x] Variety counts types earned for the first time this life, excluding itself, Contract and Reckless.
      Computed at append time in `ScoreLog`, because it counts against the events
      already in the log. **Paid as one event of `variety × n`**, since the feed
      draws a kill as one line. **`SCORE-HALFSEEN` is not excluded and ASM-0017
      predates it** — reported rather than decided.
- [x] Poisoned is implemented and tested but DORMANT — no MVP ability triggers it.
- [x] Death awards and deducts ZERO points.
- [x] Stun scores **more** than one base kill, asserted as an invariant.
      `TUN-SCORE-STUN > TUN-SCORE-CONTRACT`, and the rule reads the pin rather
      than a number of its own. Paid from `server_root`, because a stun landing is
      a consequence and `StunSystem` decides nothing about scoring.
      **AMENDED 2026-09-04. This line read `==` and *exactly one base kill*, which
      ADR-0018 falsified on 2026-09-03 by taking `TUN-SCORE-STUN` 100 → 200 and
      invariant 19 from `==` to `>`.** It stays **ticked**, and the distinction is
      worth stating: what the criterion asserts about the *code* is still exactly
      true — the rule reads the pin rather than a literal, which is precisely why
      the value could move without `server_root` changing. Only its arithmetic went
      stale. Unticking it would claim an implementation regressed when what
      happened is that a number was re-priced.

## Test notes

`test_patient_window.gd`, `test_focus_grace.gd`, `test_hunt_and_vendetta.gd`, `test_score_bonuses.gd` (which carries `test_death_zero_points.gd`'s property, because dying paying nothing is one row of GDD-07 §3 rather than a file), `test_variety.gd`, and `test_bonuses_are_judged_at_initiation.gd` for the half no pure test can reach. **`gdlint` forced the first split**: one file held all four windows and passed twenty public methods, which pushed it back to this story's own naming.

## What this story does NOT do

**`SYS-SCORE` is not a `GameSystem`, for the fourth time and a fourth reason.**
Every bonus is judged at kill *initiation*, which is `SystemOrder`'s `combat`
stage; a system at the `score` stage would answer every question one tick late.
The two windows are sampled by `SYS-SUSPICION` (stage 4, which already reads
horizontal speed) and `SYS-DETECTION` (stage 5, which already asks the Compass
lock's sight question), so both ride passes that exist and the `score` stage stays
empty.

**Nothing draws a score.** US-0074 is the feed and US-0077 the results screen.

**`kill_system.gd` reached 400 lines** (never-do #6) and the reticle hint moved to
`KillReadiness`. The seam is real: judging a press is the server's authority over
an outcome; answering *would it land* is a hint on one player's own screen.
`KillSystem.ready_for` stays as a one-line door, because four combat tests already
knock on it.

## Notes

Focus without the grace window is UNEARNABLE in a crowd — which is exactly where it should be
earned.

Known finding carried from BALANCE_MODEL section 4: at ~1.0 kills per life, Variety behaves as a
flat +50 per bonus type rather than a variety reward. It is ratio-neutral, so this is a
truth-in-naming problem. The fix — reset on contract instead of on death — is one line and
changes no tuning value. Gated on TEL-KILLS-PER-LIFE; do not apply it blind.
