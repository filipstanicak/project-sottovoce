## Jog. GDD-02 §3.1: `INPUT-RUN` held.
##
## **THE FIRST SPEED THAT COSTS ANONYMITY.** Priced so a short jog is a real
## option rather than a mistake — a player must be able to reposition under mild
## pressure without falling out of `SCORE-PATIENT`. That is why the gain is 4/s
## and not 14: the ladder has to have a rung you can afford.
class_name JogState
extends LocomotionState


func id() -> StringName:
	return PawnStateId.JOG


func target_speed() -> float:
	return Tuning.movement.jog


func suspicion_rate(_ctx: PawnContext) -> float:
	return Tuning.suspicion.gain_jog


func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_jog


func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
	_integrate(ctx, input, delta)
	var slowed := _slow_or_stop(input)
	if slowed != STAY:
		return slowed
	if not input.run:
		return PawnStateId.STROLL
	# Escalation is a HOLD, not a press. Counted in ticks because this decides a
	# suspicion rate, and an accumulated float would decide it differently on the
	# server than on the replay.
	if ctx.state_timer_ticks >= Tuning.ticks(&"TUN-SPEED-RUN-HOLD"):
		return PawnStateId.RUN
	return STAY
