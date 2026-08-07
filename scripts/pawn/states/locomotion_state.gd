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
	#
	# Crowd-scan caps the SPEED, never the STATE — routing it through the slow
	# path would drop a scanning sprinter into BlendWalk, whose suspicion DECAYS,
	# and a button that launders suspicion is exactly the mechanical advantage
	# §4.3 refuses to grant. Capped here it is a pure cost, never a discount.
	if input.slow or input.scan:
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
	var facing := Vector2(sin(input.look_yaw), cos(input.look_yaw))
	return input.move.normalized().dot(facing) < -0.5


## Suspicion decays in the civilian states. Negative because the rate is added,
## and only meaningful below TUN-SUSPICION-DECAY-SPEED-CEILING — which is why
## Jog, Run and Sprint override this with a positive gain rather than scaling it.
func _decay_rate() -> float:
	return -Tuning.suspicion.decay_base


## What this state costs at ground level. Overridden by every subclass; the roof
## surcharge is added on top by `suspicion_rate()`, which subclasses do not touch.
func _ground_rate(_ctx: PawnContext) -> float:
	return _decay_rate()


## Height is ABSOLUTE, and that only works while the street stratum is flat at
## y = 0. MAP-VETRAIO is; a map with varying ground level needs real stratum data
## in `MapData`, and `TUN-SUSPICION-ROOF-HEIGHT` says so.
static func _on_roof_stratum(ctx: PawnContext) -> bool:
	return ctx.position.y >= Tuning.suspicion.roof_height


## **THE ROOF TOLL.** `TUN-SUSPICION-GAIN-ROOF` 18/s for being up there at all,
## "regardless of speed" (TUNABLES §3.2) — added to whatever the speed already
## costs rather than replacing it.
##
## **DECAY DOES NOT RUN ON A ROOF.** Netting the 8/s decay against the 18/s toll
## would reach Noticed in 3.0 s, and TUNABLES §3.2 says 1.7 s — which is 30/18,
## the toll alone. A roof is not somewhere you recover slowly; it is somewhere
## you do not recover. That is what makes §6.1's rule true: the roofs are for
## *crossing*, never for *waiting*, and the expensive mistake is lingering.
func suspicion_rate(ctx: PawnContext) -> float:
	var ground := _ground_rate(ctx)
	if not _on_roof_stratum(ctx):
		return ground
	return maxf(ground, 0.0) + Tuning.suspicion.gain_roof
