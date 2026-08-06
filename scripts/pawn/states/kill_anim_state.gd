## KillAnim. GDD-02 §3.1 and §3.2 rule 1.
##
## **A kill in progress can be stopped, but only before it lands.** Interruptible
## by a stun until `TUN-KILL-CORPSE-SPAWN-DELAY` — 0.9 s of the 1.4 s animation.
## After the contact frame the victim is dead and the remaining 0.5 s is
## follow-through, so interrupting it would un-kill someone.
##
## That is what makes a last-second stun a genuine save rather than a cosmetic
## one, and it is why the contact frame is a TUNABLE rather than an art decision:
## the whole value of Law 5 lives in the gap between 0.9 s and 1.4 s.
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


## Open until the contact frame, closed after. Compared in TICKS, never against
## an accumulated float — this decides whether a save landed, and a value that
## drifts between server and client decides it differently on each.
func is_interruptible(ctx: PawnContext) -> bool:
	return ctx.state_timer_ticks < Tuning.step_ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY")


func step(ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	if ctx.state_timer_ticks >= Tuning.step_ticks(&"TUN-KILL-ANIM-DURATION"):
		return PawnStateId.IDLE
	return STAY
