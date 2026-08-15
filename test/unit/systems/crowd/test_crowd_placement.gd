## **WHERE THE NINETY START.** US-0041.
##
## Pure arithmetic, so the spread and the determinism are asked directly. The
## navmesh half — that every position is actually *on* the mesh — belongs to
## `test_navmesh_coverage.gd`, which has a live navigation map; here the map is
## an invalid RID and the fallback path is what gets exercised.
extends GutTest

const SEED := 20260816

var _anchors: Array = []


func before_each() -> void:
	_anchors = []
	for i: int in 20:
		_anchors.append(Vector3(float(i) * 5.0, 0.0, float(i % 4) * 8.0))


func test_one_position_per_npc() -> void:
	assert_eq(CrowdPlacement.positions(78, SEED, _anchors, RID()).size(), 78)


func test_it_is_deterministic_from_the_seed() -> void:
	# **TWO SERVERS ON ONE SEED PLACE THE SAME CROWD**, which is what lets a replay
	# be a replay. The roster already agrees; a placement that did not would make
	# the two diverge from the first frame.
	var a := CrowdPlacement.positions(78, SEED, _anchors, RID())
	var b := CrowdPlacement.positions(78, SEED, _anchors, RID())
	assert_eq(a, b, "two placements from one seed differ")


func test_a_different_seed_places_differently() -> void:
	# The other half: a placement that ignored the seed would make every match
	# start identically and would pass the test above.
	var a := CrowdPlacement.positions(78, SEED, _anchors, RID())
	var b := CrowdPlacement.positions(78, SEED + 1, _anchors, RID())
	assert_ne(a, b, "two seeds produced the same placement")


func test_anchors_are_used_round_robin() -> void:
	# **A DISTRICT WITH 62 ANCHORS AND 78 NPCs MUST NOT PUT SIXTY AT THE FIRST
	# ONE.** Round-robin is what makes the spread even without any global
	# optimisation; the failure it prevents is a crowd bunched in one quarter.
	# **THE SCATTER IS PER AXIS**, so the furthest a point can land from its anchor
	# is `SCATTER * sqrt(2)` ≈ 4.24 m, not `SCATTER`. The first version of this
	# assertion used 3.0 and undercounted — trap 4: a bound that looks right and
	# does not match the geometry it describes.
	var reach := CrowdPlacement.SCATTER * sqrt(2.0) + 0.01
	var spots := CrowdPlacement.positions(_anchors.size() * 3, SEED, _anchors, RID())
	var near_first := 0
	for spot: Vector3 in spots:
		if spot.distance_to(_anchors[0]) <= reach:
			near_first += 1
	assert_eq(near_first, 3, "the first anchor did not get exactly its share")


func test_nobody_lands_further_from_an_anchor_than_the_scatter() -> void:
	var spots := CrowdPlacement.positions(78, SEED, _anchors, RID())
	for spot: Vector3 in spots:
		var nearest := INF
		for anchor: Vector3 in _anchors:
			nearest = minf(nearest, spot.distance_to(anchor))
		assert_lt(
			nearest,
			CrowdPlacement.SCATTER * sqrt(2.0) + 0.01,
			"an NPC started far from every anchor"
		)


func test_they_are_not_all_stacked_on_one_point() -> void:
	# The scatter exists so a popular anchor does not stack four NPCs on one
	# point. A placement that dropped the offset would pass everything above.
	var spots := CrowdPlacement.positions(78, SEED, _anchors, RID())
	var distinct: Dictionary = {}
	for spot: Vector3 in spots:
		distinct["%.1f,%.1f" % [spot.x, spot.z]] = true
	assert_gt(distinct.size(), 60, "the crowd is stacked on a handful of points")


func test_no_anchors_places_nobody_rather_than_crashing() -> void:
	# A map with no idle anchors is a level defect, not a crash. Returning empty
	# lets the server log a crowd of zero, which is findable; an index error in
	# `_ready()` is a server that will not start.
	assert_eq(CrowdPlacement.positions(78, SEED, [], RID()).size(), 0)
