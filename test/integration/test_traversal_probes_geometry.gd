## **THE PROBES ACTUALLY SEE THINGS.** Real bodies, real raycasts, real
## `ProbeResult`. GDD-02 §7.1 and §7.4, TDD-06 §4.
##
## Everything else in US-0017 is testable without a world: `ProbeLayout` is
## arithmetic and `ProbeResult` is a struct. Both can be perfectly correct while
## the casts hit nothing, point backwards, or read the near face of a wall as its
## top — and none of that would fail a unit test or throw an error. It would just
## mean no wall in the district ever vaults.
##
## The heights are the ones the level-design contract (§7.4) builds at, because
## those are the cases the map will actually present:
##
## | Built at | Must resolve as |
## |---|---|
## | 0.9 m  | vault, always |
## | 1.8 m  | mantle, always |
## | 4.0 m+ | climb, always |
## | 2.0 m gap | easy jump |
##
## Nothing here asserts what the *resolver* decides — that is US-0018. What is
## asserted is that the numbers it will read are the right numbers.
extends GutTest

## Yaw 0 faces +Z (`ProbeLayout.forward`), so obstacles go in front at +Z.
const FACING := 0.0

var _world: Node3D
var _probes: TraversalProbes
var _slab: StaticBody3D


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_probes = TraversalProbes.new()
	_world.add_child(_probes)
	_ground()


func _ground() -> void:
	# 40 x 40 slab whose TOP surface is y = 0, so a pawn's feet sit at the origin.
	_slab = _box(Vector3(40.0, 2.0, 40.0), Vector3(0.0, -1.0, 0.0))


## Replace the slab with one that stops at `near_edge`, and put its far side at
## `far_edge` and `far_drop` metres down. A `far_edge` beyond reach leaves a
## sheer drop with nothing to land on.
func _open_gap(near_edge: float, far_edge: float, far_drop: float = 0.0) -> void:
	_slab.queue_free()
	_world.remove_child(_slab)
	_slab = null
	# Behind and up to the near edge.
	_box(Vector3(40.0, 2.0, 40.0), Vector3(0.0, -1.0, near_edge - 20.0))
	if far_edge < 100.0:
		_box(Vector3(40.0, 2.0, 40.0), Vector3(0.0, -1.0 - far_drop, far_edge + 20.0))


## A static WORLD body. `size` is full extents; `centre` is its middle.
func _box(size: Vector3, centre: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = centre
	return body


## A wall of `height`, standing on the ground, `ahead` metres in front.
func _obstacle(height: float, ahead: float, thickness: float = 0.4) -> void:
	_box(Vector3(6.0, height, thickness), Vector3(0.0, height * 0.5, ahead))


func _probe_at(feet: Vector3) -> ProbeResult:
	var ctx := PawnContext.new()
	ctx.position = feet
	ctx.yaw = FACING
	await get_tree().physics_frame
	await get_tree().physics_frame
	return _probes.refresh(ctx)


func test_an_empty_street_reads_as_open_ground() -> void:
	# The baseline. If this fails, every other assertion below is meaningless
	# because the casts are hitting something nobody put there.
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.valid, "the probes did not run")
	assert_false(probe.chest_hit, "something blocked the chest probe in an empty street")
	assert_false(probe.waist_hit)
	assert_true(probe.foot_clear)
	assert_true(probe.ground_ahead, "the floor was not found ahead")
	assert_false(probe.at_edge(), "a pawn in an open street is standing at an edge")


func test_a_waist_high_wall_is_seen_at_waist_and_not_at_chest() -> void:
	# 0.9 m: the vault case. The chest probe must miss it, or a low wall would
	# offer a climb — §7.2 case 6 is the most expensive option and must never be
	# selected when a cheaper one applies.
	_obstacle(0.9, 0.7)
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.waist_hit, "a 0.9 m wall did not reach the waist probe")
	assert_false(probe.chest_hit, "a 0.9 m wall reached the chest probe")


func test_the_top_of_a_vaultable_wall_is_measured_not_guessed() -> void:
	# `obstacle_top` IS the vault/mantle decision. Measured from the top surface,
	# not from the near face the forward ray hit.
	_obstacle(0.9, 0.7)
	var probe := await _probe_at(Vector3.ZERO)
	assert_almost_eq(probe.obstacle_top, 0.9, 0.05, "the obstacle top was not measured")
	assert_true(
		probe.obstacle_top <= Tuning.movement.traverse_vault_max_height,
		"a 0.9 m wall does not read as vaultable"
	)


func test_a_vault_needs_somewhere_to_land() -> void:
	# §7.2 case 4 requires clear space beyond. Ground continues past this wall.
	_obstacle(0.9, 0.7)
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.clear_beyond, "a wall with open ground beyond it reported nowhere to land")


func test_a_mantle_height_wall_reads_above_the_vault_ceiling() -> void:
	# 1.8 m: the mantle case. Between 1.1 and 2.3, and the level-design contract
	# builds nothing in the 1.05–1.15 boundary band precisely so this is decidable.
	_obstacle(1.8, 0.7)
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.waist_hit)
	assert_almost_eq(probe.obstacle_top, 1.8, 0.05)
	assert_gt(
		probe.obstacle_top,
		Tuning.movement.traverse_vault_max_height,
		"a 1.8 m wall reads vaultable"
	)
	assert_true(
		probe.obstacle_top <= Tuning.movement.traverse_mantle_max_height,
		"a 1.8 m wall reads too tall to mantle"
	)


func test_a_facade_is_hit_at_chest_height_and_is_climbable() -> void:
	# 4.0 m: the climb case. The normal has to say "wall", or a player would find
	# themselves climbing ramps.
	_obstacle(4.0, 0.7)
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.chest_hit, "a 4 m façade did not reach the chest probe")
	assert_true(probe.surface_is_climbable, "a vertical façade did not read as climbable")
	assert_almost_eq(absf(probe.normal.z), 1.0, 0.05, "the façade normal does not face the pawn")


func test_a_tall_facade_reports_no_obstacle_top_at_all() -> void:
	# **THE BUG THIS TEST FOUND.** The obstacle-top cast starts at mantle height,
	# so on a 4 m wall it begins INSIDE the geometry. Godot does not report a shape
	# a ray starts within, so the ray passed through and hit the floor beyond —
	# and the tallest thing in the district measured an obstacle top of 0.0.
	#
	# 0.0 satisfies `obstacle_top <= TUN-TRAVERSE-VAULT-MAX-HEIGHT`. Every façade
	# in Vetraio would have resolved as a vault into a wall.
	#
	# Asserted as INF exactly, not merely "greater than mantle height", because
	# the failure mode is a small number and a `>` test would have passed it.
	_obstacle(4.0, 0.7)
	var probe := await _probe_at(Vector3.ZERO)
	assert_eq(probe.obstacle_top, INF, "a 4 m façade measured a vaultable obstacle top")
	assert_false(probe.clear_beyond, "a façade reported somewhere to land beyond it")


func test_a_tall_facade_has_its_height_measured_for_the_climb_test() -> void:
	# §7.2 case 6 compares the façade height against TUN-TRAVERSE-CLIMB-MAX-HEIGHT,
	# so someone has to measure it. Cast from that ceiling, not from mantle height.
	_obstacle(4.0, 0.7)
	var probe := await _probe_at(Vector3.ZERO)
	assert_almost_eq(probe.surface_height, 4.0, 0.05, "the façade height was not measured")
	assert_true(
		probe.surface_height <= Tuning.movement.traverse_climb_max_height,
		"a 4 m façade reads as too tall to climb"
	)


func test_a_wall_taller_than_one_stratum_is_not_climbable_in_one_go() -> void:
	# TUN-TRAVERSE-CLIMB-MAX-HEIGHT is 9 m: one stratum transition per climb. A
	# 12 m face has to leave a height the resolver will reject.
	_obstacle(12.0, 0.7)
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.chest_hit)
	assert_false(
		probe.surface_height <= Tuning.movement.traverse_climb_max_height,
		"a 12 m wall reads as a single climb"
	)


func test_a_vaultable_wall_does_not_also_report_a_climb_height() -> void:
	# Something with a reachable top is a vault or a mantle. Measuring a climb
	# height for it too would let §7.2 case 6 fire on a 0.9 m wall, which is the
	# resolver choosing its most expensive option when a cheaper one applies.
	_obstacle(0.9, 0.7)
	var probe := await _probe_at(Vector3.ZERO)
	assert_eq(probe.surface_height, INF, "a vaultable wall was measured as a climbable façade")


func test_the_probes_do_not_look_behind_the_pawn() -> void:
	# Forward is +Z at yaw 0. A sign error here would make the pawn vault walls it
	# had already walked past, and every geometry test above would still pass
	# because they all put the obstacle in front.
	_obstacle(0.9, -0.7)
	var probe := await _probe_at(Vector3.ZERO)
	assert_false(probe.waist_hit, "the waist probe found a wall behind the pawn")


func test_turning_around_finds_a_wall_that_was_behind() -> void:
	# The other half: yaw must actually steer the probes.
	_obstacle(0.9, -0.7)
	var ctx := PawnContext.new()
	ctx.position = Vector3.ZERO
	ctx.yaw = PI
	await get_tree().physics_frame
	await get_tree().physics_frame
	var probe := _probes.refresh(ctx)
	assert_true(probe.waist_hit, "facing the wall did not find it")


func test_reach_stops_at_the_tunable() -> void:
	# `TUN-TRAVERSE-PROBE-LENGTH` is 0.9 m. A wall beyond it is not yet the
	# player's problem, and detecting it early would resolve a vault against
	# something they have not reached.
	_obstacle(0.9, 2.5)
	var probe := await _probe_at(Vector3.ZERO)
	assert_false(probe.waist_hit, "the waist probe reached 2.5 m ahead")


# ---------------------------------------------------------------- gap vs drop --


func test_a_kerb_is_not_an_edge() -> void:
	# Ground a little below the pawn's own level is a step down, not a cliff. The
	# tolerance is the foot probe's height, so a 0.2 m kerb stays ground.
	_open_gap(0.4, 0.5, 0.2)
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.ground_ahead, "a 0.2 m kerb read as an edge")
	assert_false(probe.at_edge())


func test_standing_at_an_edge_is_seen_as_one() -> void:
	# The foot probe finds nothing ahead and the down probe finds no floor. Both
	# halves are required: one alone describes a wall or a slope.
	_open_gap(0.5, 1000.0)
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.foot_clear, "something blocked the foot probe at an open edge")
	assert_false(probe.ground_ahead, "the floor was found across a hole")
	assert_true(probe.at_edge(), "a pawn at an edge did not read as being at one")


func test_a_crossable_gap_reports_the_distance_to_the_far_side() -> void:
	# **THE DISTINCTION THE DOWN PROBE EXISTS TO MAKE.** A 2 m gap is the easy
	# jump the level-design contract builds; the resolver compares this number
	# against TUN-TRAVERSE-GAP-MAX and picks a gap jump over a drop.
	_open_gap(0.5, 2.5)
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.at_edge())
	assert_lt(probe.gap_distance, INF, "the far side of a 2 m gap was never found")
	assert_almost_eq(probe.gap_distance, 2.6, Tuning.movement.gap_probe_step)
	assert_true(
		probe.gap_is_crossable(Tuning.movement.traverse_gap_max), "a 2 m gap read as uncrossable"
	)


func test_a_sheer_drop_finds_no_far_side_at_all() -> void:
	# `INF` means drop, a number means gap. With nothing within reach the resolver
	# falls through to §7.2 case 3 — and it must, or a rooftop edge would become a
	# gap jump off the building.
	_open_gap(0.5, 1000.0)
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.at_edge())
	assert_eq(probe.gap_distance, INF, "a sheer drop reported a far side to jump to")


func test_a_gap_wider_than_the_jump_limit_is_not_crossable() -> void:
	# The march stops at TUN-TRAVERSE-GAP-MAX 3.2 m. The metrics bible builds
	# impossible gaps at 3.6 m, and they must read as impossible.
	_open_gap(0.5, 4.0)
	var probe := await _probe_at(Vector3.ZERO)
	assert_false(
		probe.gap_is_crossable(Tuning.movement.traverse_gap_max), "a 4 m gap read as jumpable"
	)


func test_ground_far_below_the_far_side_is_a_drop_not_a_gap() -> void:
	# Something 6 m down is what you FALL to, not what you jump to. Counting it as
	# a far side would turn every rooftop edge in the district into a gap jump.
	_open_gap(0.5, 1.5, 6.0)
	var probe := await _probe_at(Vector3.ZERO)
	assert_true(probe.at_edge())
	assert_eq(probe.gap_distance, INF, "a floor 6 m down was offered as a landing")
