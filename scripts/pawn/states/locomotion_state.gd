## Shared behaviour for the six locomotion states. GDD-02 §2.2, §3.1.
##
## **DECELERATION IS FASTER THAN ACCELERATION**, 24 m/s² against 18. That is not
## a physics detail — it is the design thesis written into the acceleration
## curve. "Stop and blend" is never gated behind a ramp-down, while committing to
## speed always takes a moment. The defensive option is cheap; the aggressive one
## is not.
##
## Every subclass differs only in its target speed, its suspicion rate and which
## rung of the ladder it escalates to. The integration itself is here, once,
## because six copies of an acceleration curve is six places for them to diverge.
##
## STATELESS. Every value below is read from `Tuning` or written to `ctx`.
class_name LocomotionState
extends PawnState


## The speed this state drives toward. Overridden by every subclass; never a
## literal, always `MovementTuning`.
func target_speed() -> float:
	return 0.0


## What a traverse press resolves to, or `STAY`.
##
## **THE PRESS FINALLY DOES SOMETHING.** Checked before the speed ladder, because
## a player who asked to cross a wall has made a more specific request than
## "keep walking" — and because `TraversalResolver.resolve()` consumes the
## buffered input whether or not it finds anything, which must happen exactly
## once per press.
##
## Called from every locomotion state: GDD-02 §3's diagram draws `Loco --> Vault`
## against the group, not against any one rung, and a vault from a sprint is the
## same manoeuvre as a vault from a stroll.
func _traverse(ctx: PawnContext) -> StringName:
	return TraversalResolver.resolve(ctx)


## Where `INPUT-SLOW` and a released stick lead. ADR-0012: from EVERY locomotion
## state, in ONE tick, never gated, never delayed, never refused.
func _slow_or_stop(input: InputCommand) -> StringName:
	if input.slow:
		return PawnStateId.BLEND_WALK
	if not input.wants_movement():
		return PawnStateId.IDLE
	return STAY


## Integrate toward `target_speed()` and write the result to `ctx.velocity`.
##
## Backpedalling applies `TUN-SPEED-BACKPEDAL-MULT`: retreating from a hunter is
## possible but slow, because the correct defensive answer is to blend rather
## than to walk backwards away from someone faster than you.
func _integrate(ctx: PawnContext, input: InputCommand, delta: float) -> void:
	var desired := _world_direction(input)
	if desired.length_squared() > 1.0:
		desired = desired.normalized()
	desired *= _wanted_speed(input)

	var flat := Vector3(ctx.velocity.x, 0.0, ctx.velocity.z)
	# Slowing uses DECEL, speeding uses ACCEL. Which one applies is decided by
	# whether the target is slower than the current speed, not by the state:
	# a sprinting pawn that releases the stick decelerates on the same tick.
	var rate := Tuning.movement.decel if desired.length() < flat.length() else Tuning.movement.accel
	var stepped := flat.move_toward(desired, rate * delta)
	ctx.velocity = Vector3(stepped.x, ctx.velocity.y, stepped.z)


## How fast this state wants to be going, after every cap that applies.
##
## **DOWNWARD IS INSTANT, ON THIS TICK, IN THE BODY.** The state label changes
## via the transition the caller is about to apply, but the label is not what the
## player feels — if the ramp still aimed at sprint for one more tick, "slowing is
## never delayed" would be true of the state machine and false of the pawn.
## ADR-0012 and GDD-02 §2.2: the discrete names are for tuning and telemetry, the
## acceleration is smooth. Only downward; escalation stays gradual, because taking
## speed one rung at a time is what makes it a decision.
##
## **Crowd-scan caps the SPEED, never the STATE.** Routing it through the slow
## path would drop a scanning sprinter into BlendWalk, whose suspicion DECAYS, and
## a button that launders suspicion is exactly the mechanical advantage §4.3
## refuses to grant. Capped here it is a pure cost, never a discount.
func _wanted_speed(input: InputCommand) -> float:
	var wanted := target_speed()
	if input.slow or input.scan:
		wanted = minf(wanted, Tuning.movement.blend_walk)
	if not input.wants_movement():
		return 0.0
	if _is_backpedalling(input):
		wanted *= Tuning.movement.backpedal_mult
	return wanted


## **THE STICK IS READ IN THE CAMERA'S FRAME, NOT THE WORLD'S** — GDD-02 §2.
## `move` is an intention, and the world direction is it rotated onto the look
## yaw. It used to be `Vector3(move.x, 0, move.y)`, spending the stick on fixed
## world axes: A walked west, which at yaw 0 is the pawn's RIGHT.
##
## `input.look_yaw`, not `ctx.yaw`: the command is what a replay re-feeds, and
## `ctx.yaw` is written by the driver after this runs.
func _world_direction(input: InputCommand) -> Vector3:
	var yaw := input.look_yaw
	return ProbeLayout.right(yaw) * input.move.x + ProbeLayout.forward(yaw) * input.move.y


## True when the movement input points behind the pawn.
##
## In the INPUT's frame, which is now the only frame the stick has: the pawn
## faces the camera every tick (`LocalPawnDriver._apply_motion`), so "backwards"
## is simply S, at any heading. `TUN-SPEED-BACKPEDAL-MULT` existing at all is
## what says this controller strafes rather than turning to face its own travel.
func _is_backpedalling(input: InputCommand) -> bool:
	if not input.wants_movement():
		return false
	return input.move.normalized().y < -0.5
