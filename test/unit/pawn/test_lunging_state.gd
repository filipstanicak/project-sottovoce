## **THE COMMITTED DASH.** US-0070, GDD-04 §3.4, GDD-02 §3.1.
##
## **THE PROPERTY THAT MATTERS IS NOT THE DISTANCE.** A test that a dash covers
## 6 m passes just as happily against one the player can steer, which is the thing
## GDD-04 §3.4 spends its counterplay paragraph on: *"0.92 s of telegraphed,
## unsteerable approach"*. So the assertions worth their space are that **input
## changes nothing**, that a **stun can reach it**, and that it does **not** own
## its own position — because a dash that did would travel through a wall.
extends GutTest

var _machine: PawnStateMachine
var _ctx: PawnContext


func before_each() -> void:
	_machine = PawnStateMachine.new()
	add_child_autofree(_machine)
	_ctx = PawnContext.new()
	_ctx.peer_id = 7
	_ctx.reset_for_spawn(Vector3.ZERO, 0.0)
	_machine.spawn_into(_ctx, PawnStateId.IDLE)


## Enter the dash the way `LungeEffect` does: set the velocity to the locked
## direction at the tuned speed, then transition.
func _dash(direction := Vector3(0.0, 0.0, 1.0)) -> void:
	_ctx.velocity = direction.normalized() * LungingState.dash_speed()
	_machine.transition(_ctx, PawnStateId.LUNGING, PawnState.PRIORITY_COMBAT)
	_ctx.state_timer_ticks = 0


func _step(times: int, command: InputCommand = null) -> void:
	var input := command if command != null else InputCommand.new()
	for _i: int in times:
		_machine.step(_ctx, input, 1.0 / Tuning.net.client_input_rate)


# --- the premise ----------------------------------------------------------


func test_the_state_is_registered_and_reachable() -> void:
	# Guards the guard: a machine that refused the transition would leave the pawn
	# in `Idle`, and `Idle` satisfies "did not steer" perfectly.
	assert_true(_machine.has_state(PawnStateId.LUNGING), "Lunging was never registered")
	_dash()
	assert_eq(_ctx.state_id, PawnStateId.LUNGING, "the pawn did not enter the dash")


func test_the_tuned_numbers_are_present() -> void:
	# Every assertion below divides by these; a zero would make the file vacuous.
	assert_gt(LungingState.dash_speed(), 0.0, "TUN-LUNGE-SPEED read as nothing")
	assert_gt(LungingState.dash_ticks(), 1, "the dash converted to no ticks worth having")


# --- the duration, and it is derived --------------------------------------


## **`TUN-LUNGE-DISTANCE` OVER `TUN-LUNGE-SPEED`, NEVER A STORED THIRD NUMBER.**
## ANIMATION_SPEC §3.3 calls `ANIM-LUNGE-DASH`'s 0.67 s *derived* for the same
## reason, and a `duration` row in `lunge.tres` could be set to a value the first
## two contradict.
func test_the_dash_lasts_its_distance_over_its_speed() -> void:
	var data := Tuning.ability_data(Ids.ABIL_LUNGE)
	var expected := int(round(data.distance / data.speed * Tuning.net.client_input_rate))
	assert_eq(LungingState.dash_ticks(), expected, "the dash length stopped being derived")
	_dash()
	_step(LungingState.dash_ticks() - 1)
	assert_eq(_ctx.state_id, PawnStateId.LUNGING, "the dash ended early")
	_step(1)
	assert_eq(_ctx.state_id, PawnStateId.IDLE, "the dash never ended")


## **STEP TICKS, NOT NET TICKS** — trap 9. The counter advances inside `step()` at
## the 60 Hz input rate, so the net-tick converter would halve the dash to 0.33 s
## and 3 m, silently, because both are plausible integers.
func test_the_dash_runs_on_the_input_clock_and_not_the_net_clock() -> void:
	var net_domain := int(round(6.0 / 9.0 * Tuning.net.server_tick))
	assert_gt(LungingState.dash_ticks(), net_domain, "the two tick domains stopped differing")
	_dash()
	_step(net_domain)
	assert_eq(_ctx.state_id, PawnStateId.LUNGING, "the dash ran on the 30 Hz clock")


## The speed is held every step rather than set once, so friction and the
## write-back in `PawnMotion` cannot bleed it away over twenty ticks.
func test_the_speed_is_held_for_the_whole_dash() -> void:
	_dash()
	_step(LungingState.dash_ticks() / 2)
	var flat := Vector3(_ctx.velocity.x, 0.0, _ctx.velocity.z)
	assert_almost_eq(flat.length(), LungingState.dash_speed(), 0.01, "the dash lost its speed")


# --- the mechanic ---------------------------------------------------------


## **NO STEERING, WHICH IS THE WHOLE BUTTON.** GDD-04 §3.4: *"Direction is locked
## at wind-up; you cannot steer mid-dash."* Held hard against a command asking for
## the opposite direction at every rung of the speed ladder.
func test_input_cannot_steer_the_dash() -> void:
	_dash(Vector3(0.0, 0.0, 1.0))
	var fighting := InputCommand.new()
	fighting.move = Vector2(1.0, -1.0)
	fighting.look_yaw = PI
	fighting.buttons = InputBits.RUN | InputBits.SPRINT | InputBits.SLOW
	_step(LungingState.dash_ticks() / 2, fighting)
	var flat := Vector3(_ctx.velocity.x, 0.0, _ctx.velocity.z).normalized()
	assert_almost_eq(flat.z, 1.0, 0.001, "the player steered the dash")
	assert_almost_eq(flat.x, 0.0, 0.001, "the player steered the dash")
	assert_eq(_ctx.state_id, PawnStateId.LUNGING, "input ended the dash")


## **US-0070's FOURTH CRITERION AND US-0061's NINTH**, and the way it stays true
## is that `StunSystem._is_stunnable` never grows a case for this state and this
## state never declines a COMBAT interruption. A dash that could not be stunned
## would hard-counter the defensive play the game is built on.
func test_a_dash_can_be_stunned_out_of() -> void:
	_dash()
	_step(2)
	assert_true(
		_machine.transition(_ctx, PawnStateId.STUNNED, PawnState.PRIORITY_COMBAT),
		"a stun could not reach a lunging player"
	)
	assert_eq(_ctx.state_id, PawnStateId.STUNNED)


func test_a_dash_can_be_killed_out_of() -> void:
	_dash()
	assert_true(
		_machine.transition(_ctx, PawnStateId.DEAD, PawnState.PRIORITY_FATAL),
		"a lunging player could not be killed"
	)


## **THE OPPOSITE CALL FROM `Vault`, `Climb` AND `Drop`.** Those own their
## position because the probes measured what they are traversing; `PawnMotion`
## then skips `move_and_slide()` for them entirely. A dash is aimed at open ground
## nobody measured, so owning its position would put a player **through a wall** at
## 9 m/s.
func test_the_dash_does_not_own_its_position() -> void:
	_dash()
	assert_false(
		_machine.drives_position(_ctx),
		"the dash claimed its own position, so geometry cannot stop it"
	)
	for id: StringName in [PawnStateId.VAULT, PawnStateId.CLIMB, PawnStateId.DROP]:
		_ctx.state_id = id
		assert_true(_machine.drives_position(_ctx), "%s stopped owning its position" % id)


## A head-on wall leaves the body barely moving. Standing at full commitment for
## the rest of the window would read as the dash having frozen; it ends instead,
## and `LungeEffect` reads that as the miss it is.
func test_a_dash_stopped_by_geometry_ends() -> void:
	_dash()
	_step(1)
	_ctx.velocity = Vector3(0.0, _ctx.velocity.y, 0.0)
	_step(1)
	assert_eq(_ctx.state_id, PawnStateId.IDLE, "a stopped dash kept its commitment")


## **THE CLIENT IS FORCED INTO THIS STATE BY A SNAPSHOT AND `apply_to` NEVER RUNS
## `enter()`** — it assigns `state_id` directly. So nothing may be captured on
## entry, and the direction has to live somewhere the wire already carries.
## `own_velocity` is that place, which this proves by entering the state the way a
## reconciliation does: fields set, no transition.
func test_a_pawn_dropped_into_the_state_still_dashes() -> void:
	_ctx.state_id = PawnStateId.LUNGING
	_ctx.velocity = Vector3(0.0, 0.0, 1.0) * LungingState.dash_speed()
	_ctx.state_timer_ticks = 0
	_step(2)
	assert_eq(_ctx.state_id, PawnStateId.LUNGING, "a snapshot-forced dash ended immediately")
	var flat := Vector3(_ctx.velocity.x, 0.0, _ctx.velocity.z)
	assert_almost_eq(flat.length(), LungingState.dash_speed(), 0.01, "it lost the locked speed")


## **THE STATE MUST NOT OUTLIVE `AbilityEffect`'s OWN WINDOW**, which is what makes
## the 0.15 m shortfall in `dash_ticks()` the right trade. Ending one step later
## delivers the full 6.0 m and makes `LungeEffect.end` fire while the pawn is still
## `Lunging` — no arrival, no kill, no whiff, the whole resolution silently gone.
## Measured on a live server, both ways.
func test_the_dash_ends_inside_its_own_effect_window() -> void:
	var net_ticks_of_state := float(LungingState.dash_ticks()) / Tuning.net.client_input_rate
	var effect_window := AbilityRules.duration_of(Tuning.ability_data(Ids.ABIL_LUNGE))
	assert_lte(
		net_ticks_of_state,
		effect_window + 0.0001,
		"the dash outlives its effect, so nothing will resolve it"
	)


## **THE DASH STOPS DEAD, AND A LIVE SERVER IS WHAT FOUND THAT IT DID NOT.**
## `tools/ability_probe.tscn` measured **7.27 m against a tuned 6.0**: the state
## held its forty ticks exactly and the pawn then left at 9 m/s and coasted while
## `IdleState` decelerated it. `TUN-LUNGE-DISTANCE` says *"closes the gap and
## nothing more"*, and the extra metre is spent after the auto-kill has been
## judged — so it buys the lunger nothing and slides a whiffed one further into
## the open, while `Staggered` is supposed to leave them standing in it.
func test_the_dash_stops_dead_rather_than_coasting() -> void:
	_dash()
	_step(LungingState.dash_ticks())
	assert_eq(_ctx.state_id, PawnStateId.IDLE, "the dash never ended")
	var flat := Vector3(_ctx.velocity.x, 0.0, _ctx.velocity.z)
	assert_almost_eq(flat.length(), 0.0, 0.001, "the dash coasted out of its own distance")


## The same on every exit, not only the timer's — a stunned lunger must not slide.
func test_being_stunned_out_of_a_dash_also_stops_the_pawn() -> void:
	_dash()
	_step(2)
	_machine.transition(_ctx, PawnStateId.STUNNED, PawnState.PRIORITY_COMBAT)
	var flat := Vector3(_ctx.velocity.x, 0.0, _ctx.velocity.z)
	assert_almost_eq(flat.length(), 0.0, 0.001, "a stunned lunger kept sliding")


## Nothing about the vertical is this state's business: `PawnMotion` applies
## gravity to an ungrounded body, so a dash off a ledge must still fall.
func test_the_vertical_is_left_alone() -> void:
	_dash()
	_ctx.velocity.y = -4.0
	_step(1)
	assert_almost_eq(_ctx.velocity.y, -4.0, 0.001, "the dash flattened a fall")
