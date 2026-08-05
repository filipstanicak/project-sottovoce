## Idle. GDD-02 §3.1: no move input, grounded.
##
## Suspicion decays here. Standing still is the cheapest thing a player can do,
## and it has to stay that way — `PASV-STILLNESS` multiplies this decay, which
## only means anything if the base case is already free.
class_name IdleState
extends LocomotionState


func id() -> StringName:
	return PawnStateId.IDLE


func target_speed() -> float:
	return 0.0


func suspicion_rate(_ctx: PawnContext) -> float:
	return _decay_rate()


func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
	_integrate(ctx, input, delta)
	var traversed := _traverse(ctx)
	if traversed != STAY:
		return traversed
	if not input.wants_movement():
		return STAY
	# Default movement is STROLL, not blend-walk. Blend-walk is a deliberate act.
	return PawnStateId.BLEND_WALK if input.slow else PawnStateId.STROLL
