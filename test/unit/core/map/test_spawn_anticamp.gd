## **FROM ANY CAMPING POSITION, AT LEAST THREE SPAWNS REMAIN VALID.** GDD-05
## §2.7's anti-spawn-camp analysis, US-0062's last criterion.
##
## That analysis is a four-row table of hand-picked positions — the piazza, Piazza
## Secca, the Fondaco, the campanile — and its conclusion is *"worst case: three
## valid spawns remain"*. **Four samples cannot establish a worst case over a
## 120 × 120 m district**, so this sweeps the whole map on a grid and reports the
## real minimum beside the documented one.
##
## It is a property of `MAP-VETRAIO` and `TUN-RESPAWN-MIN-DIST-FROM-KILLER`
## together, so it goes red if either the spawn points move or the distance is
## retuned — which is exactly when somebody needs to re-read the analysis.
extends GutTest

const MAP := "res://data/maps/map_vetraio.tres"

## Two metres. Fine enough that a camper cannot stand between samples, coarse
## enough to run in well under a second: 61 × 61 positions.
const GRID := 2.0

var _map: MapData
var _t: ContractTuning


func before_all() -> void:
	_map = load(MAP) as MapData
	_t = Tuning.contract


func test_the_map_loaded_and_declares_its_spawns() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** Every "at least three" assertion below is
	# satisfied trivially by a map with no spawn points and no camper positions.
	assert_not_null(_map, "map_vetraio.tres did not load")
	assert_eq(_map.spawn_count(), int(_t.spawn_point_count), "the map is not six spawns")


## How many spawn points are at least `TUN-RESPAWN-MIN-DIST-FROM-KILLER` from a
## camper standing at `at` — that is, how many rule 2 still allows.
func _valid_from(at: Vector3) -> int:
	var n := 0
	for point: Vector3 in _map.spawn_points:
		if SpawnRules.clear_of_killer(point, at, _t):
			n += 1
	return n


func test_the_constraint_bites_somewhere_at_all() -> void:
	# **THE COUNTERFACTUAL, AND IT IS NOT OPTIONAL HERE.** Every assertion in this
	# file is of the form "at least three remain", which a rule that excludes
	# nothing satisfies perfectly — measured: planting `clear_of_killer` to always
	# return true leaves this whole file green. So the first thing to establish is
	# that the constraint excludes anything anywhere.
	#
	# This file is about the **map**; `test_spawn_constraints.gd` is what guards the
	# rule. Without this assertion it would not even notice the rule was gone.
	var most_covered := 0
	for point: Vector3 in _map.spawn_points:
		most_covered = maxi(most_covered, _map.spawn_count() - _valid_from(point))
	assert_gt(
		most_covered,
		0,
		"no camping position excludes a single spawn; TUN-RESPAWN-MIN-DIST-FROM-KILLER is inert"
	)


func test_no_camping_position_leaves_fewer_than_three_spawns() -> void:
	var worst := _map.spawn_count()
	var worst_at := Vector3.ZERO
	var samples := 0
	var x := 0.0
	while x <= 120.0:
		var z := 0.0
		while z <= 120.0:
			var here := Vector3(x, 0.0, z)
			var valid := _valid_from(here)
			samples += 1
			if valid < worst:
				worst = valid
				worst_at = here
			z += GRID
		x += GRID
	gut.p("swept %d positions; worst is %d valid spawns at %v" % [samples, worst, worst_at])
	assert_gt(samples, 3000, "the sweep covered %d positions; it is not a sweep" % samples)
	assert_gte(
		worst,
		3,
		(
			"a camper at %v leaves only %d valid spawns.\n" % [worst_at, worst]
			+ "GDD-05 §2.7's anti-camp analysis concludes three, and it is what makes\n"
			+ "camping unviable together with TUN-RESPAWN-INVULN and the fact that a\n"
			+ "camper is standing still while their own pursuer hunts them."
		)
	)


func test_the_documented_four_positions_still_read_as_the_table_says() -> void:
	# §2.7's own rows, kept because the sweep above reports a minimum and the table
	# claims specific numbers for specific places. If the sweep ever disagreed with
	# these, the table would be the thing to re-derive.
	var worst := _map.spawn_count()
	for at: Vector3 in [
		Vector3(60.0, 0.0, 20.0),  # Piazza del Vetro, centre-north
		Vector3(60.0, 0.0, 60.0),  # Piazza Secca, centre
		Vector3(60.0, 0.0, 100.0),  # Fondaco, south
		Vector3(104.0, 0.0, 40.0),  # Campanile base
	]:
		worst = mini(worst, _valid_from(at))
	assert_gte(worst, 3, "one of §2.7's four named camping positions covers four spawns")


func test_two_campers_cannot_cover_the_map_between_them() -> void:
	# **THE CASE THE TABLE DOES NOT MODEL.** Camping is priced against one player
	# standing still; two coordinating is a different claim, and it is worth
	# knowing whether the geometry survives it. Reported rather than asserted at a
	# threshold, because the design has never committed to a number here.
	var worst := _map.spawn_count()
	var worst_pair := ""
	for i: int in _map.spawn_count():
		for j: int in range(i + 1, _map.spawn_count()):
			var n := 0
			for point: Vector3 in _map.spawn_points:
				var a := SpawnRules.clear_of_killer(point, _map.spawn_points[i], _t)
				var b := SpawnRules.clear_of_killer(point, _map.spawn_points[j], _t)
				if a and b:
					n += 1
			if n < worst:
				worst = n
				worst_pair = "S%d + S%d" % [i + 1, j + 1]
	gut.p("two campers on spawn points: worst is %d valid spawns (%s)" % [worst, worst_pair])
	assert_gt(worst, 0, "two campers standing on spawn points can cover every spawn on the map")
