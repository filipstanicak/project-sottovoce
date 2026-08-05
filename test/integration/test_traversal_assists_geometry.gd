## **THE TWO FORGIVENESS ASSISTS, AGAINST REAL GEOMETRY.** GDD-02 §7.3.
##
## Auto-align — the gap fan — and ledge magnetism are the halves of traversal
## that exist purely to be *generous*. Both are easy to build so that they either
## never fire or always fire, and neither failure produces an error: the first
## feels like the controls ignoring you, the second like the game playing itself.
##
## Both were broken when first written, and neither was caught by anything else.
## The fan asked `at_edge()`, which requires a flag set after every cast has run —
## from inside one of the casts, so it silently never fired. The ledge top-cast
## was placed a fixed step ahead rather than past the face it hit, so it measured
## the floor in front of the wall.
extends GutTest

const FACING := TraversalWorld.FACING

var _world: TraversalWorld
var _probes: TraversalProbes


func before_each() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	_world = TraversalWorld.new(host)
	_probes = TraversalProbes.new()
	_world.root.add_child(_probes)


func _probe_at(feet: Vector3) -> ProbeResult:
	return await _probe_ctx(TraversalWorld.context(feet, FACING, true))


func _probe_ctx(ctx: PawnContext) -> ProbeResult:
	await get_tree().physics_frame
	await get_tree().physics_frame
	return _probes.refresh(ctx)


func test_the_gap_fan_finds_a_crossing_off_the_nose() -> void:
	# **AUTO-ALIGN.** The far side is a narrow block offset to the right; straight
	# ahead there is nothing. A player who can plainly see the crossing should not
	# have to be square to it (GDD-02 §7.3).
	_world.open_gap(0.5, 1000.0)
	_world.box(Vector3(1.0, 2.0, 6.0), Vector3(1.2, -1.0, 4.0))
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.at_edge())
	assert_lt(probe.gap_distance, INF, "the fan never found the offset crossing")
	assert_gt(probe.gap_yaw_offset, 0.0, "the crossing is to the right; the offset is not")
	assert_true(
		absf(probe.gap_yaw_offset) <= deg_to_rad(Tuning.movement.gap_align_arc) + 0.001,
		"the fan searched beyond TUN-TRAVERSE-GAP-ALIGN-ARC"
	)


func test_a_crossing_straight_ahead_needs_no_alignment() -> void:
	# The assist supplies an answer the player did not have; it never overrides
	# one they did. A square approach must leave the yaw untouched.
	_world.open_gap(0.5, 2.5)
	var probe := await _probe_at(Vector3.ZERO)
	assert_lt(probe.gap_distance, INF)
	assert_almost_eq(probe.gap_yaw_offset, 0.0, 0.0001, "a square approach was rotated")


func test_a_crossing_beyond_the_arc_is_not_found() -> void:
	# Far off to the side is a gap the player was not crossing. Turning them
	# toward it would be the assist making a decision that is theirs.
	_world.open_gap(0.5, 1000.0)
	_world.box(Vector3(1.0, 2.0, 6.0), Vector3(6.0, -1.0, 2.0))
	var probe := await _probe_at(Vector3.ZERO)
	assert_eq(probe.gap_distance, INF, "the fan reached a crossing 45 degrees off the nose")


func test_a_ledge_beside_a_falling_pawn_is_found() -> void:
	# **THE FORGIVENESS CASE.** Airborne, with a grabbable top at chest height and
	# offset to one side — exactly the "not laterally aligned" §7.3 forgives.
	_world.ledge_block(0.3)
	var probe := await _probe_ctx(TraversalWorld.context(Vector3.ZERO, FACING, false))
	assert_true(probe.ledge_found, "a ledge at chest height beside the pawn was not seen")
	assert_gt(probe.ledge_lateral, 0.0, "a ledge on the right reported a left-hand offset")
	assert_true(
		probe.ledge_within(Tuning.movement.traverse_magnet_radius),
		"a ledge inside the magnet radius did not read as in reach"
	)
	assert_almost_eq(probe.ledge_height, 1.35, 0.1)


func test_the_grab_snaps_toward_the_ledge_on_either_side() -> void:
	# The sign is what decides which way the pawn is pulled. Getting it backwards
	# would throw a falling player away from the ledge they reached for.
	_world.ledge_block(-0.3)
	var probe := await _probe_ctx(TraversalWorld.context(Vector3.ZERO, FACING, false))
	assert_true(probe.ledge_found, "a ledge on the left was not seen")
	assert_lt(probe.ledge_lateral, 0.0, "a ledge on the left reported a right-hand offset")


func test_a_grounded_pawn_casts_no_ledge_probes() -> void:
	# Airborne only. A grounded pawn is not falling past anything, and the same
	# geometry is a mantle — skipping the casts is both correct and five fewer
	# raycasts on the common frame.
	_world.ledge_block(0.3)
	var probe := await _probe_ctx(TraversalWorld.context(Vector3.ZERO, FACING, true))
	assert_false(probe.ledge_found, "a grounded pawn found a ledge to grab")


func test_a_ledge_at_the_ankles_is_already_past() -> void:
	# The window is vertical as well as lateral. A top level with your chest is
	# the one you catch; one at your feet is one you have already fallen past.
	var x := ProbeLayout.right(FACING).x * 0.3
	_world.box(Vector3(0.4, 0.2, 0.8), Vector3(x, 0.1, 0.8))
	var probe := await _probe_ctx(TraversalWorld.context(Vector3.ZERO, FACING, false))
	assert_false(probe.ledge_found, "a 0.2 m kerb was offered as a ledge grab")
