## **LOOK AT THE FIGURES.** US-0109. DEBUG TOOL.
##
##     godot --path . res://tools/figure_probe.tscn
##
## `test_persona_silhouettes.gd` can say four figures have different boxes. It
## cannot say whether one of them looks like a person, whether a walk reads as a
## walk, or whether a seated figure is on its bench. This stands every figure up
## under the district's own light — the ten shapes at rest, the gaits on a
## treadmill, every act, and a bench and a counter — and photographs them.
##
## Run it **windowed**: headless renders nothing (trap 13).
extends Node

const SPACING := 1.5
## Far enough apart that one row is not behind another in its photograph.
const ROW_GAP := 40.0
const ROWS: Array[String] = ["shapes", "gaits", "acts", "places"]

var _world: Node3D
var _eye: Camera3D
## `[body, velocity]` for each figure that is walked on the spot.
var _walking: Array = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless renders nothing, and a blank PNG reads like a bad figure.")
		get_tree().quit(1)
		return
	_world = Node3D.new()
	add_child(_world)
	_world.add_child(WorldLook.new())
	_ground()
	_stand_the_shapes(0.0)
	_walk_the_gaits(-ROW_GAP)
	_strike_the_acts(-ROW_GAP * 2.0)
	_take_the_places(-ROW_GAP * 3.0)
	_eye = Camera3D.new()
	_eye.fov = 40.0
	_world.add_child(_eye)
	_eye.current = true
	await get_tree().create_timer(2.5).timeout
	for i: int in ROWS.size():
		await _shot(ROWS[i], -ROW_GAP * float(i))
	await _shot_from("walk_side", Vector3(0.0, 1.2, -ROW_GAP + 7.5), Vector3(0.0, 0.95, -ROW_GAP))
	await _shot_from("close", Vector3(-2.6, 1.5, 3.4), Vector3(-3.4, 1.0, 0.0))
	await _shot_from(
		"sit", Vector3(-1.0, 1.4, -ROW_GAP * 3.0 + 4.5), Vector3(-3.0, 0.8, -ROW_GAP * 3.0)
	)
	get_tree().quit()


func _physics_process(delta: float) -> void:
	for pair: Array in _walking:
		(pair[0] as PersonaBody).move(delta, pair[1])


func _ground() -> void:
	var slab := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	slab.mesh = plane
	var materials := WorldMaterials.new(WorldPalette.new())
	slab.material_override = materials.ground
	slab.set_instance_shader_parameter(&"pattern", WorldMaterials.PAVING)
	_world.add_child(slab)


func _figure(id: StringName, at: Vector3, yaw: float = 0.0) -> PersonaBody:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = yaw
	_world.add_child(holder)
	var body := PersonaBody.new()
	body.persona = id
	holder.add_child(body)
	return body


func _everyone() -> Array[StringName]:
	var out: Array[StringName] = [&""]
	out.append_array(CrowdRoster.PLAYABLE)
	out.append_array(CrowdRoster.ARCHETYPES)
	return out


func _stand_the_shapes(z: float) -> void:
	var ids := _everyone()
	for i: int in ids.size():
		_figure(ids[i], Vector3((float(i) - 4.5) * SPACING, 0.0, z))


## Each persona at a different rung of the speed ladder, walked on the spot.
func _walk_the_gaits(z: float) -> void:
	var m := Tuning.movement
	var speeds: Array[float] = [
		m.blend_walk, m.stroll, m.run, m.sprint, m.blend_walk, -m.blend_walk
	]
	var ids := _everyone()
	for i: int in speeds.size():
		# Side on to the camera, so a stride is seen as a stride.
		var body := _figure(ids[i + 1], Vector3((float(i) - 2.5) * SPACING * 1.5, 0.0, z), PI * 0.5)
		body.set_physics_process(false)
		_walking.append([body, Vector3(speeds[i], 0.0, 0.0)])


func _strike_the_acts(z: float) -> void:
	var acts := FigureMotion.Act.values()
	for i: int in acts.size():
		var id := CrowdRoster.PLAYABLE[i % CrowdRoster.PLAYABLE.size()]
		var body := _figure(id, Vector3((float(i) - 5.5) * SPACING, 0.0, z), 0.5)
		body.act(acts[i])


## A bench with three sitters and a counter with two leaning on it.
func _take_the_places(z: float) -> void:
	var materials := WorldMaterials.new(WorldPalette.new())
	_box(
		Vector3(-3.0, 0.225, z - 0.65), Vector3(3.6, 0.45, 0.5), materials.of(WorldMaterials.STONE)
	)
	_box(Vector3(3.0, 0.45, z - 0.9), Vector3(3.0, 0.9, 1.0), materials.of(WorldMaterials.TIMBER))
	var ids := _everyone()
	for i: int in 3:
		var seat := Vector3(-4.2 + float(i) * 1.2, 0.0, z)
		FigurePlaces.add(seat, FigureMotion.Posture.SIT, 0.0, 0.65)
		_figure(ids[i + 1], seat, 1.2)
	for i: int in 2:
		var spot := Vector3(2.4 + float(i) * 1.2, 0.0, z)
		FigurePlaces.add(spot, FigureMotion.Posture.LEAN, PI, 0.0)
		_figure(ids[i + 4], spot, 2.0)


func _box(at: Vector3, size: Vector3, material: Material) -> void:
	var solid := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	solid.mesh = mesh
	solid.position = at
	solid.material_override = material
	_world.add_child(solid)


func _shot(id: String, z: float) -> void:
	await _shot_from(id, Vector3(0.0, 1.6, z + 12.0), Vector3(0.0, 1.0, z))


func _shot_from(id: String, eye: Vector3, target: Vector3) -> void:
	_eye.global_position = eye
	_eye.look_at(target, Vector3.UP)
	await get_tree().create_timer(0.5).timeout
	var path := "user://figure_%s.png" % id
	get_tree().root.get_texture().get_image().save_png(path)
	print(ProjectSettings.globalize_path(path))
