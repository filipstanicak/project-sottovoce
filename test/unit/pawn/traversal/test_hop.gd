## The hop on §7.2's no-match case. GDD-02 §7.2, US-0093.
##
## **AN IMPULSE, NOT A STATE.** So the assertions are on `ctx.velocity` and on the
## state *not* changing — a test that only checked "the pawn ended up higher"
## would pass on a fifteenth `PawnStateId` nobody wanted, on a vault, and on a
## pawn standing on a ramp.
##
## The two things it must never do are as important as the thing it does: it must
## not fire while airborne, which would be a double jump and would open the roofs,
## and it must not add horizontal speed, which would make Space a free metre of
## travel rather than a jump.
extends GutTest

const DT := 1.0 / 60.0

var _ctx: PawnContext


func before_each() -> void:
	_ctx = PawnContext.new()
	_ctx.state_id = PawnStateId.STROLL
	_ctx.position = Vector3(20.0, 0.0, 20.0)
	_ctx.grounded = true
	_ctx.probe_result = ProbeResult.new()
	_ctx.probe_result.valid = true
	# Nothing in front, nothing below: §7.2 case 7.
	_ctx.probe_result.ground_ahead = true
	_ctx.probe_result.foot_clear = true


## Arm a traverse and resolve it, the way `LocomotionState._traverse` does.
func _press_traverse() -> StringName:
	var command := InputCommand.new()
	command.traverse = true
	PawnInputBuffer.tick(_ctx, command)
	return TraversalResolver.resolve(_ctx)


func test_open_ground_is_still_case_seven() -> void:
	# The premise. If this ever resolved to something, every assertion below would
	# be measuring a different manoeuvre.
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.NONE)


# ------------------------------------------------------------------- it hops --


func test_pressing_traverse_in_open_ground_lifts_the_pawn() -> void:
	assert_almost_eq(_ctx.velocity.y, 0.0, 0.001, "the pawn was already rising")
	_press_traverse()
	assert_gt(_ctx.velocity.y, 0.0, "Space in open ground did nothing at all")


func test_it_does_not_change_state() -> void:
	# The whole reason it is an impulse. A hop that transitioned would need a
	# fifteenth state, edges in the normative §3 diagram, and a second owner of
	# `INPUT-TRAVERSE`.
	assert_eq(_press_traverse(), PawnState.STAY, "the hop became a state change")
	assert_eq(_ctx.state_id, PawnStateId.STROLL, "the hop left the locomotion state")


func test_a_committed_rung_jumps_higher_than_a_standing_one() -> void:
	_press_traverse()
	var standing := _ctx.velocity.y

	before_each()
	_ctx.state_id = PawnStateId.RUN
	_press_traverse()
	assert_gt(_ctx.velocity.y, standing, "running did not jump higher than strolling")


func test_the_two_rungs_are_the_tunables_and_not_literals() -> void:
	for state: StringName in [PawnStateId.IDLE, PawnStateId.BLEND_WALK, PawnStateId.STROLL]:
		before_each()
		_ctx.state_id = state
		_press_traverse()
		assert_almost_eq(_ctx.velocity.y, Tuning.movement.hop_standing, 0.001, "%s" % state)
	for state: StringName in [PawnStateId.RUN, PawnStateId.SPRINT]:
		before_each()
		_ctx.state_id = state
		_press_traverse()
		assert_almost_eq(_ctx.velocity.y, Tuning.movement.hop_committed, 0.001, "%s" % state)


# --------------------------------------------------------- and what it is not --


func test_it_adds_no_horizontal_speed() -> void:
	# **NOT "the pawn moved".** A hop that pushed the player forward would make
	# Space a travel input, and the arc's length is meant to be only the speed they
	# already had.
	_ctx.velocity = Vector3(2.2, 0.0, 1.1)
	var before := Vector2(_ctx.velocity.x, _ctx.velocity.z)
	_press_traverse()
	var after := Vector2(_ctx.velocity.x, _ctx.velocity.z)
	assert_almost_eq(after.distance_to(before), 0.0, 0.001, "the hop pushed the pawn along")


func test_it_does_not_fire_while_airborne() -> void:
	# A double jump nobody asked for, and the roofs open up.
	_ctx.grounded = false
	_press_traverse()
	assert_almost_eq(_ctx.velocity.y, 0.0, 0.001, "the pawn hopped in mid-air")


func test_it_does_not_fire_without_a_press() -> void:
	# `resolve` consumes a buffered traverse; with nothing armed it must do
	# nothing at all, or the pawn hops every frame it stands in open ground.
	TraversalResolver.resolve(_ctx)
	assert_almost_eq(_ctx.velocity.y, 0.0, 0.001, "the pawn hopped without being asked")


func test_a_vault_still_wins_over_the_hop() -> void:
	# Cases 1–6 come first, and a hop that stole a vault would undo US-0017–0020.
	_ctx.probe_result.foot_clear = false
	_ctx.probe_result.waist_hit = true
	_ctx.probe_result.obstacle_top = 0.9
	_ctx.probe_result.clear_beyond = true
	_ctx.probe_result.beyond_distance = 1.4
	assert_eq(_press_traverse(), PawnStateId.VAULT, "the hop stole a vault")


func test_a_ledge_grab_still_wins_over_the_hop() -> void:
	# **THE COMBINATION US-0093 PROMISED FOR FREE.** A hop leaves the pawn
	# airborne, and §7.2 case 1 catches a ledge within `TUN-TRAVERSE-MAGNET-RADIUS`
	# — so a hop that ends near one becomes a grab without the hop knowing anything
	# about ledges. The `grounded` guard is what makes this unambiguous: airborne,
	# the hop cannot fire, and case 1 is the only thing that can answer.
	_ctx.grounded = false
	_ctx.probe_result.ledge_found = true
	_ctx.probe_result.ledge_lateral = 0.0
	_ctx.ledge_magnet_ticks = Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW")
	assert_eq(_press_traverse(), PawnStateId.CLIMB, "a hop near a ledge did not grab it")
	assert_almost_eq(_ctx.velocity.y, 0.0, 0.001, "it hopped as well as grabbing")
