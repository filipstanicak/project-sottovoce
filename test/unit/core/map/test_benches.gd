## **THE DISTRICT HAS BENCHES, AND EVERY SEAT IS SOMEWHERE A FIGURE CAN BE.** US-0103.
##
## `MAP-VETRAIO` had no bench at all until 2026-10-04, so the static prop blend GDD-03
## §4.1.3 names, and the sitting §6.3 rule 7 asks clones to do, had nowhere to happen.
## These hold the seats to the bench table they are derived from, the way the lean
## spots are held to the stalls.
extends GutTest


func test_every_bench_gives_its_seats() -> void:
	var seats := VetraioGround.bench_seat_points()
	assert_eq(
		seats.size(),
		VetraioLayout.BENCHES.size() * VetraioLayout.BENCH_SEATS,
		"a seat fell off a floor or into a mass"
	)


func test_every_seat_is_in_front_of_its_bench_and_clear_of_it() -> void:
	for b: Array in VetraioLayout.BENCHES:
		var footprint := Rect2(float(b[1]), float(b[2]), float(b[3]), float(b[4]))
		var mine := VetraioGround.bench_seat_points().filter(
			func(row: Array) -> bool: return str(row[0]).begins_with(str(b[0]))
		)
		assert_eq(mine.size(), VetraioLayout.BENCH_SEATS, "%s lost a seat" % b[0])
		for row: Array in mine:
			var at := Vector2(float(row[1]), float(row[2]))
			assert_false(footprint.has_point(at), "%s is inside its bench" % row[0])
			var ahead := at.y > footprint.end.y if int(b[5]) > 0 else at.y < footprint.position.y
			assert_true(ahead, "%s is behind its bench, facing the wrong way" % row[0])


func test_a_bench_is_cut_from_the_navmesh_rather_than_climbed() -> void:
	assert_gt(VetraioLayout.H_BENCH, PawnNavigation.NAV_MAX_CLIMB, "agents would walk over it")
	assert_false(VetraioLayout.in_boundary_band(VetraioLayout.H_BENCH))


func test_no_anchor_or_spawn_stands_on_a_bench() -> void:
	var data: MapData = load(MapCatalogue.data_path(&"vetraio"))
	assert_not_null(data, "the district's map data did not load")
	for point: Vector3 in data.idle_anchors + data.spawn_points:
		assert_eq(VetraioGround.bench_at(Vector2(point.x, point.z)), "", "%s is on a bench" % point)


func test_the_seats_reach_the_map_after_the_lean_spots() -> void:
	# The lean spots keep their indices, so an NPC's held counter means the same spot
	# before and after benches were added.
	var data: MapData = load(MapCatalogue.data_path(&"vetraio"))
	var leans := VetraioGround.stall_lean_points()
	var seats := VetraioGround.bench_seat_points()
	assert_eq(data.static_props.size(), leans.size() + seats.size())
	for i: int in seats.size():
		var expected := Vector3(float(seats[i][1]), VetraioLayout.STREET_Y, float(seats[i][2]))
		assert_eq(data.static_props[leans.size() + i], expected, "the committed map is stale")
