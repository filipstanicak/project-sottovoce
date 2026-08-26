## KillAnim. GDD-02 §3.1 and §3.2 rule 1.
##
## **A KILL IN PROGRESS CANNOT BE STOPPED BY THE VICTIM.** Amended 2026-08-26,
## ADR-0013. The reference resolves a contested initiation for the **killer**, so
## a stun landing after the hunter has committed does nothing for the prey.
##
## This state therefore declines every COMBAT-priority interruption. **FATAL still
## gets through** — `PawnStateMachine.transition` compares the requesting priority
## against this state's own, and `PRIORITY_FATAL` exceeds `PRIORITY_COMBAT` — which
## is the third-party kill the §3 diagram already draws as
## `KillAnim --> Dead: killed (contested loss to a third party)`.
##
## **`TUN-KILL-CORPSE-SPAWN-DELAY` IS STILL A TUNABLE AND STILL MEANS THE CONTACT
## FRAME.** It decides when the victim dies, when the corpse appears and when the
## crowd startles. It simply no longer decides whether a stun arrived in time — so
## the gap between 0.9 s and 1.4 s is now follow-through and nothing else.
class_name KillAnimState
extends PawnState


func id() -> StringName:
	return PawnStateId.KILL_ANIM


func interrupt_priority() -> int:
	return PRIORITY_COMBAT


## Neutral, and deliberately so. The lens says ONE thing — how fast you are
## moving — and a player mid-kill already knows what they are doing. Widening
## here would spend the channel on information the actor has and the victim
## cannot see, and would leave every future reader guessing whether a wide lens
## meant speed or violence.
func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


## Never. The commitment is the mechanic, and it is now total.
##
## **THE TICK COMPARISON THAT USED TO LIVE HERE IS GONE, NOT RELAXED.** It read
## `state_timer_ticks < step_ticks(TUN-KILL-CORPSE-SPAWN-DELAY)` and was the one
## place in the pawn where a save was decided. Leaving it as an always-false
## expression would keep a dead comparison in code that is replayed during
## prediction reconciliation, and would leave the next reader wondering which of
## the two rules was live.
func is_interruptible(_ctx: PawnContext) -> bool:
	return false


func step(ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	if ctx.state_timer_ticks >= Tuning.step_ticks(&"TUN-KILL-ANIM-DURATION"):
		return PawnStateId.IDLE
	return STAY
