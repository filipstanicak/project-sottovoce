## **ALL SEVEN CASES, IN ORDER, INCLUDING CASE 7's SILENCE.** GDD-02 §7.2,
## TDD-06 §4.2. US-0018's test notes name this file.
##
## The order is normative. It is not an implementation detail that happens to
## work: each rung is a decision, and getting two of them the wrong way round
## produces a game that is subtly, permanently wrong to move through — a low wall
## you climb onto instead of over, a façade you vault into, a ledge you fall past
## because the gap behind it won the tie.
##
## Every case is asserted **against a hand-filled `ProbeResult`**, with no world,
## because that is what makes the priority testable at all. Whether the probes
## produce those numbers is `test_traversal_probes_geometry.gd`'s job.
extends GutTest

var _ctx: PawnContext


func before_each() -> void:
	_ctx = PawnContext.new()
	_ctx.grounded = true
	_ctx.probe_result.valid = true
	# STANDING ON SOLID GROUND, stated explicitly. A `ProbeResult` that merely
	# found nothing satisfies both halves of the edge test — foot clear, no ground
	# reported — so a fixture that omitted this would silently make every case
	# below resolve as a drop. Real probes set it; test doubles have to as well.
	_ctx.probe_result.ground_ahead = true


## A pawn standing at an edge with a far side `distance` metres away.
func _at_gap(distance: float) -> void:
	_ctx.probe_result.foot_clear = true
	_ctx.probe_result.ground_ahead = false
	_ctx.probe_result.gap_distance = distance


## A pawn against something at foot height. Anything standing on the ground and
## tall enough to hit the waist probe also blocks the foot probe.
func _blocks_the_foot() -> void:
	_ctx.probe_result.foot_clear = false


## A pawn facing an obstacle whose top is `top` metres up.
func _at_obstacle(top: float, clear_beyond: bool = true) -> void:
	_blocks_the_foot()
	_ctx.probe_result.waist_hit = true
	_ctx.probe_result.obstacle_top = top
	_ctx.probe_result.clear_beyond = clear_beyond


## A pawn facing a climbable façade `height` metres tall.
func _at_facade(height: float) -> void:
	_blocks_the_foot()
	_ctx.probe_result.chest_hit = true
	_ctx.probe_result.surface_is_climbable = true
	_ctx.probe_result.surface_height = height


## A pawn falling past a ledge `lateral` metres to the side, window still open.
func _falling_past_ledge(lateral: float = 0.0) -> void:
	_ctx.grounded = false
	_ctx.probe_result.ledge_found = true
	_ctx.probe_result.ledge_lateral = lateral
	_ctx.probe_result.ledge_height = Tuning.movement.probe_height_chest
	_ctx.ledge_magnet_ticks = Tuning.step_ticks(&"TUN-TRAVERSE-MAGNET-WINDOW")


# ------------------------------------------------------- the seven cases --


func test_case_1_ledge_grab() -> void:
	_falling_past_ledge()
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.LEDGE_GRAB)


func test_case_2_gap_jump() -> void:
	_at_gap(2.0)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.GAP_JUMP)


func test_case_3_drop() -> void:
	_at_gap(INF)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.DROP)


func test_case_4_vault() -> void:
	_at_obstacle(0.9)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.VAULT)


func test_case_5_mantle() -> void:
	_at_obstacle(1.8)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.MANTLE)


func test_case_6_climb() -> void:
	_at_facade(4.0)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.CLIMB)


func test_case_7_nothing() -> void:
	# An empty street. No edge, no wall, no façade.
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.NONE)


# --------------------------------------------------------- the ordering --


func test_ledge_grab_beats_everything_else() -> void:
	# **FORGIVENESS GOES FIRST.** Catching a ledge you are falling past must win
	# even when a gap, a wall and a façade all also match — otherwise the player
	# who reacted correctly gets whatever the geometry happened to offer instead.
	_at_obstacle(0.9)
	_at_facade(4.0)
	_at_gap(2.0)
	_falling_past_ledge()
	assert_eq(
		TraversalResolver.classify(_ctx),
		TraversalResolver.Case.LEDGE_GRAB,
		"a ledge grab lost to a lower case"
	)


func test_a_gap_beats_a_wall_behind_it() -> void:
	_at_obstacle(0.9)
	_at_gap(2.0)  # After, so the edge overwrites the foot block.
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.GAP_JUMP)


func test_vault_is_checked_before_mantle() -> void:
	# A low wall you can go OVER must not become one you climb ONTO. At exactly
	# the vault ceiling the answer is still vault — the boundary is inclusive, and
	# the level-design contract builds nothing in the 1.05–1.15 band so no real
	# geometry sits on it.
	_at_obstacle(Tuning.movement.traverse_vault_max_height)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.VAULT)
	_at_obstacle(Tuning.movement.traverse_vault_max_height + 0.01)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.MANTLE)


func test_climb_is_last() -> void:
	# The most expensive option is never selected when a cheaper one applies. A
	# 1.8 m wall hits the chest probe too, so without the ordering this would be a
	# climb — and climbing costs TUN-SUSPICION-GAIN-CLIMB where a mantle does not.
	_at_obstacle(1.8)
	_at_facade(1.8)
	assert_eq(
		TraversalResolver.classify(_ctx),
		TraversalResolver.Case.MANTLE,
		"a mantle-height wall resolved as a climb"
	)


func test_a_vault_with_nowhere_to_land_is_not_a_vault() -> void:
	# §7.2 case 4 requires clear space beyond. Without it the manoeuvre is a vault
	# into a wall, and falling through to case 7 is the honest answer.
	_at_obstacle(0.9, false)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.NONE)


func test_a_wall_too_tall_to_mantle_falls_through_to_climb() -> void:
	_at_obstacle(3.0)
	_at_facade(4.0)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.CLIMB)


func test_a_facade_beyond_one_stratum_resolves_to_nothing() -> void:
	# TUN-TRAVERSE-CLIMB-MAX-HEIGHT is 9 m: one stratum transition per climb.
	_at_facade(Tuning.movement.traverse_climb_max_height + 1.0)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.NONE)


func test_a_ramp_is_never_a_climb() -> void:
	# `surface_is_climbable` is what stops a player climbing a staircase.
	_blocks_the_foot()
	_ctx.probe_result.chest_hit = true
	_ctx.probe_result.surface_is_climbable = false
	_ctx.probe_result.surface_height = 4.0
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.NONE)


func test_a_gap_wider_than_the_jump_limit_is_a_drop() -> void:
	_at_gap(Tuning.movement.traverse_gap_max + 0.1)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.DROP)
	_at_gap(Tuning.movement.traverse_gap_max)
	assert_eq(TraversalResolver.classify(_ctx), TraversalResolver.Case.GAP_JUMP)


# ------------------------------------------------- unprobed means nothing --


func test_an_unprobed_context_resolves_to_nothing() -> void:
	# THE SAME TRAP AS `at_edge()`. A cleared `ProbeResult` satisfies several of
	# the conditions above, so a pawn whose probes had not run would resolve to a
	# drop off a cliff that is not there.
	_ctx.probe_result.clear()
	_ctx.probe_result.foot_clear = true
	assert_false(_ctx.probe_result.valid)
	assert_eq(
		TraversalResolver.classify(_ctx),
		TraversalResolver.Case.NONE,
		"an unmeasured frame resolved to a manoeuvre"
	)
