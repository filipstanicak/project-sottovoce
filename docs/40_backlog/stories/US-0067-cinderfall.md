---
id: US-0067
title: Ability — Cinderfall
version: 0.2.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-28
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY]
---

# US-0067 — Ability: Cinderfall

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY` |
| **Estimate** | M |
| **Depends on** | US-0066 |

## Description

Area denial: a thrown ash-pot that blocks line of sight and forbids kill initiation.

Exists to give a punished attacker exactly one escape.

## Acceptance criteria

- [x] 45 s cooldown, 0.45 s cast, 8 m throw range, 5 m radius, 4 s duration.
- [x] Blocks LOS for detection, lock progression and Focus accumulation.
- [x] Forbids kill INITIATION inside the radius FOR EVERYONE, INCLUDING THE CASTER.
- [x] A kill already in progress completes.
- [x] Applies +40 suspicion.
- [x] Startles NPCs within 9 m.
- [x] Registered with DetectionSystem as an LOS blocker and with KillSystem as an initiation
      blocker; deregistered on expiry.

## Test notes

`test_cinderfall_self_block.gd`, `test_cinderfall_blocks_los.gd`, `test_cinderfall_startle.gd`,
plus `test_kill_system.gd`'s `test_a_kill_already_in_progress_completes_inside_a_cloud`.

## What was actually built

**`CinderfallEffect` IS ELEVEN LINES, AND THAT IS THE STORY RATHER THAN A SHORTCUT.**
`CinderfallVolumes` was built at US-0056 and sharpened at US-0060; `DetectionSystem` has
consulted it in the project's one line-of-sight query since; `KillSystem` has refused initiation
inside one since US-0060; `AbilitySystem` has run the pipeline around it since US-0066. `add()`
was **the one entry point with nothing behind it** — the shape `CrowdAlarm.startle_at` had
through all of M3.

**THE 0.45 s CAST WAS NOBODY'S AND IS NOW THE PIPELINE'S.** `TUN-CINDERFALL-CAST-TIME` had no
reader: `AbilitySystem._commit` began the effect on the press tick. It is a wind-up now —
`LiveAbility` holds a cast that is *pending* until `begins_at` and *live* afterwards — and it
lives in the system rather than the effect because `AbilityData.cast_time` is *"used by:
Cinderfall, Secondface"*. TDD-09 §1's own sequence diagram has no cast phase and is amended.

**AND THE WIND-UP IS WHAT MAKES THE TELL WORTH SENDING.** The tell fires at the press and the
cloud lands 0.45 s later, so design law 3's *perceivable chance to react* is a measurable window
rather than a claim. **A caster killed during it drops no cloud** — the cooldown and the +40 are
spent and stay spent, so a victim who read the tell and acted on it is paid for reading it.

**A STUN DOES NOT CANCEL A CAST, AND THAT IS LEFT RATHER THAN DECIDED.** Nothing in GDD-04 gives
a stun that power; §3.1 names the counter to Cinderfall as **patience** — wait at the cloud's
edge. Adding one would change the ability's counterplay on my own judgement. **Open for the
owner**, and `AbilitySystem._end_all` is where it would go.

**THE STARTLE IS THE SYSTEM'S, NOT THE EFFECT'S.** `AbilityData.startle_radius` is Lunge's too,
so it sits beside the suspicion cost in the pipeline and leaves through `ability_startled`, which
`server_root` wires to `CrowdDirector.startle_at` — the same shape `SYS-KILL`'s consequences use.
An effect reaching `ctx.crowd` would put crowd knowledge in `scripts/systems/ability/` to express
a rule two abilities share.

**IT FIRES AT THE BURST AND IS CENTRED ON THE POT.** GDD-04 §3.1 lists the 0.45 s underarm throw
and the crack as **separate** tell channels, so the crowd scatters when the pot bursts, at the
place it burst. A wave at the caster's feet would announce them however far they threw, and would
delete the aggressive use the throw range exists for.

**`end()` MUST NOT REMOVE THE CLOUD, WHICH IS THE OPPOSITE OF WHAT "DEREGISTERED ON EXPIRY"
SOUNDS LIKE.** `CinderfallVolumes.expire` deliberately lags the burn-out by
`RewindClamp.max_ticks()`, because a kill is validated in the past and a cloud that was up when
the attacker pressed must still block that validation 100–200 ms later. An `end()` that cleared
the volume would delete exactly that window.

## Verified on a real server, not only against the system

`tools/ability_probe.tscn` boots `server_root.tscn`, joins a peer, presses slot 0 and prints what
happened. **The unit tests drive `AbilitySystem` directly and cannot see the wiring** — the
`ability_startled` connection, `cinderfall.tres` loading with its `effect_script`, the
placeholder loadout — and US-0074 lost a whole integration run to exactly that gap.

```
godot --headless --path . res://tools/ability_probe.tscn
```

Measured: `loadout [ABIL-CINDERFALL, ABIL-LUNGE]`, **0 clouds during the wind-up, 1 after it, 1
startle wave over 78 NPCs, suspicion 45.2 and 1 325 ticks of cooldown left.**

**And its first version read the wrong number.** It printed `SuspicionImpulses.pending` and got
`0.0` — which reads exactly like a cost that was never charged, and is in fact
`SYS-SUSPICION` having drained the queue at step 1 of its own pass one tick later. It reads
`PawnContext.suspicion` now: 45.2 is the +40 plus five seconds of standing alone on open ground.
**The probe found my expectation wrong, which is what a probe is for.**

## What the falsification run found

Four plants, three of them red immediately. **The fourth was green on a defect and that is the
finding.** Measuring the effect's deadline from the press rather than from the burst left
`test_the_duration_runs_from_the_burst_and_not_from_the_press` **passing**, because the cloud's
lifetime is `CinderfallVolumes`' own arithmetic and the test only asked about the cloud. The
effect and the volume keep **two clocks**, and the defect lives in the gap: the effect would be
dead for the last 0.45 s of its own cloud, which nothing about the cloud reveals.
`is_effect_active` is asserted there now.

## Two tests were passing for the wrong reason and one could never fail

- **`test_a_no_op_effect_ends_inside_the_tick_it_began` cast Cinderfall.** With a real effect
  behind it the assertion still read false — because a Cinderfall one tick after the press is
  *mid-wind-up*, which is a completely different fact. It casts `ABIL-LUNGE` now, whose
  `effect_script` is still null, and asserts that it is.
- **`test_a_refused_cast_announces_nothing` counted into a lambda-captured `int`.** GDScript
  captures a local **by value**, so `told += 1` inside the lambda incremented a copy and `told`
  was zero however many tells went out. The assertion could not fail. Found because the same
  shape failed in a test that expected *one* rather than *none*. Both count into an Array now,
  and a scan of `test/` found no third instance — the only other lambda counter mutates a class
  member, which is captured through `self`.
- **`AbilityEffect.tick` returning false nearly made the cloud inert.** The base returns false
  because *"return false to end early"* and a no-op's honest lifetime is one tick — which is
  right, and is why the first `CinderfallEffect` ended on the tick after it began. The first
  effect with a duration is the first that must override it. US-0066's note predicted this
  file would be the one to find out.

## And a green suite was running one file fewer than exists

**`CombatTargets.is_dead` takes a pawn; I called it with a context and a peer.** That is a parse
error, and GUT answers a parse error by **ignoring the whole file** —
`test/unit/systems/combat` printed *"All tests passed!"* over six scripts of seven, and the full
unit suite reported 1 463 passing tests across 174 of 175. The file it dropped was the one
holding this story's own new assertion, so the criterion it proves was **unproven under a green
run**.

Only `.ci/run_gut.sh`'s script count could see it — trap 10's family, and the **seventh** time
that check has paid. The engine's error is the *first* line of a 2 757-line run, which is why
the corpus's note about capturing a run to a file before grepping it applies to the **top** of
the file rather than the tail.

## Open

**Nothing in the criteria.** Two things named rather than done:

- **A stun during the wind-up does not cancel the cast.** Owner's call; see above.
- **Nothing draws the cloud.** There is no VFX pass and `AbilityData.tell_vfx` is null for every
  ability, so on a client the cloud is an absence of information rather than an object — the
  Compass stops pointing and the reticle stops offering, with nothing on screen to explain why.
  The wire message and the radius are already there for it.
