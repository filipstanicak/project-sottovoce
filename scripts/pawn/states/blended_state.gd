## Blended. GDD-02 §3.1 and §3.2 rule 3.
##
## **BLEND YIELDS TO EVERYTHING.** Being blended protects your ANONYMITY, never
## your BODY. A blended player can be killed, stunned or Whisperbolted normally.
##
## Blend is not cover, and the distinction is the whole mechanic: it buys you the
## chance not to be *identified*, which is worth more than being unkillable and
## costs the hunter attention rather than damage. A blend that also protected the
## body would make patience free instead of merely strongest.
class_name BlendedState
extends PawnState


func id() -> StringName:
	return PawnStateId.BLENDED


## Anything may take a blended pawn out of this state, at any priority, at any
## time. This is the only state that returns true unconditionally *and means it*.
func is_interruptible(_ctx: PawnContext) -> bool:
	return true


## The narrowest lens outside crowd-scan. GDD-02 §4.2's ladder names speeds, and
## blending is not one — but the narrow end of that ladder exists to make distant
## faces larger and more comparable, and standing still inside a group *looking at
## people* is the purest instance of that act in the game. A blended player framed
## at stroll would be given a wider view for holding still, which is the ladder
## backwards.
func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_blend


## Suspicion crushes toward zero over TUN-BLEND-CRUSH-TIME. Negative because the
## rate is added: blending is the one state that actively buys anonymity back.
func suspicion_rate(_ctx: PawnContext) -> float:
	var crush_seconds := Tuning.suspicion.blend_crush_time
	if crush_seconds <= 0.0:
		return 0.0
	return -Tuning.suspicion.max_value / crush_seconds


func step(ctx: PawnContext, input: InputCommand, _delta: float) -> StringName:
	if input.blend:
		return PawnStateId.IDLE
	if ctx.velocity.length() > Tuning.suspicion.break_on_speed:
		return PawnStateId.IDLE
	return STAY
