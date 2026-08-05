## Sprint. GDD-02 §3.1 and §1.5.
##
## **SPRINTING IS A COUNTDOWN, NOT A STATE.** 4.4x blend-walk, fast enough to
## catch a fleeing target across a plaza, and expensive enough that you reach
## Exposed in 2.8 s. The input is deliberately awkward — a double-tap or a hold
## past `TUN-SPEED-SPRINT-HOLD` — because a speed this loud must never be
## something you lean into by accident.
class_name SprintState
extends LocomotionState


func id() -> StringName:
	return PawnStateId.SPRINT


func target_speed() -> float:
	return Tuning.movement.sprint


func suspicion_rate(_ctx: PawnContext) -> float:
	return Tuning.suspicion.gain_sprint


func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_sprint


func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
	_integrate(ctx, input, delta)
	var traversed := _traverse(ctx)
	if traversed != STAY:
		return traversed
	var slowed := _slow_or_stop(input)
	if slowed != STAY:
		return slowed
	return STAY if input.sprint else PawnStateId.RUN
