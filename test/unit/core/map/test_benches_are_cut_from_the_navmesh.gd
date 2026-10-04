## **THE BAKED MESH GOES ROUND EVERY BENCH, AND EVERY SEAT CAN STILL BE REACHED.** US-0103,
## review of #251.
##
## The first version carried the claim in a number: `H_BENCH` 0.45 > `NAV_MAX_CLIMB` 0.4,
## so the bake must cut the benches out. It did not — the navmesh rasterises heights in
## 0.2 m cells, the seat landed on the climb's two cells, and civilian paths ran straight
## through every bench. A test comparing two constants could not see that. These ask the
## committed mesh itself, loaded into a navigation map of their own.
extends GutTest

const NAVMESH := "res://data/maps/map_vetraio_navmesh.tres"
## How much of the agent radius the mesh may give back. The carve is the footprint grown
## by the full radius, and the bake simplifies a carved edge afterwards, which moves it
## by up to about a cell (`NAV_CELL_SIZE` 0.2).
const SLACK := 0.15
## How far from a seat the mesh may end. A seat stands one agent radius in front of its
## bench, which is exactly the carved boundary.
const SEAT_GAP := 0.35

var _map: RID
var _region: RID


func before_all() -> void:
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_map, PawnNavigation.NAV_CELL_SIZE)
	NavigationServer3D.map_set_cell_height(_map, PawnNavigation.NAV_CELL_HEIGHT)
	NavigationServer3D.map_set_active(_map, true)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_region, _map)
	NavigationServer3D.region_set_navigation_mesh(_region, load(NAVMESH) as NavigationMesh)
	# Until the region is in the map, not merely until the map has iterated once: the
	# first iteration can be of an empty map, which answers everything with the origin.
	for _i: int in 240:
		await get_tree().physics_frame
		var p := NavigationServer3D.map_get_closest_point(_map, Vector3(60, 0, 15))
		if Vector2(p.x - 60, p.z - 15).length() < 1.0:
			break


func after_all() -> void:
	NavigationServer3D.free_rid(_region)
	NavigationServer3D.free_rid(_map)


func _footprint(b: Array, grow: float) -> Rect2:
	return Rect2(float(b[1]), float(b[2]), float(b[3]), float(b[4])).grow(grow)


func test_the_map_is_live() -> void:
	# PREMISE. An unsynchronised map answers every query with the origin, and every
	# assertion below would pass over it.
	assert_gt(NavigationServer3D.map_get_iteration_id(_map), 0, "the map never synchronised")
	var p := NavigationServer3D.map_get_closest_point(_map, Vector3(60, 0, 15))
	assert_lt(Vector2(p.x - 60, p.z - 15).length(), 1.0, "the piazza is not on the mesh")


func test_nothing_inside_a_bench_is_walkable() -> void:
	var r := PawnNavigation.NAV_AGENT_RADIUS - SLACK
	for b: Array in VetraioLayout.BENCHES:
		var inside := _footprint(b, 0.0)
		for i: int in 5:
			for j: int in 3:
				var at := Vector3(
					inside.position.x + inside.size.x * (i + 0.5) / 5.0,
					0.4,
					inside.position.y + inside.size.y * (j + 0.5) / 3.0
				)
				var p := NavigationServer3D.map_get_closest_point(_map, at)
				assert_false(
					_footprint(b, r).has_point(Vector2(p.x, p.z)),
					"%s: the mesh is walkable at %s, inside the bench" % [b[0], p]
				)


func test_a_route_across_a_bench_goes_round_it_with_clearance() -> void:
	var r := PawnNavigation.NAV_AGENT_RADIUS - SLACK
	for b: Array in VetraioLayout.BENCHES:
		var foot := _footprint(b, 0.0)
		var x := foot.get_center().x
		var start := Vector3(x, 0.0, foot.position.y - 1.5)
		var goal := Vector3(x, 0.0, foot.end.y + 1.5)
		var path := NavigationServer3D.map_get_path(_map, start, goal, true)
		assert_gt(path.size(), 1, "%s: no route across it at all" % b[0])
		for i: int in range(1, path.size()):
			for k: int in 20:
				var p := path[i - 1].lerp(path[i], k / 20.0)
				assert_false(
					_footprint(b, r).has_point(Vector2(p.x, p.z)),
					"%s: the route passes through it at %s" % [b[0], p]
				)


func test_every_seat_can_still_be_reached() -> void:
	var from := Vector3(60, 0, 15)
	for row: Array in VetraioGround.bench_seat_points():
		var seat := Vector3(float(row[1]), 0.0, float(row[2]))
		var path := NavigationServer3D.map_get_path(_map, from, seat, true)
		assert_gt(path.size(), 1, "%s: no route to it" % row[0])
		if path.size() > 1:
			var end := path[path.size() - 1]
			assert_lt(
				Vector2(end.x - seat.x, end.z - seat.z).length(),
				SEAT_GAP,
				"%s: the route ends %s away" % [row[0], end]
			)
