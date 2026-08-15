## **WHERE NPCs CAN GO, AND WHERE THEY MUST NOT.** US-0041, US-0012, TDD-08 §7.
##
## An integration test because it needs a live `NavigationServer3D` map: the
## baked resource is only half the claim, and a mesh that loads but never syncs
## into a navigation map is a mesh nothing can path on.
##
## **THE TWO HALVES ARE ONE DESIGN FACT.** Every street-level area a player can
## reach must be navigable, or a player standing there is alone by construction
## and the crowd cannot hide them (level-design Pillar B). Roofs and balconies
## must **not** be — which is precisely why standing there costs anonymity
## (`TUN-SUSPICION-GAIN-ROOF`). A navmesh that crept onto a roof would quietly
## refund a cost the design charges deliberately.
extends GutTest

const NAVMESH := "res://data/maps/map_vetraio_navmesh.tres"

## US-0041's test note: a 2 m grid over the playable street area.
const GRID := 2.0

## How far a sample may be from the navmesh and still count as covered. Generous
## on purpose — a baked mesh is inset by the agent radius, so a point 0.4 m from
## a wall is legitimately off-mesh without being unreachable.
const COVERED := 1.2

var _map: RID
var _region: RID
var _map_ready := false


## Stand the navigation map up, once, and **wait until the server says it has
## finished an iteration** rather than guessing a frame count.
##
## **THIS COST AN HOUR AND THE ENGINE ANSWERED IT.** An unsynced map returns the
## origin for every query, so the first version of this file reported **2011 of
## 2011 street points unreachable** — a timing defect wearing a level defect's
## clothes, and the most convincing possible way to look like a broken bake.
## Two awaited physics frames were not enough and twelve were; `map_force_update`
## alone did nothing. Godot's own warning names the deterministic check:
## *"map_get_iteration_id() can be used to check if a map has finished its newest
## iteration"*. Bounded, so a genuinely broken map fails rather than hangs.
##
## `before_all()` is not used, because its coroutine returns at the first `await`
## and the tests start anyway — which is why the LAST test in the file passed
## while the first did not.
func _ready_map() -> void:
	if _map_ready:
		return
	var mesh: NavigationMesh = load(NAVMESH)
	assert_not_null(mesh, "the baked navmesh is missing — run tools/generate_map_vetraio.gd")

	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(_map, true)
	NavigationServer3D.map_set_cell_size(_map, mesh.cell_size)
	# **THE MAP'S CELL HEIGHT MUST MATCH THE MESH'S.** Godot defaults the map to
	# 0.25 while this mesh bakes at 0.2, and the mismatch causes rasterisation
	# errors on mesh edges — the engine warns, and a warning in a test run is a
	# line nobody reads.
	NavigationServer3D.map_set_cell_height(_map, mesh.cell_height)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_region, _map)
	NavigationServer3D.region_set_navigation_mesh(_region, mesh)

	# **POLL THE ANSWER, NOT A PROXY FOR IT.** `map_get_iteration_id` advances
	# once before the map is queryable — measured 0 -> 1 -> 2, with the mesh only
	# usable at the second — so waiting for "the id changed" breaks one step too
	# early. Waiting until a known street point resolves is the property actually
	# needed, and it cannot be off by one.
	# **WAIT ON THE ITERATION COUNTER, NOT ON A QUERY.** Querying before the first
	# synchronisation is an *error*, not merely a wrong answer, so polling with
	# `map_get_closest_point` fills the log with failures on the way to succeeding.
	# **TWO ITERATIONS, MEASURED.** The first registers the region; the mesh is not
	# rasterised into the map until the second, and a query before that is an
	# *error* rather than a wrong answer. Waiting for a single advance breaks one
	# step early and every street point reads as unreachable — which looks exactly
	# like a broken bake and is the most convincing wrong answer available.
	var started: int = NavigationServer3D.map_get_iteration_id(_map)
	for _i: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_map) >= started + 2:
			break
	_map_ready = true


func after_all() -> void:
	if _map_ready:
		NavigationServer3D.free_rid(_region)
		NavigationServer3D.free_rid(_map)


func _closest(point: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(_map, point)


func test_the_navmesh_actually_loaded() -> void:
	# **GUARDS EVERY ASSERTION BELOW.** An empty map answers every query with the
	# origin; "nothing is covered" and "nothing was loaded" would look identical.
	await _ready_map()
	var mesh: NavigationMesh = load(NAVMESH)
	assert_gt(mesh.get_polygon_count(), 50, "the baked navmesh has almost no polygons")
	assert_ne(_closest(Vector3(45.0, 0.0, 15.0)), Vector3.ZERO, "the navigation map is empty")


func test_the_bake_used_the_agent_dimensions_tdd_08_specifies() -> void:
	# **AND THAT THEY SURVIVED QUANTISATION.** Recast ceils `agent_radius` and
	# `agent_height` to whole cells: at Godot's default 0.25 the 0.4 m radius bakes
	# as 0.5 and the 1.8 m height as 2.0, and **only a warning says so**. The cell
	# size divides both exactly, and this is where that stays true.
	var mesh: NavigationMesh = load(NAVMESH)
	assert_almost_eq(mesh.agent_radius, VetraioLayout.NAV_AGENT_RADIUS, 0.001)
	assert_almost_eq(mesh.agent_height, VetraioLayout.NAV_AGENT_HEIGHT, 0.001)
	assert_almost_eq(mesh.agent_max_slope, VetraioLayout.NAV_MAX_SLOPE, 0.001)

	var radius_cells := mesh.agent_radius / mesh.cell_size
	var height_cells := mesh.agent_height / mesh.cell_height
	assert_almost_eq(
		radius_cells, roundf(radius_cells), 0.0001, "agent_radius is not a whole cells"
	)
	assert_almost_eq(height_cells, roundf(height_cells), 0.0001, "agent_height is not whole cells")


func test_every_street_level_floor_is_covered() -> void:
	# **LEVEL-DESIGN PILLAR B.** A reachable place with no crowd is a place a
	# player is alone by construction.
	await _ready_map()
	var missed: PackedStringArray = []
	var sampled := 0
	for floor_row: Array in VetraioLayout.FLOORS:
		if not is_equal_approx(float(floor_row[5]), VetraioLayout.STREET_Y):
			continue  # the Loggia balcony is deliberately not navigable
		var x0: float = floor_row[1]
		var z0: float = floor_row[2]
		# Inset by the agent radius: the mesh is legitimately inset from every
		# wall, so sampling the exact edge would fail for a correct bake.
		var inset := VetraioLayout.NAV_AGENT_RADIUS * 2.0
		var x := x0 + inset
		while x < x0 + float(floor_row[3]) - inset:
			var z := z0 + inset
			while z < z0 + float(floor_row[4]) - inset:
				var point := Vector3(x, VetraioLayout.STREET_Y, z)
				sampled += 1
				if _closest(point).distance_to(point) > COVERED:
					missed.append("%s at (%.0f, %.0f)" % [floor_row[0], x, z])
				z += GRID
			x += GRID

	gut.p(
		"sampled %d street points on a %.0f m grid, %d uncovered" % [sampled, GRID, missed.size()]
	)
	assert_gt(sampled, 400, "the sampler covered almost nothing — the grid or the table moved")
	# A handful of misses is expected: the canal cuts through two floor rectangles
	# and stalls stand on a third, and neither is walkable.
	assert_lt(
		float(missed.size()) / float(sampled),
		0.15,
		"more than 15 %% of the street is unreachable:\n" + "\n".join(missed)
	)


func test_no_roof_is_navigable() -> void:
	# **THE NAVMESH BOUNDARY AND THE ROOF SUSPICION PENALTY ARE THE SAME RULE.**
	# NPCs cannot reach roofs, which is why standing on one costs anonymity.
	await _ready_map()
	var on_roof: PackedStringArray = []
	for block: Array in VetraioLayout.BLOCKS:
		var centre := Vector3(
			float(block[1]) + float(block[3]) * 0.5,
			VetraioLayout.ROOF_Y,
			float(block[2]) + float(block[4]) * 0.5
		)
		var nearest := _closest(centre)
		if absf(nearest.y - VetraioLayout.ROOF_Y) < 1.0:
			on_roof.append("%s roof at %v" % [block[0], nearest])
	assert_eq(on_roof.size(), 0, "the navmesh reaches a roof:\n" + "\n".join(on_roof))


func test_no_market_stall_can_be_walked_onto() -> void:
	# **A STALL COUNTER IS `H_VAULT` 0.9 M AND GODOT'S DEFAULT `agent_max_climb` IS
	# ALSO 0.9.** The baker therefore connected every stall top to the street and the
	# crowd treated the market as furniture — found by watching an NPC finish a run
	# standing on StallA at (38.3, 0.90, 18.6), which no test was asking about.
	#
	# Two reasons it must not: a civilian standing on a stall reads as a broken NPC,
	# and 0.9–1.1 m is the **vault** band — the stalls are the things a player
	# vaults, and a crowd that could stand on them would make being up there
	# ordinary and quietly cost the elevation its meaning.
	#
	# **REACHABILITY, NOT EXISTENCE.** `NAV_MAX_CLIMB` 0.4 leaves the stall top baked
	# as an island — it is a flat walkable surface with clearance, and Recast bakes
	# what it is given — but disconnects it, so nothing can path there. That is the
	# property that matters, and asserting the polygon's absence instead would demand
	# a bake filter the level does not have.
	await _ready_map()
	var street := Vector3(38.0, VetraioLayout.STREET_Y, 15.0)
	var reachable: PackedStringArray = []
	for stall: Array in VetraioLayout.STALLS:
		var top := Vector3(
			float(stall[1]) + float(stall[3]) * 0.5,
			VetraioLayout.H_VAULT,
			float(stall[2]) + float(stall[4]) * 0.5
		)
		# **HEIGHT SEPARATES THE TWO ANSWERS CLEANLY, AND DISTANCE DOES NOT.** The
		# navmesh sits 0.4 m above what it was baked from, so a path that stops on
		# the street in front of a stall ends at y = 0.4 and one that climbs it would
		# end at 1.3. A 3D distance tolerance conflates the two: the first version of
		# this assertion called a path ending 1.4 m *short* of the stall a success at
		# reaching it.
		var path := NavigationServer3D.map_get_path(_map, street, top, true)
		if path.size() > 0 and path[path.size() - 1].y >= VetraioLayout.H_VAULT:
			reachable.append("%s top, path ends at %v" % [stall[0], path[path.size() - 1]])
	var joined := "\n".join(reachable)
	assert_eq(reachable.size(), 0, "the crowd can walk onto a market stall:\n" + joined)


func test_the_balcony_is_not_navigable() -> void:
	# The Loggia balcony is a `FLOORS` row like any other — the only thing keeping
	# it off the mesh is the bake ceiling, so it is worth its own assertion.
	await _ready_map()
	var point := Vector3(60.0, VetraioLayout.BALCONY_Y, 38.0)
	var nearest := _closest(point)
	assert_gt(
		absf(nearest.y - VetraioLayout.BALCONY_Y),
		1.0,
		"the navmesh reaches the Loggia balcony at %v" % nearest
	)


func test_the_canal_is_not_navigable() -> void:
	# The canal has no floor at all, so this asserts the absence rather than an
	# exclusion — but a future floor slab across it would be caught here.
	await _ready_map()
	var centre := Vector3(
		VetraioLayout.CANAL.position.x + VetraioLayout.CANAL.size.x * 0.5,
		VetraioLayout.STREET_Y,
		VetraioLayout.CANAL.position.y + VetraioLayout.CANAL.size.y * 0.5
	)
	var nearest := _closest(centre)
	gut.p("canal centre %v -> nearest navmesh point %v" % [centre, nearest])
	assert_gt(nearest.distance_to(centre), 1.0, "the navmesh crosses the canal")
