## **THE RECONCILIATION ERROR WHILE THE PAWN IS ACTUALLY MOVING.** US-0028.
##
##     godot --headless --path . -- --server --port 27015 --max-players 6 &
##     godot --path . res://tools/drive_probe.tscn
##
## `scripts/debug/net_readout.gd` shows this live and needs a human holding a key.
## The owner reported the jitter back with a screenshot reading **mean 0.066 m,
## p95 0.075, six replays, every one of them `BACK 0.150`** — and the baseline for
## a *stationary* pawn is exactly 0.000 m over 300 comparisons, so the disagreement
## only exists while moving and no idle probe can see it.
##
## **IT DRIVES THROUGH `Input.action_press`, NOT BY WRITING A COMMAND.** Setting
## `InputCommand.move` directly would skip `PadSelection`, the deadzone, the
## hold/toggle latches and `SprintGate` — every one of which has held a defect at
## some point. Pressing the action exercises the same path a finger does.
##
## **AND IT REFUSES TO RUN HEADLESS**, trap 13: there is no windowing layer to
## deliver an action, so every reading would be zero and a zero from a blind probe
## reads exactly like a healthy machine.
extends Node

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## Long enough for the handshake, the first snapshot and the render clock to start.
const SETTLE := 4.0

## How long to hold the key down.
const DRIVE := 10.0

## What to hold. Run rather than stroll, because the error this is chasing is
## quantised in commands and one command is 7.5 cm at `TUN-SPEED-RUN` against
## 2.3 cm at a blend walk — the same defect is three times more legible.
const HELD := ["input_move_forward", "input_run"]

var _root: Node
var _reconciler: Node
var _driver: Node
var _errors: PackedFloat32Array = PackedFloat32Array()
var _corrections: Array = []
var _moved := 0
var _commands := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless cannot deliver an input action, and a zero from a")
		print("blind probe reads exactly like a zero from a healthy client. Trap 13.")
		get_tree().quit(1)
		return
	_root = (load(CLIENT_ROOT) as PackedScene).instantiate()
	get_tree().get_root().add_child.call_deferred(_root)
	Net.join("127.0.0.1", 27015)
	_run()


func _run() -> void:
	await get_tree().create_timer(SETTLE).timeout
	_reconciler = _find(_root, "reconciler.gd")
	_driver = _find_named(_root, "LocalPawnDriver")
	if _reconciler == null or _driver == null:
		print("REFUSING: no Reconciler or no LocalPawnDriver — this is not the real client.")
		get_tree().quit(1)
		return
	_reconciler.connect("corrected", Callable(self, "_on_corrected"))
	_driver.connect("command_sampled", Callable(self, "_on_command"))
	var from := _pawn_at()
	for action: String in HELD:
		Input.action_press(action)
	await get_tree().create_timer(DRIVE).timeout
	for action: String in HELD:
		Input.action_release(action)
	await get_tree().create_timer(1.0).timeout
	_report(from)
	get_tree().quit(0)


func _on_corrected(error: float, replayed: bool) -> void:
	_errors.append(error)
	if not replayed:
		return
	var at := _reconciler.get("last_error_vector") as Vector3
	var yaw: float = _driver.ctx.yaw
	_corrections.append([at, yaw])


func _on_command(command: InputCommand) -> void:
	_commands += 1
	if command.move.length() > 0.01:
		_moved += 1


## **THE TRAVEL LINE COMES FIRST, BECAUSE EVERY OTHER NUMBER MEANS SOMETHING ELSE
## IF THE PAWN NEVER MOVED.** A probe whose key press did not reach the sampler
## reports a perfect 0.000 m error, which is indistinguishable from a healthy
## client and is how this class of tool has lied before.
func _report(from: Vector3) -> void:
	var travelled := from.distance_to(_pawn_at())
	print("--- driving the real client for %.0f s ---" % DRIVE)
	print(
		(
			"commands %d, of which %d carried movement; the pawn travelled %.2f m"
			% [_commands, _moved, travelled]
		)
	)
	if _moved == 0 or travelled < 1.0:
		print("REFUSING TO REPORT AN ERROR: the pawn did not move, so nothing below is about")
		print("reconciliation. Check the window has focus and PadSelection is not ignoring the")
		print("keyboard.")
		return
	_report_error()
	_report_bias()


func _report_error() -> void:
	if _errors.is_empty():
		print("no snapshots were compared at all — the client is not reconciling")
		return
	var sorted := Array(_errors)
	sorted.sort()
	var total := 0.0
	for value: float in sorted:
		total += float(value)
	print(
		(
			"error   mean %.3f  p95 %.3f  max %.3f m over %d (snap at %.2f), %d replays"
			% [
				total / float(sorted.size()),
				float(sorted[int(float(sorted.size()) * 0.95)]),
				float(sorted[-1]),
				sorted.size(),
				Tuning.net.reconcile_threshold,
				_corrections.size()
			]
		)
	)
	print("  one command at TUN-SPEED-RUN is %.3f m" % (Tuning.movement.run / 60.0))


## **AVERAGED IN THE PAWN'S FRAME.** Two corrections that both pulled the player
## backwards cancel in world space when the two happened on opposite headings,
## which reports "no bias" for the most systematic fault there is.
func _report_bias() -> void:
	if _corrections.is_empty():
		print("bias    no correction exceeded the snap threshold")
		return
	var along := 0.0
	var across := 0.0
	for entry: Array in _corrections:
		var error := entry[0] as Vector3
		var yaw := float(entry[1])
		var forward := Vector3(sin(yaw), 0.0, cos(yaw))
		along += error.dot(forward)
		across += error.dot(Vector3(forward.z, 0.0, -forward.x))
	var n := float(_corrections.size())
	print(
		(
			"bias    %s %.3f   %s %.3f   over %d replays"
			% [
				"FWD " if along >= 0.0 else "BACK",
				absf(along / n),
				"RIGHT" if across >= 0.0 else "LEFT ",
				absf(across / n),
				_corrections.size()
			]
		)
	)


func _pawn_at() -> Vector3:
	if _driver == null:
		return Vector3.ZERO
	return _driver.ctx.position as Vector3


func _find(node: Node, script_tail: String) -> Node:
	if node.get_script() != null and node.get_script().resource_path.ends_with(script_tail):
		return node
	for child: Node in node.get_children():
		var hit := _find(child, script_tail)
		if hit != null:
			return hit
	return null


func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child: Node in node.get_children():
		var hit := _find_named(child, wanted)
		if hit != null:
			return hit
	return null
