## Builds the MAP-VETRAIO greybox and its MapData from VetraioLayout.
##
##     godot --headless -s res://tools/generate_map_vetraio.gd
##
## GENERATED, NOT AUTHORED BY HAND, for the same reason the tuning classes are:
## every dimension comes from the metrics bible, and a hand-placed box is a
## dimension nothing checks. The layout table is the single source; the scene and
## the MapData are both derived from it, so a test that checks the table is
## checking what shipped.
extends SceneTree

const SCENE_OUT := "res://scenes/map/map_vetraio.tscn"

## Collision and navmesh only, no meshes. THE DEDICATED SERVER LOADS THIS ONE.
## The server needs to know where the walls are; it has no reason to hold a
## MeshInstance3D for every one of them, and TDD-12 §3 excludes assets from the
## server export except map collision and navmesh.
const COLLISION_OUT := "res://scenes/map/map_vetraio_collision.tscn"
const DATA_OUT := "res://data/maps/map_vetraio.tres"
const NAVMESH_OUT := "res://data/maps/map_vetraio_navmesh.tres"

## How far a walkable slab hangs below the surface it declares. Thick enough that
## nothing falls through it, and entirely beneath `FLOORS`' y so the surface is
## exactly the number the layout table gives.
const FLOOR_THICKNESS := 0.2

## Desaturated greybox palette, GDD-05 §7.4. Deliberately avoids the saturated
## identity hues the colour-language law reserves for personas and tells.
## MAT-VOID is absent: it must never appear in a playtest build.
const PALETTE := {
	"MAT-GREY-FLOOR": Color(0.45, 0.45, 0.46),
	"MAT-GREY-WALL": Color(0.62, 0.62, 0.63),
	"MAT-CLIMB": Color(0.38, 0.48, 0.62),
	"MAT-VAULT": Color(0.66, 0.62, 0.36),
	"MAT-BLEND": Color(0.40, 0.58, 0.44),
}

var _materials: Dictionary = {}

## False while building the collision-only variant the dedicated server loads.
var _with_meshes := true


## **THE BAKE NEEDS A LIVE TREE, SO THE WHOLE RUN IS DEFERRED.** `_init()` fires
## while the `SceneTree` is still being constructed: a node added to the root
## there is not yet *inside* the tree, and `parse_source_geometry_data` refuses
## it. One awaited frame is the difference — and it is exactly the reason US-0012
## recorded the bake as owed rather than doing it.
func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://scenes/map")
	DirAccess.make_dir_recursive_absolute("res://data/maps")
	_build_materials()

	var data := _write_everything()
	if data == null:
		quit(1)
		return
	_report(data)
	quit(0)


## Both scenes, the navmesh and the MapData. Null on any failure.
##
## **THE BAKE COMES BEFORE THE COLLISION SCENE IS SAVED**, because the region
## carrying the baked mesh goes *into* that scene. A navmesh resource nothing
## publishes is a navmesh no agent can path on: the world's navigation map stays
## empty, every query answers the origin, and the whole crowd is placed at
## (0, 0, 0) — a missing node wearing a placement bug's clothes.
func _write_everything() -> MapData:
	if not _save_scene(_build_scene(true), SCENE_OUT):
		return null

	var navmesh := _bake_navmesh()
	if navmesh == null:
		return null
	if not _save_scene(_build_scene(false, navmesh), COLLISION_OUT):
		return null

	var data := _build_data()
	if ResourceSaver.save(data, DATA_OUT) != OK:
		push_error("failed to save %s" % DATA_OUT)
		return null
	return data


## The mesh's parameters, TDD-08 §7. Separate from the bake because "what the mesh
## is" and "how it gets built" are two things.
func _navmesh_settings() -> NavigationMesh:
	var mesh := NavigationMesh.new()
	# **CELL SIZE FIRST.** The agent dimensions are quantised against it — and
	# **ceiled** — so assigning them the other way round quantises against Godot's
	# default 0.25 and bakes a 0.4 m radius as 0.5. Only a warning says so.
	mesh.cell_size = VetraioLayout.NAV_CELL_SIZE
	mesh.cell_height = VetraioLayout.NAV_CELL_HEIGHT
	mesh.agent_radius = VetraioLayout.NAV_AGENT_RADIUS
	mesh.agent_height = VetraioLayout.NAV_AGENT_HEIGHT
	mesh.agent_max_slope = VetraioLayout.NAV_MAX_SLOPE
	mesh.agent_max_climb = VetraioLayout.NAV_MAX_CLIMB
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS

	# **THE STREET STRATUM AND NOTHING ABOVE IT.** Roofs, balconies and the
	# campanile are excluded by never being offered to the baker, rather than by
	# being carved out afterwards — a filter that runs second can be forgotten.
	# The canal has no floor to bake in the first place.
	mesh.filter_baking_aabb = AABB(
		Vector3(-1.0, VetraioLayout.NAV_BAKE_FLOOR, -1.0),
		Vector3(
			VetraioLayout.MAP_SIZE + 2.0,
			VetraioLayout.NAV_BAKE_CEILING - VetraioLayout.NAV_BAKE_FLOOR,
			VetraioLayout.MAP_SIZE + 2.0
		)
	)
	return mesh


## **BAKED HERE, NOT AT RUNTIME.** TDD-08 §7: the geometry is static and the mesh
## is never rebaked in a match. US-0012 recorded the bake as owed precisely
## because it needs a live tree — and this generator already runs inside the
## engine, which is the tree it needs.
##
## Baking at startup instead would cost every server seconds of a countdown it
## does not have, and would make a **level** defect appear as a *networking* one:
## clients waiting on a server that looks hung.
func _bake_navmesh() -> NavigationMesh:
	var mesh := _navmesh_settings()

	# **PARSED EXPLICITLY RATHER THAN THROUGH A REGION.** `bake_navigation_mesh()`
	# wants its source root in the scene tree in a way that nesting it under the
	# region does not satisfy; the two-step API says what it needs out loud, which
	# is the whole reason this is worth the extra line.
	var source := _build_scene(false)
	get_root().add_child(source)
	var geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, geometry, source)
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	get_root().remove_child(source)
	source.free()

	if mesh.get_polygon_count() == 0:
		push_error("navmesh baked to zero polygons — the source geometry was not parsed")
		return null
	print("navmesh: %d polygons" % mesh.get_polygon_count())
	if ResourceSaver.save(mesh, NAVMESH_OUT) != OK:
		push_error("failed to save %s" % NAVMESH_OUT)
		return null
	return mesh


func _save_scene(root: Node3D, path: String) -> bool:
	var packed := PackedScene.new()
	if packed.pack(root) != OK or ResourceSaver.save(packed, path) != OK:
		push_error("failed to save %s" % path)
		return false
	return _strip_unique_ids(path)


## Godot stamps every node with a RANDOM `unique_id` on save, so re-running the
## generator produces a 300-line diff in which nothing changed. Stripping them
## makes the committed scenes byte-stable, which is the only way "regenerate and
## check git diff is empty" can be the verification it claims to be.
func _strip_unique_ids(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("could not reopen %s" % path)
		return false
	var text := file.get_as_text()
	file.close()

	var cleaned := RegEx.create_from_string(" unique_id=-?[0-9]+").sub(text, "", true)
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		push_error("could not rewrite %s" % path)
		return false
	out.store_string(cleaned)
	out.close()
	return true


func _report(data: MapData) -> void:
	print(
		(
			"map: %d blocks, %d floors, %d stalls, %d spawns, %d circuits, %d anchors, %d props"
			% [
				VetraioLayout.BLOCKS.size(),
				VetraioLayout.FLOORS.size(),
				VetraioLayout.STALLS.size(),
				data.spawn_points.size(),
				data.circuits.size(),
				data.idle_anchors.size(),
				data.blend_props.size()
			]
		)
	)


func _build_materials() -> void:
	for key: String in PALETTE:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PALETTE[key]
		mat.roughness = 0.9
		mat.resource_name = key
		_materials[key] = mat


func _build_scene(with_meshes: bool = true, navmesh: NavigationMesh = null) -> Node3D:
	_with_meshes = with_meshes
	var root := Node3D.new()
	root.name = "MapVetraio" if with_meshes else "MapVetraioCollision"

	var geometry := Node3D.new()
	geometry.name = "Geometry"
	root.add_child(geometry)
	geometry.owner = root

	_add_geometry(geometry, root)

	# The canal is a hole, not a surface: no floor, and excluded from the navmesh.
	var canal := Node3D.new()
	canal.name = "CanalVolume"
	canal.position = Vector3(
		VetraioLayout.CANAL.position.x + VetraioLayout.CANAL.size.x * 0.5,
		-1.0,
		VetraioLayout.CANAL.position.y + VetraioLayout.CANAL.size.y * 0.5
	)
	root.add_child(canal)
	canal.owner = root

	# **THE REGION IS WHAT PUBLISHES THE MESH.** Without it the world's navigation
	# map is empty and every `map_get_closest_point` answers the origin — so an
	# agent cannot path and a placement snaps every NPC to (0, 0, 0).
	if navmesh != null:
		var region := NavigationRegion3D.new()
		region.name = "NavRegion"
		region.navigation_mesh = navmesh
		root.add_child(region)
		region.owner = root
	return root


## Every solid the layout declares. Split out of _build_scene because the arch
## guard caps a function at 40 lines, and four loops in one function was four
## things.
func _add_geometry(geometry: Node3D, root: Node3D) -> void:
	# **A FLOOR HANGS BELOW ITS SURFACE, IT DOES NOT STRADDLE IT.** `FLOORS` gives
	# the height of the walkable SURFACE — STREET_Y 0.0, BALCONY_Y 3.5 — and the
	# slab has to end there. Centring it on that height instead put every walkable
	# top 0.1 m high, which is one of those errors that is invisible until it is
	# not: the pawn stood at y = 0.10 while the 0.9 m stall counters stayed at
	# 0.90, so they were only 0.80 m above its feet, the 0.85 m waist probe passed
	# over them, and pressing traverse at a market stall did nothing at all.
	for f: Array in VetraioLayout.FLOORS:
		_add_box(
			geometry,
			root,
			f[0],
			Vector3(f[1], f[5] - FLOOR_THICKNESS, f[2]),
			Vector3(f[3], FLOOR_THICKNESS, f[4]),
			f[6]
		)
	for b: Array in VetraioLayout.BLOCKS:
		_add_box(geometry, root, b[0], Vector3(b[1], 0.0, b[2]), Vector3(b[3], b[5], b[4]), b[6])
	for s: Array in VetraioLayout.STALLS:
		_add_box(
			geometry,
			root,
			s[0],
			Vector3(s[1], 0.0, s[2]),
			Vector3(s[3], VetraioLayout.H_VAULT, s[4]),
			"MAT-VAULT"
		)
	for p: Array in VetraioLayout.BLEND_PROPS:
		_add_box(
			geometry,
			root,
			"Prop_" + String(p[0]),
			Vector3(float(p[1]) - 0.8, 0.0, float(p[2]) - 0.8),
			Vector3(1.6, VetraioLayout.H_VAULT, 1.6),
			"MAT-BLEND"
		)


func _add_box(
	parent: Node3D,
	owner_node: Node3D,
	node_name: String,
	corner: Vector3,
	size: Vector3,
	material: String
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = corner + size * 0.5
	parent.add_child(body)
	body.owner = owner_node

	if _with_meshes:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.material_override = _materials.get(material)
		mesh.name = "Mesh"
		body.add_child(mesh)
		mesh.owner = owner_node

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.name = "Collision"
	body.add_child(shape)
	shape.owner = owner_node


func _build_data() -> MapData:
	var data := MapData.new()
	data.id = &"MAP-VETRAIO"
	data.display_key = &"ui.map.vetraio"
	data.bounds = AABB(Vector3.ZERO, Vector3(VetraioLayout.MAP_SIZE, 24.0, VetraioLayout.MAP_SIZE))

	for s: Array in VetraioLayout.SPAWNS:
		data.spawn_points.append(Vector3(s[1], 0.0, s[2]))

	for c: Array in VetraioLayout.CIRCUITS:
		var points := PackedVector3Array()
		for p: Vector2 in c[2]:
			points.append(Vector3(p.x, 0.0, p.y))
		data.circuits.append(points)
		data.circuit_periods.append(c[1])

	for z: Array in VetraioLayout.ZONES:
		var zone := MapZone.new()
		zone.zone_name = StringName(z[0])
		zone.bounds = AABB(Vector3(z[1], 0.0, z[2]), Vector3(z[3], 4.0, z[4]))
		zone.density = z[5]
		zone.is_theatre = z[6]
		data.zones.append(zone)

	for p: Array in VetraioLayout.BLEND_PROPS:
		data.blend_props.append(Vector3(p[1], 0.0, p[2]))

	for t: Array in VetraioLayout.THEATRES:
		data.theatre_spaces.append(AABB(Vector3(t[1], 0.0, t[2]), Vector3(t[3], 6.0, t[4])))

	data.idle_anchors = _place_anchors(data.zones)
	data.navmesh_exclusions = _navmesh_exclusions()
	return data


## Idle anchors per zone at GDD-05 §4.4's density; a theatre gets none.
## **A ZONE THINNER THAN ITS CELL GOT NOTHING, SILENTLY** — `Fondaco`, 120 x 3 m
## at 8.49 spacing, began its row past its own end, so the district's northern
## street had no crowd (US-0096). One row down the middle now, at the declared
## count; the square pitch, which makes a DENSE zone a blend pocket, is kept where
## a cell fits.
func _place_anchors(zones: Array[MapZone]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for zone: MapZone in zones:
		if zone.is_theatre:
			continue
		var wanted := zone.expected_anchors()
		if wanted <= 0:
			continue
		var span := Vector2(zone.bounds.size.x, zone.bounds.size.z)
		var spacing := sqrt((span.x * span.y) / float(wanted))
		var thin := span.y < spacing
		var step := Vector2(span.x / float(wanted), span.y) if thin else Vector2(spacing, spacing)
		var x := zone.bounds.position.x + minf(step.x, span.x) * 0.5
		while x < zone.bounds.end.x:
			var z := zone.bounds.position.z + minf(step.y, span.y) * 0.5
			while z < zone.bounds.end.z:
				out.append(Vector3(x, 0.0, z))
				z += step.y
			x += step.x
	return out


## Roofs, balconies and the canal. NPCs must never reach them — that is exactly
## why standing there costs suspicion (GDD-05 §4.4).
func _navmesh_exclusions() -> Array[AABB]:
	var out: Array[AABB] = []
	out.append(
		AABB(
			Vector3(VetraioLayout.CANAL.position.x, -2.0, VetraioLayout.CANAL.position.y),
			Vector3(VetraioLayout.CANAL.size.x, 4.0, VetraioLayout.CANAL.size.y)
		)
	)
	out.append(
		AABB(
			Vector3(0.0, VetraioLayout.BALCONY_Y - 0.5, 0.0),
			Vector3(VetraioLayout.MAP_SIZE, 24.0, VetraioLayout.MAP_SIZE)
		)
	)
	return out
