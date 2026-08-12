## Climb. GDD-02 §3.1 and §6, TDD-06 §4.2 case 6.
##
## **THE ROOFS ARE A HIGHWAY WITH A TOLL BOOTH.** Climbing is priced per metre
## rather than per manoeuvre — `TUN-SPEED-CLIMB` 2.8 m/s against
## `TUN-SUSPICION-GAIN-CLIMB` 12/s is 4.3 suspicion for every metre gained — so a
## 9 m façade costs 38.6 and puts you at **Noticed** before you arrive.
##
## That is the design working, not a tax to be softened. §6.1: vertical movement
## costs, horizontal slow movement pays, and dropping down is free. The correct
## roof play is climb, cross, drop *immediately*, and let the crowd absorb you;
## the expensive mistake is lingering up there.
##
## **A CLIMB CAN BE ABANDONED.** Pull away from the wall and you let go, into a
## `Drop` from wherever you had reached. A commitment you cannot back out of
## would make every façade a gamble on what is over the top, and the game already
## asks the player to gamble on things they can actually see.
class_name ClimbState
extends PawnState


func id() -> StringName:
	return PawnStateId.CLIMB


## COMBAT and above, like a vault: you can be stunned off a wall, and being
## stunned mid-climb is one of the more legible things that can happen to you.
func interrupt_priority() -> int:
	return PRIORITY_NORMAL


func is_interruptible(_ctx: PawnContext) -> bool:
	return false


## The climb owns its position — it moves along the façade, not through physics.
func drives_position() -> bool:
	return true


## Per second, for as long as the climb lasts. The *arrival* is what really
## costs: standing on a roof is `TUN-SUSPICION-GAIN-ROOF`, half again as much.
func suspicion_rate(_ctx: PawnContext) -> float:
	return Tuning.suspicion.gain_climb


## GDD-02 §2.1 frames a climb at 62°, between stroll and run. It borrowed the
## Jog rung's 65° until that rung was deprecated; `TUN-CAM-FOV-CLIMB` promotes
## the documented number to an ID of its own rather than reaching for whichever
## neighbouring rung is closest.
func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_climb


func enter(ctx: PawnContext) -> void:
	super(ctx)
	ctx.velocity = Vector3.ZERO


func step(ctx: PawnContext, input: InputCommand, _delta: float) -> StringName:
	var ticks := duration_ticks(ctx)
	if ticks <= 0:
		return PawnStateId.IDLE

	if _is_letting_go(ctx, input):
		# Fall from exactly where you had reached. The plan for the drop is made
		# here rather than by the resolver, because no press asked for it.
		_plan_release(ctx)
		return PawnStateId.DROP

	if ctx.state_timer_ticks >= ticks:
		ctx.position = ctx.traverse_target
		ctx.velocity = Vector3.ZERO
		return PawnStateId.IDLE

	var t := float(ctx.state_timer_ticks) / float(ticks)
	ctx.position = ctx.traverse_start.lerp(ctx.traverse_target, t)
	return STAY


## Ticks to cover the plan's rise at `TUN-SPEED-CLIMB`.
##
## A SPEED, NOT A DURATION — which is what makes the cost proportional to the
## height. Fixing the duration would make a 9 m façade cost the same as a 3 m
## one, and the roof economy in §6.1 rests on it not doing that.
static func duration_ticks(ctx: PawnContext) -> int:
	var rise := absf(ctx.traverse_target.y - ctx.traverse_start.y)
	var speed := maxf(Tuning.movement.climb, 0.001)
	return maxi(int(round(rise / speed * Tuning.net.client_input_rate)), 1)


## Pulling away from the wall. Backwards input, in the stick's own frame — the
## same test `LocomotionState` uses to decide a backpedal.
##
## It compared the stick against `ctx.yaw` until the stick stopped being a world
## vector; on a wall faced from the south that made "back" mean *north*, so a
## player climbing east let go by pressing D. `move` is the player's intention
## now, and back is S at every heading.
static func _is_letting_go(_ctx: PawnContext, input: InputCommand) -> bool:
	if not input.wants_movement():
		return false
	return input.move.normalized().y < -0.5


## Turn the abandoned climb into a fall back to where the climb began.
##
## The climb's own start IS the ground: you were standing on it a moment ago.
## Reading it before overwriting the plan is the whole trick — the probes cannot
## help here, because a pawn halfway up a wall has nothing under its forward
## casts, and re-probing mid-climb would ask the geometry a question the player
## never posed.
static func _plan_release(ctx: PawnContext) -> void:
	var ground_y := ctx.traverse_start.y
	ctx.traverse_case = TraversalResolver.Case.DROP
	ctx.traverse_start = ctx.position
	ctx.traverse_peak_y = ctx.position.y
	ctx.traverse_target = Vector3(ctx.position.x, minf(ground_y, ctx.position.y), ctx.position.z)
