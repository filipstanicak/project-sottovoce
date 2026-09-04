## Builds MAP-SANDBOX and its MapData from SandboxLayout.
##
##     godot --headless --path . -s res://tools/generate_map_sandbox.gd
##
## GENERATED, NOT AUTHORED BY HAND, for `generate_map_vetraio.gd`'s reason: a
## hand-placed box is a dimension nothing checks. The layout table is the single
## source and both the scenes and the MapData derive from it, so a test that checks
## the table is checking what shipped. **Trap 1 applies: hand-edits to
## `scenes/map/map_sandbox*.tscn` or `data/maps/map_sandbox*.tres` are silently
## reverted on the next run.**
##
## **THE PLUMBING IS `MapBuild`'s AND THAT IS NOT TIDINESS.** A bench baked with a
## different agent radius, cell size or climb height is a bench the pawn traverses
## differently — so a defect reproduced here would not be the defect. One set of
## bake settings, shared with the district.
##
## **WHAT THIS GENERATOR DOES NOT DO**, where the district's does: no zones, no
## circuits, no theatre spaces, no blend props, no derived parapets and no canal.
## The perimeter is four ordinary walls, which is what a courtyard has.
extends SceneTree

const SCENE_OUT := "res://scenes/map/map_sandbox.tscn"
const COLLISION_OUT := "res://scenes/map/map_sandbox_collision.tscn"
const DATA_OUT := "res://data/maps/map_sandbox.tres"
const NAVMESH_OUT := "res://data/maps/map_sandbox_navmesh.tres"

var _build := MapBuild.new(true)


## **THE BAKE NEEDS A LIVE TREE, SO THE WHOLE RUN IS DEFERRED.** `_init()` fires
## while the `SceneTree` is still being constructed: a node added to the root there
## is not yet *inside* the tree, and `parse_source_geometry_data` refuses it.
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


func _write_everything() -> MapData:
	if not MapBuild.save_scene(_build_scene(true), SCENE_OUT):
		return null

	var navmesh := MapBuild.bake(self, _build_scene(false), SandboxLayout.MAP_SIZE)
	if navmesh == null:
		return null
	if ResourceSaver.save(navmesh, NAVMESH_OUT) != OK:
		push_error("failed to save %s" % NAVMESH_OUT)
		return null
	if not MapBuild.save_scene(_build_scene(false, navmesh), COLLISION_OUT):
		return null

	var data := _build_data()
	if ResourceSaver.save(data, DATA_OUT) != OK:
		push_error("failed to save %s" % DATA_OUT)
		return null
	return data


## **THE EMPTY FIELDS ARE THE DESIGN, NOT AN OMISSION.** `zones`, `circuits`,
## `blend_props`, `theatre_spaces` and `navmesh_exclusions` are left empty: a
## procession needs a district to walk around and a zone exists to carry a density
## this map does not claim. `CrowdFormations.form()` already refuses to make a group
## the crowd cannot spare, so an empty circuit list is a crowd that stands and
## strolls — which is what a bench wants.
func _build_data() -> MapData:
	var data := MapData.new()
	data.id = MapCatalogue.id_of("sandbox")
	data.display_key = &"ui.map.sandbox"
	data.bounds = AABB(
		Vector3.ZERO,
		Vector3(SandboxLayout.MAP_SIZE, SandboxLayout.WALL_HEIGHT, SandboxLayout.MAP_SIZE)
	)
	for s: Array in SandboxLayout.SPAWNS:
		data.spawn_points.append(Vector3(s[1], VetraioLayout.STREET_Y, s[2]))
	data.idle_anchors = SandboxLayout.anchors()
	return data


func _build_scene(with_meshes: bool = true, navmesh: NavigationMesh = null) -> Node3D:
	_build = MapBuild.new(with_meshes)
	var root := Node3D.new()
	root.name = "MapSandbox" if with_meshes else "MapSandboxCollision"

	var geometry := Node3D.new()
	geometry.name = "Geometry"
	root.add_child(geometry)
	geometry.owner = root

	_add_geometry(geometry, root)
	MapBuild.add_region(root, navmesh)
	return root


func _add_geometry(geometry: Node3D, root: Node3D) -> void:
	# A floor HANGS BELOW its surface, it does not straddle it — see `FLOORS`.
	for f: Array in SandboxLayout.FLOORS:
		_build.add_box(
			geometry,
			root,
			f[0],
			Vector3(f[1], f[5] - MapBuild.FLOOR_THICKNESS, f[2]),
			Vector3(f[3], MapBuild.FLOOR_THICKNESS, f[4]),
			f[6]
		)
	for b: Array in SandboxLayout.BLOCKS:
		_build.add_box(
			geometry, root, b[0], Vector3(b[1], 0.0, b[2]), Vector3(b[3], b[5], b[4]), b[6]
		)
	for s: Array in SandboxLayout.STALLS:
		_build.add_box(
			geometry,
			root,
			s[0],
			Vector3(s[1], 0.0, s[2]),
			Vector3(s[3], VetraioLayout.H_VAULT, s[4]),
			"MAT-VAULT"
		)


func _report(data: MapData) -> void:
	print(
		(
			"sandbox: %.0f x %.0f m, %d blocks, %d stalls, %d spawns, %d anchors"
			% [
				SandboxLayout.MAP_SIZE,
				SandboxLayout.MAP_SIZE,
				SandboxLayout.BLOCKS.size(),
				SandboxLayout.STALLS.size(),
				data.spawn_points.size(),
				data.idle_anchors.size()
			]
		)
	)
