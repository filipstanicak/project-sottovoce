## **WHAT THE GAME ACTUALLY SAMPLES, AFTER EVERYTHING THAT FILTERS IT.** US-0090.
##
## `tools/input_probe.gd` reads the input layer **raw**, which is what it is for —
## it found a set of sim pedals holding three actions at full deflection. But it
## runs as a `-s` `SceneTree` script, so it stands up no client scene, and
## `PadSelection` is applied by `InputSampler._ready()`. **It therefore reports the
## bindings as shipped in `project.godot`, not the ones the game is playing with.**
##
## With the pedals attached the two disagree completely: the raw probe reports
## `input_move_forward 1.00` and the client log reports `no mapped pad, joypad
## bindings disabled`. Both are true and only one of them is about the game. A
## diagnostic that answers a different question than the one being asked is trap
## 13's family, and it cost a wrong diagnosis once already.
##
## So this one boots the **real client scene** and prints the `InputCommand` the
## real `LocalPawnDriver` emits — which is the only thing that moves a pawn.
##
##     godot --path . res://tools/input_live.tscn
##
## **A SCENE AND NOT A `-s` SCRIPT**, because a `SceneTree` script compiles before
## the autoload globals register and every script naming `Net` fails to compile.
## **AND NEVER `--headless`**: there is no windowing layer there to see a device,
## so every reading would be a zero — which is exactly what a quiet machine looks
## like. Trap 13.
extends Node

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## Long enough for a pad's resting axis values to arrive, which they do about a
## second after it enumerates.
const SETTLE := 3.0
const WATCH := 6.0
const SAMPLE_EVERY := 0.5

var _root: Node
var _driver: Node
var _seen: Array = []
var _from := Vector3.INF


## Where the local pawn is now, or `INF` before one exists.
func _pawn_at() -> Vector3:
	var pawn := _find(_root, "PawnLocal")
	return (pawn as Node3D).global_position if pawn is Node3D else Vector3.INF


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless sees no input device, and a zero from a blind probe")
		print("reads exactly like a zero from a quiet machine. Trap 13.")
		get_tree().quit(1)
		return
	_root = (load(CLIENT_ROOT) as PackedScene).instantiate()
	get_tree().get_root().add_child.call_deferred(_root)
	# **CONNECTED, BECAUSE A LOCAL-ONLY CLIENT IS A DIFFERENT GAME.** Run offline
	# this tool reported a perfectly still pawn while the same build, joined to a
	# server, walked 40 m with nobody at the controls. Prediction, reconciliation
	# and the server's own "a missing command repeats the last one" all live on the
	# connected path and none of them runs offline.
	Net.join("127.0.0.1", 27015)
	_run()


func _run() -> void:
	await get_tree().create_timer(SETTLE).timeout
	_driver = _find(_root, "LocalPawnDriver")
	if _driver == null:
		print("REFUSING: no LocalPawnDriver in the client scene — nothing samples input.")
		get_tree().quit(1)
		return
	_driver.command_sampled.connect(_on_command)
	_from = _pawn_at()
	var elapsed := 0.0
	while elapsed < WATCH:
		await get_tree().create_timer(SAMPLE_EVERY).timeout
		elapsed += SAMPLE_EVERY
		_report_now()
	_verdict()
	get_tree().quit(0)


## **THE COMMAND, NOT THE ACTIONS.** `InputCommand.move` is what reaches the
## server and what the pawn is stepped with; an action still bound to a device is
## harmless if nothing samples it into a command.
func _on_command(command: InputCommand) -> void:
	_seen.append([command.move, command.buttons])
	if _seen.size() > 240:
		_seen.remove_at(0)


func _report_now() -> void:
	if _seen.is_empty():
		print("no command has been sampled at all — the driver is not running")
		return
	var last: Array = _seen[-1]
	var move: Vector2 = last[0]
	print(
		(
			"move=(%+.3f,%+.3f)  buttons=%s  |  raw actions: fwd %.2f  left %.2f  run %.2f"
			% [
				move.x,
				move.y,
				String.num_uint64(int(last[1]), 2).pad_zeros(8),
				Input.get_action_strength(&"input_move_forward"),
				Input.get_action_strength(&"input_move_left"),
				Input.get_action_strength(&"input_run"),
			]
		)
	)


## **THE ONE QUESTION WORTH A VERDICT: does the pawn move with nobody touching
## anything?** A command whose `move` is nonzero over a whole watch is a pawn
## walking on its own, whatever the cause.
func _verdict() -> void:
	var moving := 0
	for row: Array in _seen:
		if (row[0] as Vector2).length() > 0.01:
			moving += 1
	var now := _pawn_at()
	var drift := 0.0 if _from == Vector3.INF or now == Vector3.INF else _from.distance_to(now)
	print("--- %d of %d sampled commands carried movement ---" % [moving, _seen.size()])
	print("the pawn travelled %.2f m during the watch, from %v to %v" % [drift, _from, now])
	if moving == 0 and drift < 0.5:
		print("CLEAN: nothing is driving the pawn.")
		return
	if moving == 0:
		print("**THE PAWN MOVED WITHOUT A SINGLE COMMAND ASKING IT TO.**")
		print("That is not the input layer. Look at the server: a peer whose command")
		print("stops arriving has its LAST one repeated rather than being stalled,")
		print("and at reconciliation, which takes the server's answer exactly.")
		return
	print("THE PAWN IS BEING DRIVEN WITH NOBODY AT THE CONTROLS.")
	print("Compare `godot --path . -s res://tools/input_probe.gd`, which reads the")
	print("layer RAW: if that shows a device held and this shows movement, the")
	print("device is reaching a command. If that shows a device held and this is")
	print("clean, PadSelection is doing its job and the cause is elsewhere.")


func _find(node: Node, wanted: String) -> Node:
	if node.get_class() == wanted or node.name == wanted:
		return node
	for child: Node in node.get_children():
		var hit := _find(child, wanted)
		if hit != null:
			return hit
	return null
