## **LOOK AT THE DISTRICT.** ADR-0026. DEBUG TOOL.
##
##     godot --path . res://tools/look_probe.tscn
##     godot --path . res://tools/look_probe.tscn -- --only loggia
##
## No test can say whether a street looks like a street. This boots the real
## `client_root.tscn` with no server, stands a crowd in it the way a server would
## describe one, and photographs the district from the places a player sees it
## from — and from the air, where a mistake in the dressing shows at once.
##
## It prints how many triangles the dressing built and how long a frame took,
## because the art pass has a budget (ART_BIBLE §5) and looking is not measuring.
##
## Run it **windowed**: headless renders nothing (trap 13).
extends Node

const CLIENT := "res://scenes/client_root.tscn"
const SETTLE := 90

## `[name, eye, target]`. Eyes at 1.7 m are a player's; the rest are for checking.
const VIEWS: Array = [
	["piazza", Vector3(38.0, 1.7, 27.0), Vector3(62.0, 2.2, 13.0)],
	["stalls", Vector3(44.0, 1.7, 23.5), Vector3(52.0, 1.4, 18.5)],
	["loggia", Vector3(33.0, 1.7, 47.0), Vector3(80.0, 3.0, 43.0)],
	["canal", Vector3(45.0, 1.7, 33.0), Vector3(90.0, 0.0, 33.0)],
	["market", Vector3(93.0, 1.7, 80.0), Vector3(106.0, 3.0, 76.0)],
	["fondaco", Vector3(4.0, 1.7, 97.5), Vector3(60.0, 3.0, 97.0)],
	["secca", Vector3(40.0, 1.7, 86.0), Vector3(84.0, 5.0, 62.0)],
	["roof", Vector3(26.0, 10.2, 26.0), Vector3(104.0, 15.0, 12.0)],
	["air", Vector3(60.0, 70.0, 175.0), Vector3(60.0, 0.0, 55.0)],
	["air_north", Vector3(-30.0, 40.0, -40.0), Vector3(60.0, 0.0, 50.0)],
]

var _root: Node = null
var _eye: Camera3D = null
var _tick := 1000
var _civilians: Dictionary = {}
var _feeding := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless renders nothing, and a blank PNG reads like a broken look.")
		get_tree().quit(1)
		return
	_root = (load(CLIENT) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_root)
	for _i: int in SETTLE:
		await get_tree().process_frame
	_stand_a_crowd()
	_feeding = true
	_take_the_camera()
	if OS.get_cmdline_user_args().has("--bench"):
		await _bench()
		get_tree().quit()
		return
	var only := _only()
	for view: Array in VIEWS:
		if only == "" or only == str(view[0]):
			await _shot(view)
	var dressing := _root.get_node_or_null("World/Map/Dressing") as DistrictDressing
	print("")
	print("dressing: %d triangles" % (dressing.triangles if dressing != null else 0))
	print(
		(
			"frame: %.2f ms at %d fps"
			% [1000.0 / maxf(Engine.get_frames_per_second(), 1.0), Engine.get_frames_per_second()]
		)
	)
	get_tree().quit()


## What each part of the look costs, from the piazza: one effect off at a time.
func _bench() -> void:
	_eye.global_position = VIEWS[0][1]
	_eye.look_at(VIEWS[0][2], Vector3.UP)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var env := (_root.get_node("World/WorldLook/WorldEnvironment") as WorldEnvironment).environment
	var viewport := get_viewport()
	print("all on        %s" % await _frame_ms())
	env.ssr_enabled = false
	print("without SSR   %s" % await _frame_ms())
	env.ssao_enabled = false
	print("...and SSAO   %s" % await _frame_ms())
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	print("...and MSAA   %s" % await _frame_ms())
	env.glow_enabled = false
	env.fog_enabled = false
	print("...glow, fog  %s" % await _frame_ms())
	(_root.get_node("World/Map/Dressing") as Node3D).visible = false
	print("...dressing   %s" % await _frame_ms())


func _frame_ms() -> String:
	await get_tree().create_timer(0.5).timeout
	var frames := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 2000000:
		await get_tree().process_frame
		frames += 1
	return "%.2f ms" % (2000.0 / float(frames))


func _only() -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--only")
	return args[at + 1] if at >= 0 and at + 1 < args.size() else ""


## Civilians where a district has them: along the stalls, in the Loggia, and a
## few crossing the open ground.
func _stand_a_crowd() -> void:
	var index := 1
	for i: int in 14:
		_civilians[index] = Vector3(37.0 + float(i) * 3.1, 0.0, 16.6 + float(i % 3) * 2.2)
		index += 1
	for i: int in 12:
		_civilians[index] = Vector3(40.0 + float(i) * 4.3, 0.0, 43.0 + float(i % 4) * 2.0)
		index += 1
	for i: int in 8:
		_civilians[index] = Vector3(96.0 + float(i % 4) * 2.4, 0.0, 75.0 + float(i / 4) * 6.0)
		index += 1


func _take_the_camera() -> void:
	var rig := _root.get_node_or_null("World/CameraRig")
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := _root.get_node_or_null("Hud") as CanvasLayer
	if hud != null:
		hud.visible = false
	_eye = Camera3D.new()
	_eye.name = "LookProbeEye"
	_eye.fov = 70.0
	_eye.far = 2000.0
	_root.get_node("World").add_child(_eye)
	_eye.current = true


func _shot(view: Array) -> void:
	_eye.global_position = view[1]
	_eye.look_at(view[2], Vector3.UP)
	await get_tree().create_timer(0.8).timeout
	var path := "user://look_%s.png" % str(view[0])
	get_tree().root.get_texture().get_image().save_png(path)
	print(ProjectSettings.globalize_path(path))


## A snapshot every physics frame, as a server would send one every tick.
func _physics_process(_delta: float) -> void:
	if not _feeding:
		return
	_tick += 1
	var snapshot := Snapshot.new()
	snapshot.server_tick = _tick
	var pawn := _root.get_node("World/PawnLocal") as Node3D
	snapshot.own_position = pawn.global_position
	for index: int in _civilians:
		snapshot.add_npc(index, _civilians[index], float(index) * 0.9, 0, 0)
	Net.snapshot_received.emit(snapshot)
	_dress()


## Figures in the four personas' hues, so the district is judged with its crowd.
func _dress() -> void:
	var crowd := _root.get_node_or_null("ClientNet/NpcView") as NpcView
	if crowd == null:
		return
	for index: int in _civilians:
		var body := crowd.body_of(index)
		if body != null:
			body.dress(CrowdRoster.PLAYABLE[index % CrowdRoster.PLAYABLE.size()])
