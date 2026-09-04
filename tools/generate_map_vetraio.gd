## Builds the MAP-VETRAIO greybox and its MapData from VetraioLayout.
##
##     godot --headless -s res://tools/generate_map_vetraio.gd
##
## GENERATED, NOT AUTHORED BY HAND, for the same reason the tuning classes are: a
## hand-placed box is a dimension nothing checks. The layout table is the single
## source and both the scene and the MapData derive from it, so a test that checks
## the table is checking what shipped.
extends SceneTree

const SCENE_OUT := "res://scenes/map/map_vetraio.tscn"

## Collision and navmesh only, no meshes. THE DEDICATED SERVER LOADS THIS ONE.
## The server needs to know where the walls are; it has no reason to hold a
## MeshInstance3D for every one of them, and TDD-12 §3 excludes assets from the
## server export except map collision and navmesh.
const COLLISION_OUT := "res://scenes/map/map_vetraio_collision.tscn"
const DATA_OUT := "res://data/maps/map_vetraio.tres"
const NAVMESH_OUT := "res://data/maps/map_vetraio_navmesh.tres"

## The shared plumbing: boxes, the bake settings, and a byte-stable scene write.
var _build := MapBuild.new(true)


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

	var data := _write_everything()
	if data == null:
		quit(1)
		return
	_report(data)
	quit(0)


## Both scenes, the navmesh and the MapData. Null on any failure.
##
## **THE BAKE COMES BEFORE THE COLLISION SCENE IS SAVED**, because the region
## carrying the baked mesh goes *into* that scene. A navmesh nothing publishes is one
## no agent can path on: every query answers the origin and the whole crowd is placed
## at (0, 0, 0) — a missing node wearing a placement bug's clothes.
func _write_everything() -> MapData:
	if not MapBuild.save_scene(_build_scene(true), SCENE_OUT):
		return null

	var navmesh := MapBuild.bake(self, _build_scene(false), VetraioLayout.MAP_SIZE)
	if navmesh == null:
		return null
	if ResourceSaver.save(navmesh, NAVMESH_OUT) != OK:
		push_error("failed to save %s" % NAVMESH_OUT)
		return null
	if not MapBuild.save_scene(_build_scene(false, navmesh), COLLISION_OUT):
		return null

	var data := MapDataBuilder.build()
	if ResourceSaver.save(data, DATA_OUT) != OK:
		push_error("failed to save %s" % DATA_OUT)
		return null
	return data


func _report(data: MapData) -> void:
	print(
		(
			"map: %d blocks, %d floors, %d stalls, %d spawns, %d circuits, %d anchors, %d + %d props"
			% [
				VetraioLayout.BLOCKS.size(),
				VetraioLayout.FLOORS.size(),
				VetraioLayout.STALLS.size(),
				data.spawn_points.size(),
				data.circuits.size(),
				data.idle_anchors.size(),
				data.blend_props.size(),
				data.static_props.size()
			]
		)
	)


func _build_scene(with_meshes: bool = true, navmesh: NavigationMesh = null) -> Node3D:
	_build = MapBuild.new(with_meshes)
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

	MapBuild.add_region(root, navmesh)
	return root


## Every solid the layout declares. Split out of _build_scene because the arch
## guard caps a function at 40 lines, and four loops in one function was four
## things.
func _add_geometry(geometry: Node3D, root: Node3D) -> void:
	# **A FLOOR HANGS BELOW ITS SURFACE, IT DOES NOT STRADDLE IT.** `FLOORS` gives the
	# walkable SURFACE height and the slab must end there. Centring it instead put
	# every walkable top 0.1 m high, so the 0.9 m stall counters sat only 0.80 m above
	# a pawn's feet, the 0.85 m waist probe passed over them, and traverse at a market
	# stall did nothing at all.
	for f: Array in VetraioLayout.FLOORS:
		_build.add_box(
			geometry,
			root,
			f[0],
			Vector3(f[1], f[5] - MapBuild.FLOOR_THICKNESS, f[2]),
			Vector3(f[3], MapBuild.FLOOR_THICKNESS, f[4]),
			f[6]
		)
	for b: Array in VetraioLayout.BLOCKS:
		_build.add_box(
			geometry, root, b[0], Vector3(b[1], 0.0, b[2]), Vector3(b[3], b[5], b[4]), b[6]
		)
	_add_parapets(geometry, root)
	_add_furniture(geometry, root)


## The market stalls and the blend props: everything at `H_VAULT` that a player can
## get over rather than round. Split from `_add_geometry` when moving the box
## builder into `MapBuild` reflowed that function past the 40-line cap — and the
## seam is honest rather than mechanical, because these two are the only solids on
## the map a pawn interacts with instead of being stopped by.
func _add_furniture(geometry: Node3D, root: Node3D) -> void:
	for s: Array in VetraioLayout.STALLS:
		_build.add_box(
			geometry,
			root,
			s[0],
			Vector3(s[1], 0.0, s[2]),
			Vector3(s[3], VetraioLayout.H_VAULT, s[4]),
			"MAT-VAULT"
		)
	for p: Array in VetraioLayout.BLEND_PROPS:
		_build.add_box(
			geometry,
			root,
			"Prop_" + String(p[0]),
			Vector3(float(p[1]) - 0.8, 0.0, float(p[2]) - 0.8),
			Vector3(1.6, VetraioLayout.H_VAULT, 1.6),
			"MAT-BLEND"
		)


## Every floor edge bordering a drop, derived rather than listed. See VetraioGround.
func _add_parapets(geometry: Node3D, root: Node3D) -> void:
	for w: Array in VetraioGround.parapets():
		var corner := Vector3(w[1], 0.0, w[2])
		_build.add_box(geometry, root, w[0], corner, Vector3(w[3], w[5], w[4]), "MAT-VAULT")
