## Lunging — **the committed dash**. GDD-04 §3.4, US-0070, GDD-02 §3.1.
##
## `TUN-LUNGE-DISTANCE` 6.0 m at `TUN-LUNGE-SPEED` 9.0 m/s: 0.67 s of travel,
## faster than a sprint, and **the player steers none of it**.
##
## **IT IS A PAWN STATE AND NOT AN EFFECT WRITING A POSITION, BECAUSE 6 m OF
## UNPREDICTED MOVEMENT IS 6 m OF RUBBER-BAND.** `AbilityEffect` lives in
## `scripts/systems/`, which is stripped from every client export, so a dash
## driven from there would be corrected on all twenty of its ticks — 0.3 m per
## tick, continuously, on the most decisive action in the game. Prediction needs
## the movement to live here, where both peers run it.
##
## **AND THE DIRECTION IS `ctx.velocity`, WHICH IS WHY THERE IS NO NEW FIELD AND
## NO NEW WIRE ROW.** `SYS-ABILITY` sets the velocity to the clamped aim at the
## burst; the own-pawn block carries `own_velocity` as **full floats** precisely
## because it is what prediction reconciles against, and `own_state` and
## `own_state_timer` carry the rest. So a client forced into this state by a
## snapshot has everything it needs to predict the remainder — **which matters
## because `PredictedState.apply_to` assigns `state_id` directly and never runs
## `enter()`.** Anything captured on entry would be captured on the server alone.
##
## **A DASH DOES NOT DRIVE ITS OWN POSITION, AND THAT IS THE OPPOSITE CALL FROM
## `Vault`, `Climb` AND `Drop`.** Those own their position because they are
## planned arcs against geometry the probes **measured**; `PawnMotion` then skips
## `move_and_slide()` entirely for them. A Lunge is aimed at open ground nobody
## measured, so owning its position would send a player **through a wall** at
## 9 m/s. It sets a velocity and lets the physics body answer.
##
## **A GRAZED WALL DEFLECTS THE DASH RATHER THAN ENDING IT, AND THAT IS
## DELIBERATE.** `move_and_slide()` slides along a surface, and this state
## re-asserts the tuned speed along whatever direction survived — so a dash that
## clips a corner follows it. That is what every other movement state does with a
## wall, it lasts at most 0.67 s, and **no input touches it**, which is what
## US-0070's *"direction LOCKS at wind-up"* actually forbids. A **head-on** wall
## stops the pawn, and `step()` ends the dash rather than leaving it standing
## still at full commitment.
##
## **STUNNABLE FOR THE WHOLE OF IT** — `TUN-LUNGE-STUNNABLE`, US-0061's ninth
## criterion, and GDD-04 §3.4's *"a prepared defender ALWAYS beats a Lunge"*. That
## is satisfied by this state being **interruptible** and by
## `StunSystem._is_stunnable` never growing a case for it.
class_name LungingState
extends PawnState

## Below this fraction of the tuned speed the dash has been stopped by geometry
## rather than deflected by it. **Not zero**: a body pressed into a wall retains a
## little velocity from the slide, and a dash that ended only at exactly zero
## would leave the player standing at full commitment for the rest of the window.
const STALLED := 0.5


func id() -> StringName:
	return PawnStateId.LUNGING


## **A COMMITTED DASH STOPS DEAD, AND THE PROBE IS WHAT FOUND THAT IT DID NOT.**
## `tools/ability_probe.tscn` measured a live server at **7.27 m against a tuned
## 6.0** — the state held its forty ticks exactly, and the pawn then left at
## `TUN-LUNGE-SPEED` 9.0 m/s and **coasted** while `IdleState` decelerated it.
##
## `TUN-LUNGE-DISTANCE`'s own row says *"closes the 'they saw me and turned' gap
## **and nothing more**"*, and 21 % more is more. Worse, the extra metre is spent
## **after** the auto-kill has been judged, so it buys the lunger nothing and
## simply slides a whiffed one further into the open — while `Staggered` is
## supposed to leave them *standing* in it.
##
## **NO UNIT TEST COULD SEE THIS**, because they assert the state and its velocity
## and the overshoot is in the pawn's total displacement, measured after the state
## has ended. It took driving a real server.
##
## **`y` IS LEFT ALONE**: a dash off a ledge must still fall, and gravity is
## `PawnMotion`'s.
func exit(ctx: PawnContext) -> void:
	ctx.velocity = Vector3(0.0, ctx.velocity.y, 0.0)


func interrupt_priority() -> int:
	return PRIORITY_COMBAT


## **YES, AND IT IS THE STORY'S FOURTH CRITERION RATHER THAN A PREFERENCE.**
## *"STUNNABLE for the entire wind-up and dash"* — the wind-up is spent in a
## locomotion state and is trivially stunnable; this is the other half. A dash
## that declined a stun would hard-counter the defensive play the game is built
## on, which GDD-04 §3.4 names as inverting design law 5.
func is_interruptible(_ctx: PawnContext) -> bool:
	return true


## **THE ONE STATE THAT TAKES THE CAMERA IS `Stunned`, AND THIS IS NOT IT.** You
## chose to commit; you did not lose the right to look. What is taken is your
## *direction*, and that is the whole cost of the button.
func camera_controlled() -> bool:
	return true


## **THE WIDEST RUNG, BECAUSE THE LENS REPORTS SPEED AND THIS IS THE FASTEST THE
## PAWN EVER MOVES.** `TUN-LUNGE-SPEED` 9.0 m/s is above `TUN-SPEED-SPRINT`, so
## anything narrower would say the pawn had slowed down at the moment it did the
## opposite. The combat states sit at `fov_stroll` for the mirror-image reason —
## a player mid-kill is not moving — and this is the same rule, not an exception
## to it.
func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_sprint


## **NO.** See the class docstring: a planned traversal owns its position because
## the probes measured what it is traversing. Nothing measured this.
func drives_position() -> bool:
	return false


## **INPUT IS NOT READ, WHICH IS THE WHOLE MECHANIC.** GDD-04 §3.4: *"Direction is
## locked at wind-up; you cannot steer mid-dash."*
##
## **STEP TICKS, NOT NET TICKS** — trap 9. `state_timer_ticks` advances inside
## `step()` at the 60 Hz input rate, so the net-tick converter would halve the
## dash to 0.33 s and 3 m.
func step(ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	var speed := dash_speed()
	var flat := Vector3(ctx.velocity.x, 0.0, ctx.velocity.z)
	if speed <= 0.0 or flat.length() < speed * STALLED:
		# Stopped by geometry, or entered with no direction at all. Either way the
		# dash is over and `LungeEffect` reads that from the state rather than from
		# a second clock of its own.
		return PawnStateId.IDLE
	var held := flat.normalized() * speed
	# **`y` IS PRESERVED RATHER THAN ZEROED**, so a dash off a ledge still falls:
	# `PawnMotion` applies gravity to an ungrounded body and this state has no
	# opinion about the vertical.
	ctx.velocity = Vector3(held.x, ctx.velocity.y, held.z)
	# **A DASH DELIVERS 5.85 m OF A TUNED 6.0, AND THE 0.15 m IS THE COST OF
	# STOPPING DEAD.** `PawnStateMachine.step` increments the timer *before* this
	# runs, and on the call that ends the dash `exit()` zeroes the velocity before
	# `PawnMotion` moves anything — so the pawn moves on `dash_ticks() - 1` steps.
	# Measured on a live server at **5.85 m, reproducible to two decimals**, which
	# is exactly 39 × 0.15.
	#
	# **`>` WAS TRIED AND IS MUCH WORSE.** It delivers the full 6.0 m and makes the
	# state outlive `AbilityEffect`'s own window by one net tick — so `LungeEffect.end`
	# fires while the pawn is still `Lunging`, refuses to queue an arrival, and
	# **the entire resolution is silently dropped**: no kill, no whiff, no stagger.
	# The probe measured that too, ending in `Idle` where it should end `Staggered`.
	# US-0067's *two clocks and the defect lives in the gap*, created and then
	# reverted rather than shipped.
	#
	# **ONE CLOCK AND 2.5 % SHORT BEATS TWO CLOCKS AND EXACT**, and the shortfall
	# errs toward the ability being weaker, which is the safe direction for the one
	# verb designed to bypass the approach phase.
	if ctx.state_timer_ticks >= dash_ticks():
		return PawnStateId.IDLE
	return STAY


## `TUN-LUNGE-SPEED`, read from the ability rather than from a section — the dash
## is the ability's own number and `AbilityData` is where it lives.
static func dash_speed() -> float:
	var data := Tuning.ability_data(Ids.ABIL_LUNGE)
	return 0.0 if data == null else maxf(data.speed, 0.0)


## How long the dash lasts, in **step** ticks. **Derived from the distance and the
## speed, never stored** — `AbilityRules.duration_of`'s rule, and a fourth number
## here could be set to a value the first two contradict.
##
## **PUBLIC BECAUSE IT IS THE ANSWER WORTH TESTING.** A test that re-derived it
## would agree with a state that had drifted.
static func dash_ticks() -> int:
	var data := Tuning.ability_data(Ids.ABIL_LUNGE)
	if data == null:
		return 0
	return int(round(AbilityRules.duration_of(data) * Tuning.net.client_input_rate))
