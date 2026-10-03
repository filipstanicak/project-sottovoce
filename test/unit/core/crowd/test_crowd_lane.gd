## **A STROLLER'S OWN SIDE OF THE STREET, AS ARITHMETIC.** US-0103, `CrowdLane`.
##
## The rows the owner reported were strollers sharing one shortest path. These hold
## the rule that spreads them: one offset per figure, kept, deterministic, bounded,
## spread over both sides, and a route moved onto it with its ends where they were.
extends GutTest

const SEED := 20261004
const SPREAD := 1.0


func test_the_offset_is_the_same_every_time_it_is_asked() -> void:
	for index: int in 20:
		assert_eq(
			CrowdLane.lateral_for(SEED, index, SPREAD),
			CrowdLane.lateral_for(SEED, index, SPREAD),
			"figure %d changed sides between two questions" % index
		)


func test_the_offset_stays_inside_the_spread_and_uses_both_sides() -> void:
	var left := 0
	var right := 0
	for index: int in 200:
		var lateral := CrowdLane.lateral_for(SEED, index, SPREAD)
		assert_between(lateral, -SPREAD, SPREAD, "figure %d is outside the spread" % index)
		if lateral < -0.3:
			left += 1
		elif lateral > 0.3:
			right += 1
	# **THE PROPERTY THE ROWS BROKE.** Everybody on one side is a row one metre over.
	assert_gt(left, 50, "too few figures walk on one side: %d of 200" % left)
	assert_gt(right, 50, "too few figures walk on the other side: %d of 200" % right)


func test_another_match_deals_other_sides() -> void:
	var differ := 0
	for index: int in 50:
		if not is_equal_approx(
			CrowdLane.lateral_for(SEED, index, SPREAD),
			CrowdLane.lateral_for(SEED + 1, index, SPREAD)
		):
			differ += 1
	assert_gt(differ, 40, "the lanes ignore the match seed")


func test_no_spread_is_no_offset() -> void:
	for index: int in 20:
		assert_eq(CrowdLane.lateral_for(SEED, index, 0.0), 0.0)


func test_a_route_keeps_its_ends_and_moves_onto_the_lane() -> void:
	var path := PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 10), Vector3(10, 0, 10)])
	var lane := CrowdLane.offset_path(path, 0.8)
	assert_eq(lane[0], path[0], "the figure no longer leaves from where it stands")
	assert_eq(lane[lane.size() - 1], path[path.size() - 1], "the figure arrives somewhere else")
	# Every leg's midpoint is moved square to the leg by the lane's width.
	assert_almost_eq(lane[1].distance_to(Vector3(0, 0, 5)), 0.8, 0.001)
	assert_almost_eq((lane[1] - Vector3(0, 0, 5)).dot(Vector3(0, 0, 10)), 0.0, 0.001)
	# The corner moves along its bisector, by the same width.
	assert_almost_eq(lane[2].distance_to(path[1]), 0.8, 0.001)


func test_a_straight_crossing_still_bends_onto_the_lane() -> void:
	# **THE PLAZA CASE.** A two-point path has no corner to move; without the midpoint
	# every figure crossing the same plaza would still walk the same line.
	var lane := CrowdLane.offset_path(PackedVector3Array([Vector3.ZERO, Vector3(20, 0, 0)]), -1.0)
	assert_eq(lane.size(), 3)
	assert_almost_eq(lane[1].distance_to(Vector3(10, 0, 0)), 1.0, 0.001)


func test_the_two_signs_are_the_two_sides() -> void:
	var path := PackedVector3Array([Vector3.ZERO, Vector3(20, 0, 0)])
	var left := CrowdLane.offset_path(path, 1.0)
	var right := CrowdLane.offset_path(path, -1.0)
	assert_almost_eq(left[1].distance_to(right[1]), 2.0, 0.001)


func test_every_moved_point_is_snapped_and_the_ends_are_not() -> void:
	var asked: Array = []
	var snap := func(point: Vector3) -> Vector3:
		asked.append(point)
		return Vector3(point.x, 0.0, 0.0)
	var path := PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 10), Vector3(10, 0, 10)])
	var lane := CrowdLane.offset_path(path, 0.8, snap)
	assert_eq(asked.size(), lane.size() - 2, "a moved point was not put back on the navmesh")
	for i: int in range(1, lane.size() - 1):
		assert_eq(lane[i].z, 0.0, "point %d is the moved point, not the snapped one" % i)


func test_no_lane_is_the_shortest_path_unchanged() -> void:
	var path := PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 10), Vector3(10, 0, 10)])
	assert_eq(CrowdLane.offset_path(path, 0.0), path)
