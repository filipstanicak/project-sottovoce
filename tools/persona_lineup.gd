## **THE FOUR PERSONAS, SIDE BY SIDE, AS A PICTURE.** ART_BIBLE §1.2, US-0046.
##
## §6.1's four rows are silhouette *claims*, and §1.2 judges them the only way a
## silhouette can be judged: rendered, at distance, in solid black, by a human.
## No suite in this repository has a window, so this is the tool that produces the
## thing the owner looks at.
##
## Run it windowed. **`--headless` renders nothing** and would write a blank file,
## which is trap 13's family: a probe that cannot see reports the same as a
## quiet machine.
##
##     godot --path . -s res://tools/persona_lineup.gd
##
## Writes `user://persona_lineup.png` and prints the path.
extends SceneTree

const PERSONAS: Array[StringName] = [
	Ids.PERSONA_VETRAIO,
	Ids.PERSONA_CANTATRICE,
	Ids.PERSONA_LUCERNA,
	Ids.PERSONA_PESATORE,
]

## Metres between figures. Wide enough that neither overlaps, tight enough that
## all four fit one frame at the distance §1.2 cares about.
const SPACING := 1.6


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless renders nothing, and a blank PNG reads like a bad model.")
		quit(1)
		return

	var world := Node3D.new()
	root.add_child(world)
	_light(world)
	_ground(world)

	var at := -SPACING * 1.5
	for persona: StringName in PERSONAS:
		world.add_child(_figure(persona, at))
		at += SPACING

	var camera := Camera3D.new()
	# Eye height and a shallow look-down, so the four are read as a crowd is read.
	camera.position = Vector3(0.0, 1.6, 7.5)
	camera.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	camera.fov = 55.0
	world.add_child(camera)
	camera.make_current()

	# Two frames: one to build, one with everything in place to capture.
	await process_frame
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	var path := "user://persona_lineup.png"
	image.save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
	print("left to right: Vetraio 1.68 | Cantatrice 1.72 | Lucerna 1.89 | Pesatore 1.75")
	quit()


## A pawn-shaped holder so `PersonaBody` measures a real collider, exactly as it
## does on a pawn.
func _figure(persona: StringName, x: float) -> Node3D:
	var holder := CharacterBody3D.new()
	holder.position = Vector3(x, 0.0, 0.0)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	holder.add_child(shape)
	var body := PersonaBody.new()
	body.persona = persona
	holder.add_child(body)
	return holder


func _light(world: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_energy = 1.1
	world.add_child(sun)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.09, 0.09, 0.11)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.30, 0.30, 0.34)
	environment.ambient_light_energy = 0.7
	env.environment = environment
	world.add_child(env)


func _ground(world: Node3D) -> void:
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(40.0, 40.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.21, 0.20)
	material.roughness = 1.0
	mesh.material = material
	plane.mesh = mesh
	world.add_child(plane)
