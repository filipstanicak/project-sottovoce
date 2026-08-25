## Run. GDD-02 §3.1: `INPUT-RUN` held past `TUN-SPEED-RUN-RESOLVE`.
##
## **THE COMMITMENT SPEED, AND THE FIRST RUNG THAT COSTS ANYTHING.** Twice
## stroll's speed for 14/s where stroll pays nothing — the ladder steps straight
## from free to expensive, with no cheap rung in between. That cliff is the whole
## economy: if the cost scaled smoothly with the speed the ladder would be a
## slider, and there would be nothing to decide.
##
## The Jog rung used to sit here at 3.4 m/s for 4/s. It was removed because
## `INPUT-RUN` producing a speed the player did not ask for is a worse cost than
## the one it was buying — the cheap way to reposition is Stroll, which is free.
class_name RunState
extends LocomotionState


func id() -> StringName:
	return PawnStateId.RUN


func target_speed() -> float:
	return Tuning.movement.run


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
		return PawnStateId.STROLL
	return STAY
