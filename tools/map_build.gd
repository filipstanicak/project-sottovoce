## **THE PLUMBING EVERY MAP GENERATOR SHARES.** BUILD-TIME ONLY; nothing in a
## running game loads this file. Extracted from `generate_map_vetraio.gd` on
## 2026-09-04, when `MAP-SANDBOX` needed a second generator.
##
## **THE SEAM IS BETWEEN A RULE AND A MECHANISM.** What shape the district is, where
## a parapet goes and which zone an anchor belongs to are `VetraioLayout`'s and are
## not here. How a box becomes a `StaticBody3D`, what a navmesh is baked with and
## how a scene is written so it reproduces byte-identically are properties of the
## engine and this project, and are the same for every map.
##
## **THE BAKE SETTINGS ARE WHY THIS IS SHARED RATHER THAN COPIED.** A second map
## baked with a different agent radius, cell size or climb height is a map the pawn
## traverses differently — so a sandbox built to reproduce a defect would quietly
## fail to reproduce it. One definition, and both maps get it.
##
## **AND `NAV_AGENT_RADIUS` AND ITS SIBLINGS ARE IN THE WRONG CLASS**, which is
## visible only now there are two maps: they describe the **pawn**, not the
## district, and they sit in `VetraioLayout` because there was one map when they
## were written. Read from there rather than moved — 22 references across 8 files
## and no `TUN-` id among them, so it is a rename with no design content. Reported
## in CLAUDE.md instead of folded into a map story.
class_name MapBuild
extends RefCounted

## How far a walkable slab hangs below the surface it declares. Thick enough that
## nothing falls through it, and entirely beneath the declared y so the surface is
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

## False while building the collision-only variant the dedicated server loads: it
## needs to know where the walls are and has no reason to hold a `MeshInstance3D`
## for every one of them. TDD-12 §3.
var _with_meshes := true


func _init(with_meshes: bool) -> void:
	_with_meshes = with_meshes
	for key: String in PALETTE:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PALETTE[key]
		mat.roughness = 0.9
		mat.resource_name = key
		_materials[key] = mat


## One solid. `corner` is the minimum corner, never the centre — every layout table
## in this project declares rectangles that way, and converting at each call site is
## how a wall ends up half its own width from where the table says it is.
func add_box(
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


## The mesh's parameters, TDD-08 §7. Separate from the bake because "what the mesh
## is" and "how it gets built" are two things. `extent` is the map's square size.
static func navmesh_settings(extent: float) -> NavigationMesh:
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

	# **THE STREET STRATUM AND NOTHING ABOVE IT.** Roofs, balconies and anything else
	# above the street are excluded by never being offered to the baker rather than
	# by being carved out afterwards — a filter that runs second can be forgotten. A
	# canal has no floor to bake in the first place.
	mesh.filter_baking_aabb = AABB(
		Vector3(-1.0, VetraioLayout.NAV_BAKE_FLOOR, -1.0),
		Vector3(
			extent + 2.0,
			VetraioLayout.NAV_BAKE_CEILING - VetraioLayout.NAV_BAKE_FLOOR,
			extent + 2.0
		)
	)
	return mesh


## **BAKED HERE, NOT AT RUNTIME.** TDD-08 §7: the geometry is static and the mesh is
## never rebaked in a match. US-0012 recorded the bake as owed because it needs a
## live tree, and a generator already runs inside one. Baking at startup would cost
## every server seconds of a countdown it does not have, and would make a **level**
## defect appear as a *networking* one — clients waiting on a hung server.
##
## Returns null and pushes an error when nothing parsed, because a mesh of zero
## polygons answers every query with the origin rather than failing.
##
## **`source` IS FREED.** It is added to the root for the parse and cannot be reused.
static func bake(tree: SceneTree, source: Node3D, extent: float) -> NavigationMesh:
	var mesh := navmesh_settings(extent)
	# **PARSED EXPLICITLY RATHER THAN THROUGH A REGION.** `bake_navigation_mesh()`
	# wants its source root in the scene tree in a way that nesting it under the
	# region does not satisfy; the two-step API says what it needs out loud, which is
	# the whole reason this is worth the extra line.
	tree.get_root().add_child(source)
	var geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, geometry, source)
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	tree.get_root().remove_child(source)
	source.free()

	if mesh.get_polygon_count() == 0:
		push_error("navmesh baked to zero polygons — the source geometry was not parsed")
		return null
	print("navmesh: %d polygons" % mesh.get_polygon_count())
	return mesh


## **THE REGION IS WHAT PUBLISHES THE MESH.** Without it the world's navigation map
## is empty and every `map_get_closest_point` answers the origin — so an agent
## cannot path and a placement snaps every NPC to (0, 0, 0).
static func add_region(root: Node3D, navmesh: NavigationMesh) -> void:
	if navmesh == null:
		return
	var region := NavigationRegion3D.new()
	region.name = "NavRegion"
	region.navigation_mesh = navmesh
	root.add_child(region)
	region.owner = root


static func save_scene(root: Node3D, path: String) -> bool:
	var packed := PackedScene.new()
	if packed.pack(root) != OK or ResourceSaver.save(packed, path) != OK:
		push_error("failed to save %s" % path)
		return false
	return strip_unique_ids(path)


## Godot stamps every node with a RANDOM `unique_id` on save, so re-running a
## generator produces a 300-line diff in which nothing changed. Stripping them makes
## the committed scenes byte-stable, which is the only way "regenerate and check
## `git diff` is empty" can be the verification it claims to be.
static func strip_unique_ids(path: String) -> bool:
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
