## StunAnim — **you performing a stun**, not you being stunned. GDD-02 §3.1 and
## the §3 diagram's `Loco --> StunAnim` edge.
##
## **THE TWO ARE DISTINCT STATES AND CONFUSING THEM INVERTS THE MECHANIC.**
## `Stunned` is four seconds of helplessness with the camera taken away;
## this is `TUN-STUN-ANIM-DURATION` 0.7 s of commitment, keeping the camera,
## after which you are back in Idle. GDD-02 §3's own table says so, and it is the
## first thing to check if a stun ever appears to punish the wrong player.
##
## **UNINTERRUPTIBLE BELOW FATAL, WHICH IS GDD-02 §3.1's OWN COLUMN.** The first
## version of this state returned true, on the reasoning that ADR-0013's
## commitment exception was "exactly one state wide" — and that reasoning was
## about the *kill completing*, not about this state's interrupt column, which has
## read **"No below FATAL"** since M0. The table is normative; the inference was
## not. Both combat animations now decline COMBAT and admit FATAL, and they are
## symmetric rather than deliberately different.
##
## **THE CONSEQUENCE IS SMALLER THAN IT LOOKS.** A hunter who commits to a kill
## during the prey's 0.7 s swing still lands it — not because this state yields,
## but because the kill resolves at its own contact frame against a victim who is
## simply not in a state that refuses death.
##
## **AND UNTIL 2026-09-02 THIS STATE COULD NOT DIE AT ALL.** GDD-02 §3's diagram
## declared no `StunAnim -> Dead`, so a prey killed mid-swing was scored,
## corpse-spawned and repaired around while `CombatTargets.is_dead` still answered
## **false**. The edge exists now; `test_every_living_state_can_reach_dead` is what
## keeps it and every future state honest.
##
## Never-do #13 forbids weakening stun to make hunting feel better. Nothing here
## may grow a cancel, a shorter duration or a wider window without an ADR.
class_name StunAnimState
extends PawnState


func id() -> StringName:
	return PawnStateId.STUN_ANIM


func interrupt_priority() -> int:
	return PRIORITY_COMBAT


## Neutral, like `KillAnim` and `Stunned`. The lens says one thing — how fast you
## are moving — and spending it on violence would leave every future reader
## guessing which of the two a wide lens meant.
func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


## Never, below FATAL. GDD-02 §3.1's interrupt column, and never-do #13: nothing
## here may grow a cancel without an ADR.
func is_interruptible(_ctx: PawnContext) -> bool:
	return false


## **STEP TICKS, NOT NET TICKS.** `state_timer_ticks` advances inside `step()` at
## the 60 Hz input rate, so converting with `Tuning.ticks()` would halve the
## swing to 0.35 s — silently, because both are plausible integers. Trap 9, and
## `test_step_counters_use_step_ticks.gd` refuses the wrong converter here.
func step(ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	if ctx.state_timer_ticks >= Tuning.step_ticks(&"TUN-STUN-ANIM-DURATION"):
		return PawnStateId.IDLE
	return STAY
