## Run. GDD-02 §3.1: `INPUT-RUN` held past `TUN-SPEED-RUN-HOLD`.
##
## **THE COMMITMENT SPEED.** 32 % faster than jog and 3.5x the suspicion cost.
## The ratio is deliberately unfavourable so that running is a decision rather
## than a default — if the cost scaled with the speed, the ladder would be a
## slider and there would be nothing to decide.
class_name RunState
extends LocomotionState


func id() -> StringName:
	return PawnStateId.RUN


func target_speed() -> float:
	return Tuning.movement.run


func _ground_rate(_ctx: PawnContext) -> float:
	return Tuning.suspicion.gain_run


func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_run


func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
	_integrate(ctx, input, delta)
	var traversed := _traverse(ctx)
	if traversed != STAY:
		return traversed
	var slowed := _slow_or_stop(input)
	if slowed != STAY:
		return slowed
	if input.sprint:
		return PawnStateId.SPRINT
	if not input.run:
		return PawnStateId.JOG
	return STAY
