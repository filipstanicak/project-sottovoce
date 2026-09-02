## **A CLIENT THAT JOINS AND WALKS, SO A HUMAN HAS SOMEBODY TO HUNT.** DEBUG TOOL.
##
## There are no AI players in this game and this is not one: it is **the real
## client scene**, joined over the real wire, with its movement actions pressed
## from a script instead of by a finger. So every rule it exercises — the contract
## cycle, suspicion, the Compass, a kill, a stun, a score — runs exactly as it does
## for a person.
##
## ```
## godot --headless --path . res://tools/bot_client.tscn -- --connect 127.0.0.1:27015 --bot 1
## ```
##
## **`--bot N` IS THE SEED AND NOTHING ELSE.** Two bots given the same number walk
## the same route, which is what makes a reported defect reproducible.
##
## **IT PRESSES ACTIONS RATHER THAN WRITING COMMANDS**, like `drive_probe.gd`:
## setting `InputCommand.move` directly would skip `PadSelection`, the deadzone,
## the hold latches and `SprintGate`, every one of which has held a defect.
##
## **AND IT RUNS HEADLESS, WHICH `drive_probe.gd` SAYS IS IMPOSSIBLE.** That file
## refuses headless with *"headless cannot deliver an input action"* — **and it is
## wrong, which is worth knowing before somebody else believes it.** Trap 13's
## evidence is about *reading a device*: a joypad axis and mouse motion need a
## windowing layer, and `tools/input_probe.gd` measured exactly that. But
## `Input.action_press` is a **synthetic** press into the Input singleton and needs
## no device at all. Measured: a headless bot walked **12.5 m in fifteen seconds**
## with the server agreeing, which the travel line below reports every run.
##
## **WHAT IT STILL CANNOT DO IS LOOK WITH A MOUSE.** Turning goes through
## `input_look_left` / `input_look_right`, which exist for the pad, so a bot turns
## in coarse sweeps rather than aiming. It cannot press kill or stun meaningfully
## and does not try: it is a moving, blending, killable player, not an opponent.
extends Node

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## Handshake, first snapshot, render clock.
const SETTLE := 3.0

## How long a leg of the walk lasts, in seconds. Long enough to cross a plaza.
const LEG_MIN := 2.5
const LEG_MAX := 6.0

## How long a turn lasts. `input_look_left` is an axis binding, so a press is full
## deflection and a second of it is a large turn.
const TURN_MIN := 0.25
const TURN_MAX := 0.9

## How often the bot says where it is.
const REPORT_EVERY := 5.0

var _root: Node = null
var _rng := RandomNumberGenerator.new()
var _held: PackedStringArray = []
var _index: int = 1
var _walking := true

## `--ability <slot>`, or -1 for a bot that only walks.
var _ability: int = -1

## The last value `EVT-SUSPICION-VALUE-CHANGED` carried. See `_watch_the_cast`.
var _suspicion: float = -1.0


func _ready() -> void:
	var args := PackedStringArray(OS.get_cmdline_user_args())
	_index = _int_after(args, "--bot", 1)
	_ability = _int_after(args, "--ability", -1)
	_rng.seed = hash("sottovoce-bot-%d" % _index)
	var address := _string_after(args, "--connect", "127.0.0.1:27015")
	var host := address.get_slice(":", 0)
	var port := int(address.get_slice(":", 1)) if address.contains(":") else 27015
	_root = (load(CLIENT_ROOT) as PackedScene).instantiate()
	get_tree().get_root().add_child.call_deferred(_root)
	print("bot %d joining %s:%d" % [_index, host, port])
	Net.join(host, port)
	_run()


func _run() -> void:
	await get_tree().create_timer(SETTLE).timeout
	if not Net.is_client_connected():
		print("bot %d: no server at the address. Nothing to do." % _index)
		get_tree().quit(1)
		return
	print("bot %d: walking" % _index)
	_report()
	if _ability >= 0:
		await _press_the_ability()
	while true:
		await _leg()


## **PRESS AN ABILITY OVER THE REAL WIRE.** `--ability 1` presses `INPUT-ABILITY-2`
## once, four seconds in, and reports what the client actually sent.
##
## **THIS IS THE ONE HOP `tools/ability_probe.tscn` CANNOT SEE.** That probe boots
## `server_root.tscn` and calls `AbilitySystem.report_request` **directly**, so it
## proved the system, the effect and the state while the client-to-server message
## had **no caller at all** — pressing Q or F did literally nothing for three
## stories, and only somebody at the controls could find it. Reported 2026-09-02.
func _press_the_ability() -> void:
	var sender := _find_named(_root, "InputSender")
	var before: int = sender.call(&"requested_count") if sender != null else -1
	var action := InputActions.action_name(
		Ids.INPUT_ABILITY_1 if _ability == 0 else Ids.INPUT_ABILITY_2
	)
	print("bot %d: pressing %s (slot %d)" % [_index, action, _ability])
	Input.action_press(action)
	await get_tree().create_timer(0.2).timeout
	Input.action_release(action)
	await get_tree().create_timer(0.5).timeout
	if sender == null:
		print("bot %d: REFUSING — no InputSender, so nothing could have been sent." % _index)
		return
	var after: int = sender.call(&"requested_count")
	print("bot %d: ability requests sent %d -> %d" % [_index, before, after])
	await _watch_the_cast()


## **THE ROUND TRIP, READ OFF THE PAWN.** The client counter above proves only that
## a packet left. What proves the whole path — binding, sampler, sender, RPC,
## router, `SYS-ABILITY`, the effect and the state — is the **snapshot coming
## back**: `own_state` and `suspicion` are the server's, and neither moves unless
## the press was received and honoured.
##
## `AbilitySystem` logs nothing at all, so the server's own output cannot answer
## this; that is why the evidence has to be gathered here.
func _watch_the_cast() -> void:
	var driver := _find_named(_root, "LocalPawnDriver")
	if driver == null:
		print("bot %d: REFUSING — no driver, so nothing could be observed." % _index)
		return
	var ctx := driver.get("ctx") as PawnContext
	# **SUSPICION COMES OFF THE BUS, NOT OFF THE CONTEXT.** A client never writes
	# `PawnContext.suspicion` at all — it is server state and `HudBridge` reads it
	# straight from the snapshot — so an earlier version of this tool read a
	# permanent `0.0` and would have reported `TUN-LUNGE-SUSPICION` as not applying.
	# Trap 4's family: an instrument wrong in a plausible direction.
	EventBus.suspicion_value_changed.connect(_note_suspicion)
	_suspicion = -1.0
	var before := -1.0
	var states: Dictionary = {}
	for _i: int in 120:
		await get_tree().physics_frame
		states[ctx.state_id] = true
		if before < 0.0:
			before = _suspicion
	EventBus.suspicion_value_changed.disconnect(_note_suspicion)
	print(
		(
			"bot %d: states seen after the press: %s   suspicion %.1f -> %.1f"
			% [_index, ", ".join(PackedStringArray(states.keys())), before, _suspicion]
		)
	)


func _note_suspicion(value: float) -> void:
	_suspicion = value


## **HOW FAR IT HAS ACTUALLY GOT, EVERY `REPORT_EVERY` SECONDS.** A bot that joined
## and stood still looks identical in the server log to one that is walking, and
## the whole reason this tool exists rather than a bare `--connect` is that a
## standing target cannot exercise the Compass, the crowd or a chase.
func _report() -> void:
	var driver := _find_named(_root, "LocalPawnDriver")
	var from := Vector3.ZERO
	var last := Vector3.ZERO
	var walked := 0.0
	while true:
		await get_tree().create_timer(REPORT_EVERY).timeout
		if driver == null:
			return
		var here: Vector3 = (driver.get("ctx") as PawnContext).position
		if from == Vector3.ZERO:
			from = here
			last = here
		walked += last.distance_to(here)
		last = here
		print(
			(
				"bot %d: at (%.1f, %.1f) — %.1f m walked, %.1f m from where it started"
				% [_index, here.x, here.z, walked, from.distance_to(here)]
			)
		)


static func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child: Node in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null


## One leg: walk for a while, then turn for a while. **Blend-walk, not run** —
## a bot sprinting in circles would sit at Exposed all match and make every
## suspicion reading meaningless.
func _leg() -> void:
	_hold(["input_move_forward", "input_slow"])
	await get_tree().create_timer(_rng.randf_range(LEG_MIN, LEG_MAX)).timeout
	_hold([_turn()])
	await get_tree().create_timer(_rng.randf_range(TURN_MIN, TURN_MAX)).timeout


func _turn() -> String:
	return "input_look_left" if _rng.randf() < 0.5 else "input_look_right"


## Release whatever was held and press these instead. **One place**, so a bot
## cannot end a leg still holding the previous one's keys — which reads as a bot
## that walks into a wall and stays there.
func _hold(actions: Array) -> void:
	for action: String in _held:
		Input.action_release(action)
	_held = PackedStringArray()
	for action: Variant in actions:
		Input.action_press(str(action))
		_held.append(str(action))


static func _string_after(args: PackedStringArray, flag: String, fallback: String) -> String:
	var at := Array(args).find(flag)
	return str(args[at + 1]) if at >= 0 and at + 1 < args.size() else fallback


static func _int_after(args: PackedStringArray, flag: String, fallback: int) -> int:
	return int(_string_after(args, flag, str(fallback)))
