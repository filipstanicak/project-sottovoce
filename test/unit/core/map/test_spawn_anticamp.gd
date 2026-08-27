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


# ------------------------------------------------- a conspiracy of two ----


func test_a_second_camper_is_not_a_second_killer() -> void:
	# **THE CORRECTION, AND IT IS WHY EVERY NUMBER BELOW MOVED.** This file used to
	# ask `clear_of_killer` of **both** campers and published *"two campers on spawn
	# points reduce it to one"*. `SpawnRules.candidates` applies the 40 m rule to
	# exactly one position — the killer's — and `TUN-RESPAWN-MIN-DIST-FROM-ANY-PLAYER`
	# 12 m to everybody else, so that measurement was of a rule the game does not
	# have. **At any one respawn there is exactly one killer**, however many players
	# are standing still.
	var spawn := _map.spawn_points[0]
	var twenty_off := spawn + Vector3(20.0, 0.0, 0.0)
	assert_false(SpawnRules.clear_of_killer(spawn, twenty_off, _t), "20 m is inside 40 m")
	assert_true(
		SpawnRules.clear_of_everyone(spawn, PackedVector3Array([twenty_off]), _t),
		"a living non-killer 20 m away vetoed a spawn; the two radii have merged"
	)


## Which spawns a body standing at `at` denies, as a bitmask — **asked of
## `SpawnRules` rather than recomputed from a radius.**
##
## The first version of this file took the radius as an argument and compared
## distances itself, which made every sweep below a measurement of the rule I
## believed in rather than of the one that ships: planting a 40 m accomplice into
## `clear_of_everyone` left the conspiracy figure reading 2 with nothing red.
func _denied_from(at: Vector3, as_killer: bool) -> int:
	var mask := 0
	var alone := PackedVector3Array([at])
	for i: int in _map.spawn_count():
		var spawn := _map.spawn_points[i]
		var clear := (
			SpawnRules.clear_of_killer(spawn, at, _t)
			if as_killer
			else SpawnRules.clear_of_everyone(spawn, alone, _t)
		)
		if not clear:
			mask |= 1 << i
	return mask


## Every distinct denial mask a body of that radius can produce over the grid.
##
## **THE MASKS ARE THE SEARCH SPACE, NOT THE POSITIONS.** 3 721 samples collapse to
## a handful of distinct answers, so an exhaustive search over conspiracies costs
## the square of that handful rather than the square of the map.
func _masks(as_killer: bool, standable_only: bool) -> Array[int]:
	var seen := {}
	var x := 0.0
	while x <= 120.0:
		var z := 0.0
		while z <= 120.0:
			if not standable_only or VetraioGround.is_standable(Vector2(x, z)):
				seen[_denied_from(Vector3(x, 0.0, z), as_killer)] = true
			z += GRID
		x += GRID
	var out: Array[int] = []
	for mask: int in seen.keys():
		out.append(mask)
	return out


func _bits(mask: int) -> int:
	var n := 0
	for i: int in _map.spawn_count():
		if mask & (1 << i):
			n += 1
	return n


func test_one_living_body_denies_at_most_one_spawn() -> void:
	# **DERIVED FROM RULE 1 RATHER THAN OBSERVED.** One body denies two spawns only
	# if they are within `2 x TUN-RESPAWN-MIN-DIST-FROM-ANY-PLAYER` of each other,
	# and rule 1's own minimum is 30 m. The arithmetic is what holds a conspiracy
	# down, so this goes red if the spawns move together **or** if the tunable is
	# raised past half their separation — which is when somebody must re-read §2.7.
	var closest := INF
	for i: int in _map.spawn_count():
		for j: int in range(i + 1, _map.spawn_count()):
			closest = minf(closest, _map.spawn_points[i].distance_to(_map.spawn_points[j]))
	gut.p("closest spawn pair %.2f m against 2 x %.1f m" % [closest, _t.min_dist_from_any_player])
	assert_gt(closest, 2.0 * _t.min_dist_from_any_player, "one body can now deny two spawns")
	for mask: int in _masks(false, false):
		assert_lte(_bits(mask), 1, "a position denies %d spawns at once" % _bits(mask))


func test_the_worst_camping_position_is_ground_somebody_can_stand_on() -> void:
	# **THE SWEEP ABOVE WALKS THE WHOLE GRID, INCLUDING THE INSIDE OF BUILDINGS.** A
	# worst case established at a position no player can occupy is the `LoggiaPier`
	# retraction's shape — seven "legal" spawn sites, every one of them six metres
	# inside a wall — so the same minimum is taken over standable ground alone.
	var worst := _map.spawn_count()
	for mask: int in _masks(true, true):
		worst = mini(worst, _map.spawn_count() - _bits(mask))
	gut.p("worst camping position a player can actually occupy: %d valid spawns" % worst)
	assert_gte(worst, 3, "standable ground is worse than the whole-grid sweep, which cannot be")


func test_a_killer_and_an_accomplice_leave_at_least_two() -> void:
	var killers := _masks(true, true)
	var bodies := _masks(false, true)
	assert_gt(
		killers.size(), 2, "the killer sweep found %d answers; it is not a sweep" % killers.size()
	)
	var worst := _map.spawn_count()
	for k: int in killers:
		for b: int in bodies:
			worst = mini(worst, _map.spawn_count() - _bits(k | b))
	gut.p(
		(
			"killer + one accomplice on standable ground: worst is %d valid spawns" % worst
			+ " (%d killer masks x %d body masks)" % [killers.size(), bodies.size()]
		)
	)
	assert_gte(worst, 2, "a killer and one accomplice reduce the map to %d spawns" % worst)


func test_a_full_lobby_standing_still_empties_it_and_the_fallback_answers() -> void:
	# **THE WORST ARRANGEMENT THAT EXISTS**, and it is not a conspiracy of two: a
	# body on **every** spawn point denies all six at 12 m, so no lobby can do worse
	# than this and there is nothing left for the killer to add. Rule 7 then places
	# the victim at the point furthest from the killer — the anti-revenge property
	# the 40 m rule exists for, arriving through the fallback instead of the filter.
	var everybody := PackedVector3Array()
	for point: Vector3 in _map.spawn_points:
		everybody.append(point)
	var worst := INF
	var worst_at := Vector3.ZERO
	var x := 0.0
	while x <= 120.0:
		var z := 0.0
		while z <= 120.0:
			var killer := Vector3(x, 0.0, z)
			if VetraioGround.is_standable(Vector2(x, z)):
				var i := SpawnRules.choose(_map.spawn_points, killer, everybody, _t, null)
				assert_eq(SpawnRules.candidates(_map.spawn_points, killer, everybody, _t).size(), 0)
				var away := _map.spawn_points[i].distance_to(killer)
				if away < worst:
					worst = away
					worst_at = killer
			z += GRID
		x += GRID
	gut.p(
		"every spawn denied: the fallback is still %.1f m from a killer at %v" % [worst, worst_at]
	)
	# **AND IT CLEARS RULE 2 ANYWAY, WHICH IS THE FINDING.** From anywhere standable
	# the furthest spawn is over `TUN-RESPAWN-MIN-DIST-FROM-KILLER` away, so on this
	# map the fallback is never worse than the filter it replaces — a lobby that
	# denies every spawn has bought itself nothing at all.
	assert_gt(
		worst,
		_t.respawn_min_dist_from_killer,
		(
			(
				"the fallback drops to %.1f m at %v; denying every spawn is worth something now. "
				% [worst, worst_at]
			)
			+ "Re-read GDD-05 §2.7: the spawns are closer together than its analysis assumes."
		)
	)
