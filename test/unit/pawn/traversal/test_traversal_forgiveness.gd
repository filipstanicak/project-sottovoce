## **~0.45 s AROUND EVERY TRAVERSE OPPORTUNITY.** GDD-02 §7.3, TDD-06 §4.3.
##
## 0.20 s early (`TUN-TRAVERSE-INPUT-BUFFER`) plus 0.25 s late
## (`TUN-TRAVERSE-MAGNET-WINDOW`), plus 0.6 m of lateral slack
## (`TUN-TRAVERSE-MAGNET-RADIUS`) and ±20° of aim
## (`TUN-TRAVERSE-GAP-ALIGN-ARC`).
##
## That is enormous by action-game standards and it is deliberate: **a missed
## ledge must be a decision error, never a timing error.** The player's attention
## belongs on the crowd, which is the game, not on their own footwork, which is
## not. Parkour here is assisted, not simulated.
##
## Every window is asserted at its edges — one tick inside and one tick outside —
## because a forgiveness window that is silently half its tuned length is exactly
## the defect `Tuning.step_ticks` exists to prevent, and it feels like nothing at
## all until a playtester says the controls are "sticky".
extends GutTest

var _ctx: PawnContext


func before_each() -> void:
	_ctx = PawnContext.new()
	_ctx.grounded = false
	_ctx.probe_result.valid = true


func _ledge_in_reach(lateral: float = 0.0) -> void:
	_ctx.probe_result.ledge_found = true
	_ctx.probe_result.ledge_lateral = lateral
	_ctx.probe_result.ledge_height = Tuning.movement.probe_height_chest


func _no_ledge() -> void:
	_ctx.probe_result.ledge_found = false


# ------------------------------------------------------- the late window --


func test_the_late_window_is_the_tunable_at_the_step_rate() -> void:
	# 0.25 s at 60 Hz is 15 ticks. At the 30 Hz net tick it would be 8, and the
	# window would forgive 0.125 s while every document says 0.25.
	var expected: int = int(
		round(Tuning.movement.traverse_magnet_window * Tuning.net.client_input_rate)
	)
	assert_eq(Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW"), expected)
	assert_eq(expected, 15, "0.25 s at the 60 Hz step rate is 15 ticks")
	# Not exactly 2x: 0.25 s is 7.5 net ticks and rounds to 8, so the 30 Hz figure
	# is a tick GENEROUS while the step figure is exact. Strictly greater is the
	# real invariant — if these ever met, one of the rates moved.
	assert_gt(
		Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW"),
		Tuning.ticks(&"TUN-TRAVERSE-MAGNET-WINDOW"),
		"the step rate is no longer faster than the net tick"
	)


func test_a_ledge_in_reach_arms_the_window() -> void:
	_ledge_in_reach()
	TraversalResolver.tick_magnet(_ctx)
	assert_eq(_ctx.ledge_magnet_ticks, Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW"))


func test_pressing_late_still_grabs_for_the_whole_window() -> void:
	# **THE POINT OF THE WINDOW.** The player has already fallen past the ledge;
	# every frame from here on the probes see nothing, and the grab must keep
	# working anyway.
	_ledge_in_reach()
	TraversalResolver.tick_magnet(_ctx)
	var window := Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW")

	for _i: int in window - 1:
		_no_ledge()
		TraversalResolver.tick_magnet(_ctx)
	assert_gt(_ctx.ledge_magnet_ticks, 0, "the grab window closed inside its own duration")

	# The probes have to still see the ledge for the grab itself; the window
	# forgives the PRESS being late, not the ledge having vanished.
	_ledge_in_reach()
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.LEDGE_GRAB)


func test_the_window_closes_after_its_duration_and_not_before() -> void:
	_ledge_in_reach()
	TraversalResolver.tick_magnet(_ctx)
	for _i: int in Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW"):
		_no_ledge()
		TraversalResolver.tick_magnet(_ctx)
	assert_eq(_ctx.ledge_magnet_ticks, 0, "the window outlived its duration")

	_ledge_in_reach()
	assert_ne(
		TraversalResolver.classify(_ctx),
		TraversalResolver.Case.LEDGE_GRAB,
		"a grab fired after the window had closed"
	)


func test_the_machine_ticks_the_window_inside_step() -> void:
	# Same reasoning as the action buffer: this changes the simulation, so a
	# client-only version would predict a grab the server never performed.
	var machine := PawnStateMachine.new()
	machine.register(IdleState.new())
	var ctx := PawnContext.new()
	ctx.state_id = PawnStateId.IDLE
	ctx.grounded = false
	ctx.probe_result.valid = true
	ctx.probe_result.ledge_found = true

	machine.step(ctx, InputCommand.empty(1), 1.0 / 60.0)
	assert_gt(ctx.ledge_magnet_ticks, 0, "step() did not tick the magnet window")
	machine.free()


func test_a_respawn_clears_the_window() -> void:
	_ledge_in_reach()
	TraversalResolver.tick_magnet(_ctx)
	_ctx.reset_for_spawn(Vector3.ZERO, 0.0)
	assert_eq(_ctx.ledge_magnet_ticks, 0, "a grab window survived a respawn")


# ---------------------------------------------------- the lateral radius --


func test_a_ledge_within_the_radius_is_grabbable_on_either_side() -> void:
	# Signed, and both signs must work. A grab that only forgave one side would
	# be a bug nobody notices until they fall off the left of something.
	var radius := Tuning.movement.traverse_magnet_radius
	for lateral: float in [-radius, -radius * 0.5, 0.0, radius * 0.5, radius]:
		_ctx.probe_result.clear()
		_ctx.probe_result.valid = true
		_ledge_in_reach(lateral)
		_ctx.ledge_magnet_ticks = Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW")
		assert_eq(
			TraversalResolver.classify(_ctx),
			TraversalResolver.Case.LEDGE_GRAB,
			"a ledge %.2f m to the side was not grabbable" % lateral
		)


func test_a_ledge_beyond_the_radius_is_not() -> void:
	_ledge_in_reach(Tuning.movement.traverse_magnet_radius + 0.01)
	_ctx.ledge_magnet_ticks = Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW")
	assert_ne(TraversalResolver.classify(_ctx), TraversalResolver.Case.LEDGE_GRAB)


func test_the_radius_is_the_documented_value() -> void:
	assert_almost_eq(Tuning.movement.traverse_magnet_radius, 0.6, 0.001)
	assert_almost_eq(Tuning.movement.traverse_magnet_window, 0.25, 0.001)


func test_a_grounded_pawn_never_ledge_grabs() -> void:
	# Case 1 is for catching yourself in the air. On the ground the same geometry
	# is a mantle, and it must resolve as one.
	_ctx.grounded = true
	_ledge_in_reach()
	_ctx.ledge_magnet_ticks = Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW")
	assert_ne(TraversalResolver.classify(_ctx), TraversalResolver.Case.LEDGE_GRAB)


# --------------------------------------------------------- the early half --


func test_the_early_and_late_windows_together_are_about_half_a_second() -> void:
	# GDD-02 §7.3 states the combined figure explicitly, and it is the number the
	# whole design position rests on. If a retune ever halves it, this says so.
	var combined := Tuning.movement.traverse_input_buffer + Tuning.movement.traverse_magnet_window
	assert_almost_eq(combined, 0.45, 0.01, "the combined forgiveness window moved")


func test_a_traverse_pressed_early_still_resolves() -> void:
	# The buffer is armed before the obstacle is in range; by the time the probes
	# see the wall the press is several ticks old and must still count.
	var ctx := PawnContext.new()
	ctx.grounded = true
	var pressed := InputCommand.empty(1)
	pressed.traverse = true
	PawnInputBuffer.tick(ctx, pressed)

	for _i: int in Tuning.step_ticks(&"TUN-TRAVERSE-INPUT-BUFFER") - 1:
		PawnInputBuffer.tick(ctx, InputCommand.empty(1))

	ctx.probe_result.valid = true
	ctx.probe_result.ground_ahead = true
	ctx.probe_result.foot_clear = false
	ctx.probe_result.waist_hit = true
	ctx.probe_result.obstacle_top = 0.9
	ctx.probe_result.clear_beyond = true
	assert_eq(TraversalResolver.resolve(ctx), PawnStateId.VAULT, "an early press was dropped")


# ------------------------------------------------------------ auto-align --


func test_auto_align_leaves_a_square_approach_alone() -> void:
	# The assist supplies an answer the player did not have. It never overrides
	# one they did.
	_ctx.yaw = 1.0
	_ctx.probe_result.gap_yaw_offset = 0.0
	assert_almost_eq(TraversalResolver.aligned_yaw(_ctx), 1.0, 0.0001)


func test_auto_align_turns_toward_the_crossing() -> void:
	_ctx.yaw = 0.0
	_ctx.probe_result.gap_yaw_offset = deg_to_rad(15.0)
	assert_almost_eq(TraversalResolver.aligned_yaw(_ctx), deg_to_rad(15.0), 0.0001)


func test_auto_align_is_bounded_by_the_arc() -> void:
	# It must never turn you toward a gap you were not crossing. Even a corrupt
	# offset is clamped, because this rotates the player's character for them.
	_ctx.yaw = 0.0
	_ctx.probe_result.gap_yaw_offset = deg_to_rad(90.0)
	assert_almost_eq(
		TraversalResolver.aligned_yaw(_ctx),
		deg_to_rad(Tuning.movement.gap_align_arc),
		0.0001,
		"auto-align rotated the pawn beyond TUN-TRAVERSE-GAP-ALIGN-ARC"
	)


func test_the_align_arc_is_the_documented_twenty_degrees() -> void:
	assert_almost_eq(Tuning.movement.gap_align_arc, 20.0, 0.001)


# ----------------------------------------------------- case 7 is silence --


func test_a_failed_traverse_consumes_the_input_and_plays_nothing() -> void:
	# **SILENCE, NOT A FLAIL.** A failed traverse must never look like a bug —
	# and leaving the press buffered would fire the manoeuvre a moment later, at
	# the next wall the player walked past, which is worse than doing nothing.
	var ctx := PawnContext.new()
	ctx.grounded = true
	ctx.probe_result.valid = true
	ctx.probe_result.ground_ahead = true
	var pressed := InputCommand.empty(1)
	pressed.traverse = true
	PawnInputBuffer.tick(ctx, pressed)

	assert_eq(TraversalResolver.resolve(ctx), PawnState.STAY, "an empty street resolved to a state")
	assert_false(
		PawnInputBuffer.has_traverse(ctx), "a failed traverse left the press armed to fire later"
	)


func test_resolve_without_a_press_does_nothing_at_all() -> void:
	# The resolver is only ever asked because a button was pressed. Asked without
	# one, it must not consume anything or resolve anything.
	var ctx := PawnContext.new()
	ctx.probe_result.valid = true
	ctx.probe_result.ground_ahead = true
	ctx.probe_result.foot_clear = false
	ctx.probe_result.waist_hit = true
	ctx.probe_result.obstacle_top = 0.9
	ctx.probe_result.clear_beyond = true
	assert_eq(TraversalResolver.resolve(ctx), PawnState.STAY, "a vault fired with no input")
