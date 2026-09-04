## **LOOK AT A MAP FROM ABOVE, BECAUSE NO TEST HERE CAN.** DEBUG TOOL.
##
##     godot --path . res://tools/map_probe.tscn -- --map sandbox
##     godot --path . res://tools/map_probe.tscn -- --map vetraio
##
## A generated map can satisfy every assertion in the suite and still be wrong in
## a way only an eye catches: a wall built from its centre rather than its corner
## sits half its own width out of place, a floor that straddles its declared height
## puts the whole district 0.1 m up, and a nook with its mouth on the wrong side is
## a corner trap nobody can walk into. All three of those have happened here, and
## the last two cost milestones.
##
## **IT BOOTS THE REAL CLIENT ROOT**, so what it photographs is what a player would
## be standing in — the same `MapCatalogue` lookup, the same scene, the same
## lighting. A hand-built preview would prove the preview.
##
## **AND IT MARKS THE SPAWN POINTS**, because the picture that matters is not the
## geometry alone: it is whether the places players appear are inside the walls,
## clear of the blocks and as far apart as the layout claims. A spawn point drawn
## on top of a wall is instantly obvious and is invisible in a coordinate list.
##
## Run it **windowed**. `--headless` renders nothing and would write a blank PNG,
## which reads exactly like a map that failed to load — trap 13.
extends Node

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## High enough to frame a 120 m district; the lens does the rest.
const EYE_HEIGHT := 150.0
const MARKER_RADIUS := 1.2

var _root: Node = null


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless renders nothing, and a blank PNG reads like a broken map.")
		get_tree().quit(1)
		return
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var chosen := _string_after(args, "--map", MapCatalogue.DEFAULT)
	if not MapCatalogue.has(chosen):
		print("no such map: %s. Known: %s" % [chosen, ", ".join(MapCatalogue.names())])
		get_tree().quit(1)
		return

	LaunchConfig.active = LaunchConfig.parse(args, Tuning.match_rules.max_players)
	_root = (load(CLIENT_ROOT) as PackedScene).instantiate()
	# Deferred: `_ready()` runs while the tree is still adding children, and a direct
	# add there fails with "parent node is busy".
	get_tree().get_root().add_child.call_deferred(_root)
	await get_tree().process_frame
	await get_tree().process_frame

	var data := load(MapCatalogue.data_path(chosen)) as MapData
	_mark_the_spawns(data)
	_look_down_at(data)
	# Settled rather than snapped: one frame is before the environment has lit.
	await get_tree().create_timer(1.0).timeout
	_capture(chosen, data)
	get_tree().quit(0)


## **THE RIG IS DISABLED, NOT FREED.** `CameraRig` writes `global_position` every
## rendered frame, so a camera left running would drag the view back to the pawn
## between the placement below and the capture — which reads as a camera that
## cannot be positioned rather than as one being overridden. Freeing it instead was
## the first attempt and it takes `LocalPawnDriver` down with it: the driver holds
## the pawn and steps it every physics frame, so the probe died on a previously
## freed argument. **The pawn is left standing**, and is worth seeing: it is drawn
## at whichever spawn point the client picked.
func _look_down_at(data: MapData) -> void:
	var rig := _find_named(_root, "CameraRig")
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED

	var extent: float = maxf(data.bounds.size.x, data.bounds.size.z)
	var eye := Camera3D.new()
	eye.name = "MapProbeEye"
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	eye.size = extent * 1.1
	eye.far = EYE_HEIGHT * 2.0
	eye.position = Vector3(data.bounds.size.x * 0.5, EYE_HEIGHT, data.bounds.size.z * 0.5)
	eye.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_find_named(_root, "World").add_child(eye)
	eye.current = true


## A post at every spawn point, tall enough to read against the floor from above.
func _mark_the_spawns(data: MapData) -> void:
	var world := _find_named(_root, "World")
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.30, 0.25)
	paint.roughness = 1.0
	for i: int in data.spawn_points.size():
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = MARKER_RADIUS
		cyl.bottom_radius = MARKER_RADIUS
		cyl.height = 6.0
		post.mesh = cyl
		post.material_override = paint
		post.name = "Spawn%d" % i
		post.position = data.spawn_points[i] + Vector3(0.0, 3.0, 0.0)
		world.add_child(post)


func _capture(chosen: String, data: MapData) -> void:
	var path := "user://map_%s.png" % chosen
	get_tree().root.get_texture().get_image().save_png(path)
	print(
		(
			"%s: %.0f x %.0f m, %d spawns, %d idle anchors -> %s"
			% [
				MapCatalogue.id_of(chosen),
				data.bounds.size.x,
				data.bounds.size.z,
				data.spawn_points.size(),
				data.idle_anchors.size(),
				ProjectSettings.globalize_path(path)
			]
		)
	)


static func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child: Node in node.get_children():
		var hit := _find_named(child, wanted)
		if hit != null:
			return hit
	return null


static func _string_after(args: PackedStringArray, flag: String, fallback: String) -> String:
	var at := Array(args).find(flag)
	return str(args[at + 1]) if at >= 0 and at + 1 < args.size() else fallback
