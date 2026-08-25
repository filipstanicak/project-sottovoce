## Stroll. GDD-02 §3.1: move, no modifier.
##
## The "purposeful civilian" speed and the one a good player travels at. Fast
## enough that crossing the map is not tedious, slow enough to stay suspicion-
## free — `TUN-SUSPICION-DECAY-SPEED-CEILING` sits exactly here (invariant §17.3),
## so stroll is the fastest speed at which the meter still falls.
class_name StrollState
extends LocomotionState


func id() -> StringName:
	return PawnStateId.STROLL


func target_speed() -> float:
	return Tuning.movement.stroll


func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
	_integrate(ctx, input, delta)
	var traversed := _traverse(ctx)
	if traversed != STAY:
		return traversed
	var slowed := _slow_or_stop(input)
	if slowed != STAY:
		return slowed
	return PawnStateId.RUN if input.run else STAY
