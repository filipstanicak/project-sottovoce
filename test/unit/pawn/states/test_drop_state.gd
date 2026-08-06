## Drop and the gap-jump arc. GDD-02 §3.1 and §6, US-0020.
##
## **THE STRATUM ARITHMETIC IS THE DESIGN.** MAP-VETRAIO's roof is 8.5 m, its
## balcony 3.5 m, and `TUN-TRAVERSE-DROP-SAFE-HEIGHT` is 4.0 m. So
## roof→balcony (5.0 m) staggers, balcony→street (3.5 m) does not, and
## roof→street (8.5 m) certainly does.
##
## US-0020's own note puts it plainly: *you can flee across the roofs cheaply
## but cannot rejoin the crowd cheaply.* Descending into the crowd is a small
## skill check rather than a free action — and it is a check on TIME, never on
## anonymity, because dropping down is the cheap direction and must stay so.
##
## The numbers below come from `docs/10_gdd/05_level_design.md`'s strata via
## `VetraioLayout`, not from constants typed here, so a map that moved a floor
## would fail this rather than quietly change the game.
extends GutTest

const DT := 1.0 / 60.0

var _state: DropState
var _ctx: PawnContext


func before_each() -> void:
	_state = DropState.new()
	_ctx = PawnContext.new()
	_ctx.state_id = PawnStateId.DROP


func _plan_fall(from_y: float, to_y: float) -> void:
	_ctx.traverse_case = TraversalResolver.Case.DROP
	_ctx.position = Vector3(0.0, from_y, 0.0)
	_ctx.traverse_start = Vector3(0.0, from_y, 0.0)
	_ctx.traverse_target = Vector3(0.0, to_y, 0.6)
	_ctx.traverse_peak_y = from_y


func _plan_gap(distance: float) -> void:
	_ctx.traverse_case = TraversalResolver.Case.GAP_JUMP
	_ctx.position = Vector3.ZERO
	_ctx.traverse_start = Vector3.ZERO
	_ctx.traverse_target = Vector3(0.0, 0.0, distance)
	_ctx.traverse_peak_y = TraversalResolver._launch_apex()


func _run() -> StringName:
	var out := PawnState.STAY
	for _i: int in 400:
		_ctx.state_timer_ticks += 1
		out = _state.step(_ctx, InputCommand.empty(1), DT)
		if out != PawnState.STAY:
			break
	return out


# ------------------------------------------------------------ the strata --


func test_balcony_to_street_lands_clean() -> void:
	# 3.5 m, under the 4 m threshold. The last step of the correct roof play —
	# climb, cross, drop, be absorbed — must not punish you.
	_plan_fall(VetraioLayout.BALCONY_Y, VetraioLayout.STREET_Y)
	assert_false(DropState.is_hard_landing(_ctx), "balcony-to-street staggered")
	assert_eq(DropState.stagger_ticks(_ctx), 0)


func test_roof_to_balcony_staggers() -> void:
	# 5.0 m, past the threshold. The upper transitions being cheap is what makes
	# the roofs usable; this one is the exception the story's note calls out.
	_plan_fall(VetraioLayout.ROOF_Y, VetraioLayout.BALCONY_Y)
	assert_true(DropState.is_hard_landing(_ctx), "roof-to-balcony was free")


func test_roof_straight_to_the_street_staggers() -> void:
	# 8.5 m — the panic-off-a-roof move. No suspicion, but 0.8 s of helplessness.
	_plan_fall(VetraioLayout.ROOF_Y, VetraioLayout.STREET_Y)
	assert_true(DropState.is_hard_landing(_ctx))
	assert_eq(DropState.stagger_ticks(_ctx), Tuning.step_ticks(&"TUN-TRAVERSE-DROP-STAGGER"))


func test_a_drop_exactly_at_the_threshold_is_clean() -> void:
	# STRICTLY past. The level design builds to this boundary, and a `>=` would
	# tax a transition the metrics deliberately made free.
	_plan_fall(Tuning.movement.traverse_drop_safe_height, 0.0)
	assert_false(DropState.is_hard_landing(_ctx), "a drop at exactly the safe height staggered")
	_plan_fall(Tuning.movement.traverse_drop_safe_height + 0.01, 0.0)
	assert_true(DropState.is_hard_landing(_ctx))


func test_the_stagger_is_the_tunable_at_the_step_rate() -> void:
	_plan_fall(VetraioLayout.ROOF_Y, VetraioLayout.STREET_Y)
	assert_eq(DropState.stagger_ticks(_ctx), Tuning.step_ticks(&"TUN-TRAVERSE-DROP-STAGGER"))
	assert_almost_eq(Tuning.movement.drop_stagger, 0.8, 0.001)


# --------------------------------------------------------------- falling --


func test_a_fall_takes_what_gravity_says() -> void:
	# GDD-02 §6 quotes ~0.9 s for a 4 m drop, which is sqrt(2h/g). The design
	# number was read off the physics; tuning it separately would let the two
	# disagree without anyone noticing which was right.
	_plan_fall(4.0, 0.0)
	var seconds := DropState.flight_ticks(_ctx) / Tuning.net.client_input_rate
	assert_almost_eq(seconds, 0.9, 0.06, "a 4 m fall no longer takes ~0.9 s")


func test_a_longer_fall_takes_longer_but_not_proportionally() -> void:
	# Gravity accelerates. A fall four times as far takes twice as long, and that
	# is what makes a high drop feel committed rather than merely slow.
	_plan_fall(1.0, 0.0)
	var short := DropState.flight_ticks(_ctx)
	_plan_fall(4.0, 0.0)
	var long := DropState.flight_ticks(_ctx)
	assert_almost_eq(float(long) / float(short), 2.0, 0.15)


func test_it_accelerates_rather_than_descending_evenly() -> void:
	# A linear descent reads as being lowered on a wire.
	_plan_fall(8.0, 0.0)
	var first_half := 8.0 - DropState.position_at(_ctx, 0.5).y
	assert_lt(first_half, 4.0, "the fall descended at a constant rate")


func test_it_lands_on_the_plan_and_is_grounded() -> void:
	_plan_fall(VetraioLayout.BALCONY_Y, VetraioLayout.STREET_Y)
	assert_eq(_run(), PawnStateId.IDLE)
	assert_almost_eq(_ctx.position.distance_to(_ctx.traverse_target), 0.0, 0.001)
	assert_true(_ctx.grounded, "the pawn landed and stayed airborne")


func test_entering_leaves_the_ground() -> void:
	_ctx.grounded = true
	_state.enter(_ctx)
	assert_false(_ctx.grounded, "a falling pawn still counted as grounded")


func test_a_hard_landing_holds_the_pawn_for_the_stagger() -> void:
	# The window during which you can be killed. It has to be a real delay in the
	# state machine, not a visual flourish.
	_plan_fall(VetraioLayout.ROOF_Y, VetraioLayout.STREET_Y)
	var flight := DropState.flight_ticks(_ctx)
	for _i: int in flight + 1:
		_ctx.state_timer_ticks += 1
		_state.step(_ctx, InputCommand.empty(1), DT)
	assert_eq(_ctx.state_id, PawnStateId.DROP, "the stagger did not hold the pawn")
	assert_true(_ctx.grounded, "the pawn is staggering in mid-air")
	assert_eq(_run(), PawnStateId.IDLE, "the stagger never released")


func test_a_clean_landing_does_not_hold() -> void:
	_plan_fall(VetraioLayout.BALCONY_Y, VetraioLayout.STREET_Y)
	var flight := DropState.flight_ticks(_ctx)
	for _i: int in flight:
		_ctx.state_timer_ticks += 1
		_state.step(_ctx, InputCommand.empty(1), DT)
	_ctx.state_timer_ticks += 1
	assert_eq(_state.step(_ctx, InputCommand.empty(1), DT), PawnStateId.IDLE, "a clean drop stuck")


# ------------------------------------------------------------- gap jumps --


func test_a_gap_jump_rises_before_it_falls() -> void:
	# Otherwise it is a step off a kerb. The launch is what makes it read as a
	# jump, and reading as a jump is what tells a watcher what you just did.
	_plan_gap(2.0)
	assert_gt(DropState.position_at(_ctx, 0.5).y, 0.0, "the gap jump never left the ground")


func test_a_gap_jump_crosses_the_whole_gap() -> void:
	# A gap at or under TUN-TRAVERSE-GAP-MAX is jumpable ALWAYS. A launch that
	# sometimes fell short would make the level-design contract a lie.
	_plan_gap(Tuning.movement.traverse_gap_max)
	assert_eq(_run(), PawnStateId.IDLE)
	assert_almost_eq(
		_ctx.position.z, Tuning.movement.traverse_gap_max, 0.001, "the jump fell short"
	)


func test_a_gap_jump_flies_for_about_the_documented_time() -> void:
	# GDD-02 §6's cost table says ~0.8 s, which is 2v/g at the tuned launch speed.
	_plan_gap(2.0)
	var seconds := DropState.flight_ticks(_ctx) / Tuning.net.client_input_rate
	assert_almost_eq(seconds, 0.8, 0.06, "a gap jump no longer takes ~0.8 s")


func test_a_level_gap_jump_never_staggers() -> void:
	# It lands where it started, height-wise. Nothing fell.
	_plan_gap(3.0)
	assert_false(DropState.is_hard_landing(_ctx))


# ------------------------------------------------------ interruptibility --


func test_nothing_below_fatal_interrupts_a_fall() -> void:
	# GDD-02 §3.1 says "No" where Vault says "Yes (to COMBAT+)", and the
	# difference is real: a stun is a thing done to someone standing up. Returning
	# COMBAT here refuses COMBAT and admits only FATAL, the same way `Stunned`
	# expresses it.
	assert_false(_state.is_interruptible(_ctx))
	assert_eq(_state.interrupt_priority(), PawnState.PRIORITY_COMBAT)

	var machine := PawnStateMachine.new()
	machine.register(DropState.new())
	machine.register(IdleState.new())
	_plan_fall(VetraioLayout.ROOF_Y, VetraioLayout.STREET_Y)
	assert_false(
		machine.transition(_ctx, PawnStateId.IDLE, PawnState.PRIORITY_COMBAT),
		"a COMBAT interrupt pulled a pawn out of mid-air"
	)
	machine.free()


func test_falling_is_free() -> void:
	# Dropping down is the cheap direction, and §6.1's route economy needs it to
	# stay that way. What a long fall costs is time, never anonymity.
	_plan_fall(VetraioLayout.ROOF_Y, VetraioLayout.STREET_Y)
	assert_eq(_state.suspicion_rate(_ctx), 0.0, "falling charged suspicion")


func test_the_plan_owns_the_position() -> void:
	assert_true(_state.drives_position())
