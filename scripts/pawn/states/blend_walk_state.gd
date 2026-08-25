## BlendWalk. GDD-02 §3.1: move plus `INPUT-SLOW`.
##
## **THE MOST IMPORTANT KEY IN THE GAME.** This speed must equal
## `TUN-CROWD-NPC-SPEED-STROLL` exactly — invariant §17.1, the single most
## important one in TUNABLES. A player moving at a different speed from the NPCs
## around them is readable from motion alone, and anonymity is dead regardless of
## what the suspicion meter says.
class_name BlendWalkState
extends LocomotionState


func id() -> StringName:
	return PawnStateId.BLEND_WALK


func target_speed() -> float:
	return Tuning.movement.blend_walk


func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_blend


func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
	_integrate(ctx, input, delta)
	var traversed := _traverse(ctx)
	if traversed != STAY:
		return traversed
	if not input.wants_movement():
		return PawnStateId.IDLE
	# Releasing slow returns to the default, not to whatever you were doing
	# before. Blend-walk is entered deliberately and left deliberately.
	return STAY if input.slow else PawnStateId.STROLL
