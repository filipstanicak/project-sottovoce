## **THE DISTRICT WITH THE CROWD IN IT, AS A PICTURE.** US-0030, US-0031, and the
## first thing in this project that draws an NPC.
##
## The corpus's own rule: **nine defects here were found by looking at the running
## game and none was reachable by any test** — no suite has a window, a display or
## an input device. `NpcView` is exactly what that rule is for: every assertion
## about it passes whether the district renders a crowd, renders nothing, or
## stacks seventy-eight bodies on the origin.
##
## Run it against a server that is already up:
##
##     godot --headless --path . -- --server --port 27015 --max-players 6 &
##     godot --path . res://tools/crowd_probe.tscn
##
## **IT IS A SCENE, NOT A `-s` SCRIPT, AND THAT IS NOT A STYLE CHOICE.** A
## `SceneTree` script run with `-s` compiles before the autoload globals are
## registered, so every script naming `Net` — `remote_pawns.gd` and `npc_view.gd`
## among them — fails to compile and the client silently loads without them. The
## first version of this tool did that and reported an empty district, which is
## trap 13's family: a probe that cannot see reports what a broken game reports.
##
## **`--headless` RENDERS NOTHING** and would write a blank file. It refuses.
extends Node

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## Seconds before the shot: the handshake, a pawn, and enough snapshots that the
## interpolator has two samples to work between.
const SETTLE := 6.0

var _root: Node


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless renders nothing, and a blank PNG reads like an empty district.")
		get_tree().quit(1)
		return
	_root = (load(CLIENT_ROOT) as PackedScene).instantiate()
	get_tree().get_root().add_child.call_deferred(_root)
	Net.join("127.0.0.1", 27015)
	_shoot()


func _shoot() -> void:
	await get_tree().create_timer(SETTLE).timeout
	var view := _find(_root) as NpcView
	var drawn := view.count() if view != null else -1
	var spread := _spread(view)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://crowd.png")
	print("crowd.png -> %s" % ProjectSettings.globalize_path("user://crowd.png"))
	# **THE COUNT AND THE SPREAD, BESIDE THE PICTURE.** A screenshot alone cannot
	# tell a crowd from one NPC very close to the camera, nor a placed crowd from
	# seventy-eight bodies stacked on the origin.
	print("NPCs drawn: %d, spread across %.1f m" % [drawn, spread])
	get_tree().quit(0)


func _spread(view: NpcView) -> float:
	if view == null:
		return 0.0
	var lo := Vector3(INF, 0.0, INF)
	var hi := Vector3(-INF, 0.0, -INF)
	for child: Node in view.get_children():
		var at: Vector3 = (child as Node3D).global_position
		lo.x = minf(lo.x, at.x)
		lo.z = minf(lo.z, at.z)
		hi.x = maxf(hi.x, at.x)
		hi.z = maxf(hi.z, at.z)
	return 0.0 if lo.x == INF else Vector2(hi.x - lo.x, hi.z - lo.z).length()


func _find(node: Node) -> Node:
	if node is NpcView:
		return node
	for child: Node in node.get_children():
		var found := _find(child)
		if found != null:
			return found
	return null
