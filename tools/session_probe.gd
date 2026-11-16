## **LOOK AT A REAL SESSION, AND PRICE IT.** US-0109. DEBUG TOOL.
##
##     godot --path . res://tools/session_probe.tscn -- --connect 127.0.0.1:27015
##
## `look_probe` stands a still crowd of thirty in an empty client. This joins a
## server that is actually running a match — bots walking, the whole crowd strolling,
## sitting and leaning — as one more player, and photographs what that player
## sees. Then it turns vsync off and reports what a frame costs with the district
## dressed and ninety figures animated, which is the number ART_BIBLE §5 is about.
##
## It needs a server with room for one more: `play.bat`'s, or
## `godot --headless --path . -- --server --min-players 2` and a bot.
##
## Run it **windowed**: headless renders nothing (trap 13).
extends Node

const CLIENT := "res://scenes/client_root.tscn"
## How long to wait for the countdown to hand out a match.
const MATCH_WAIT := 40.0
const SHOTS := 4
const SHOT_GAP := 4.0

var _root: Node = null


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless renders nothing, and a blank PNG reads like an empty district.")
		get_tree().quit(1)
		return
	var args := OS.get_cmdline_user_args()
	LaunchConfig.active = LaunchConfig.parse(
		args, Tuning.match_rules.max_players, Tuning.match_rules.min_players
	)
	_root = (load(CLIENT) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_root)
	await get_tree().create_timer(1.0).timeout
	Net.join(LaunchConfig.active.connect_host(), LaunchConfig.active.connect_port())
	if not await _a_match_started():
		print(
			"no match started within %.0f s: is the server waiting for more players?" % MATCH_WAIT
		)
		get_tree().quit(1)
		return
	for i: int in SHOTS:
		await get_tree().create_timer(SHOT_GAP).timeout
		_shot("session_%d" % i)
	await _from_above()
	await _price()
	get_tree().quit()


func _a_match_started() -> bool:
	var waited := 0.0
	while waited < MATCH_WAIT:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
		if GameState.has_match() and _crowd() != null and _crowd().count() > 0:
			return true
	return false


func _crowd() -> NpcView:
	return _root.get_node_or_null("ClientNet/NpcView") as NpcView


func _shot(id: String) -> void:
	var path := "user://%s.png" % id
	get_tree().root.get_texture().get_image().save_png(path)
	print(ProjectSettings.globalize_path(path))


## The street the player stands in, from a first-floor window.
func _from_above() -> void:
	var pawn := _root.get_node("World/PawnLocal") as Node3D
	var eye := Camera3D.new()
	eye.fov = 60.0
	eye.far = 2000.0
	_root.get_node("World").add_child(eye)
	eye.global_position = pawn.global_position + Vector3(7.0, 6.0, 7.0)
	eye.look_at(pawn.global_position + Vector3(-6.0, 0.5, -6.0), Vector3.UP)
	eye.current = true
	(_root.get_node("Hud") as CanvasLayer).visible = false
	await get_tree().create_timer(1.0).timeout
	_shot("session_above")
	await get_tree().create_timer(SHOT_GAP).timeout
	_shot("session_above_later")


func _price() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(0.5).timeout
	var frames := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 3000000:
		await get_tree().process_frame
		frames += 1
	var remotes := _root.get_node_or_null("ClientNet/RemotePawns") as RemotePawns
	print("")
	print("civilians drawn: %d, other players: %d" % [_crowd().count(), remotes.count()])
	print("frame: %.2f ms (%d fps), vsync off" % [3000.0 / float(frames), frames / 3])
	print(
		(
			"physics: %.2f ms a tick"
			% (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		)
	)
