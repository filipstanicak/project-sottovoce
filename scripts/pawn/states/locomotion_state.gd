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
	var wanted := target_speed()

	# DOWNWARD IS INSTANT, ON THIS TICK, IN THE BODY. The state label changes via
	# the transition the caller is about to apply, but the label is not what the
	# player feels — if the ramp still aimed at sprint for one more tick, "slowing
	# is never delayed" would be true of the state machine and false of the pawn.
	# ADR-0012, and GDD-02 §2.2: the discrete names are for tuning and telemetry,
	# the acceleration is smooth.
	#
	# Only DOWNWARD. Escalation stays gradual, because taking speed one rung at a
	# time is what makes it a decision.
	if input.slow:
		wanted = minf(wanted, Tuning.movement.blend_walk)
	if not input.wants_movement():
		wanted = 0.0

	if _is_backpedalling(input):
		wanted *= Tuning.movement.backpedal_mult

	var desired := Vector3(input.move.x, 0.0, input.move.y)
	if desired.length_squared() > 1.0:
		desired = desired.normalized()
	desired *= wanted

	var flat := Vector3(ctx.velocity.x, 0.0, ctx.velocity.z)
	# Slowing uses DECEL, speeding uses ACCEL. Which one applies is decided by
	# whether the target is slower than the current speed, not by the state:
	# a sprinting pawn that releases the stick decelerates on the same tick.
	var rate := Tuning.movement.decel if desired.length() < flat.length() else Tuning.movement.accel
	var stepped := flat.move_toward(desired, rate * delta)
	ctx.velocity = Vector3(stepped.x, ctx.velocity.y, stepped.z)


## True when the movement input points behind the pawn's facing.
func _is_backpedalling(input: InputCommand) -> bool:
	if not input.wants_movement():
		return false
	var facing := Vector2(sin(input.yaw), cos(input.yaw))
	return input.move.normalized().dot(facing) < -0.5


## Suspicion decays in the civilian states. Negative because the rate is added,
## and only meaningful below TUN-SUSPICION-DECAY-SPEED-CEILING — which is why
## Jog, Run and Sprint override this with a positive gain rather than scaling it.
func _decay_rate() -> float:
	return -Tuning.suspicion.decay_base
