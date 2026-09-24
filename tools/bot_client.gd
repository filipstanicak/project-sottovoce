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

const HUNT := preload("res://tools/bot_hunt.gd")
const CIVILIAN := preload("res://tools/bot_civilian.gd")
const CENSUS := preload("res://tools/bot_census.gd")

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## Handshake, first snapshot, render clock.
const SETTLE := 3.0

## How often the bot says where it is.
const REPORT_EVERY := 5.0

var _root: Node = null
var _held: PackedStringArray = []

## The held set as one string, so an unchanged set compares by value.
var _held_key := ""
var _index: int = 1

## `--ability <slot>`, or -1 for a bot that only walks.
var _ability: int = -1

## `--hunt`. **THE FIRST THING IN THIS PROJECT THAT PURSUES ANYBODY.** A bot walked
## randomly and could therefore never be a *pursuer* in any sense a player feels —
## and worse, a strolling bot sits at Anonymous all match, so `TUN-STUN-MIN-TIER`
## made it unstunnable and ADR-0018's Lunge stun untestable against one.
##
## **IT STEERS ON THE COMPASS AND NOTHING ELSE**, which is the only thing a client
## is told about where its contract is (GDD-03 §8.5). It cannot cheat, because
## there is nothing here to cheat with: the bearing carries
## `TUN-COMPASS-CONE-WOBBLE`'s lie exactly as a human's does.
var _hunting := false

## `--reckless`. **A HUNTER IS ONLY STUNNABLE WHEN CARELESS**, which is
## `TUN-STUN-MIN-TIER` and the whole of why patience is safe — so a bot that
## strolls can never be practised against. Casting an ability costs
## `TUN-CINDERFALL-SUSPICION` +40, which is above `TUN-SUSPICION-TIER-NOTICED` 30,
## so a bot that re-casts whenever it can is a hunter who has chosen to be seen.
##
## **IT IS THE ONLY LEVER THAT WORKS TODAY**: the other route to Noticed is speed,
## and a synthetic `input_run` moves the pawn 0.0 m.
var _reckless := false

## The last value `EVT-SUSPICION-VALUE-CHANGED` carried. See `_watch_the_cast`.
var _suspicion: float = -1.0

## The hunting brain, made only when `--hunt` is given.
var _hunt: RefCounted = null
## **THE CIVILIAN BRAIN, WHICH IS THE DEFAULT SINCE US-0102.** Until then a bot walked
## straight legs of 2.5-6 s between random turns and was the one figure of its colour
## that nobody had to look at twice. It walks the crowd's walk now — `bot_civilian.gd`.
var _civilian: RefCounted = null
## Built at `_ready` so the navigation map has synchronised by the end of the settle.
var _find_path: Callable
## `--census <seconds>`: measure how the crowd, the other players and this bot move,
## and print the comparison. Zero is off.
var _census_for := 0.0


func _ready() -> void:
	var args := PackedStringArray(OS.get_cmdline_user_args())
	_index = _int_after(args, "--bot", 1)
	_ability = _int_after(args, "--ability", -1)
	_hunting = Array(args).has("--hunt")
	_reckless = Array(args).has("--reckless")
	_census_for = float(_string_after(args, "--census", "0"))
	var address := _string_after(args, "--connect", "127.0.0.1:27015")
	var host := address.get_slice(":", 0)
	var port := int(address.get_slice(":", 1)) if address.contains(":") else 27015
	# **A BOT NEVER GOES THROUGH `boot.gd`**, so nothing would have published its
	# command line — and `ClientRoot` would fall back to the default map while the
	# server it is joining runs another one. The bot then walks a district that is
	# not there, which reads as a broken navmesh rather than a wrong map.
	#
	# `--bot` and `--ability` land in `unknown` here and that is harmless: nothing
	# calls `problems()` on this, because a bot's command line is not a launch.
	LaunchConfig.active = LaunchConfig.parse(
		args, Tuning.match_rules.max_players, Tuning.match_rules.min_players
	)
	_find_path = CIVILIAN.path_finder(LaunchConfig.active.map_name)
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
	if _hunting:
		_hunt = HUNT.new(_index)
		EventBus.compass_updated.connect(_hunt.on_compass)
	else:
		_civilian = CIVILIAN.new(_index, _anchors(), _find_path)
	print("bot %d: %s" % [_index, "hunting" if _hunting else "walking like a civilian"])
	if _census_for > 0.0:
		_take_census()
	_report()
	if _ability >= 0:
		await _press_the_ability()
	if _reckless:
		_be_reckless()
	while true:
		await _follow_brain(_hunt if _hunting else _civilian)


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


## Cast slot 0 on a loop, so the bot stays above `TUN-STUN-MIN-TIER`. The interval
## is `TUN-CINDERFALL-COOLDOWN`, read rather than written, so a retune moves it.
func _be_reckless() -> void:
	var every := Tuning.ability_data(Ids.ABIL_CINDERFALL).cooldown
	while true:
		Input.action_press("input_ability_1")
		await get_tree().create_timer(0.1).timeout
		Input.action_release("input_ability_1")
		await get_tree().create_timer(maxf(every, 1.0)).timeout


## One decision from whichever brain drives this bot, held for as long as it asks.
## A zero-length answer still yields a frame, so a brain that decides twice in a row
## cannot spin the loop.
func _follow_brain(brain: RefCounted) -> void:
	var plan: Array = brain.decide(_pawn())
	_hold(plan[0])
	await get_tree().create_timer(maxf(float(plan[1]), 0.02)).timeout


## The district's idle anchors, from the same `MapData` the server's crowd reads.
func _anchors() -> Array:
	var data := load(MapCatalogue.data_path(LaunchConfig.active.map_name)) as MapData
	return data.idle_anchors if data != null else []


## **SAMPLE WHAT THIS CLIENT DRAWS, THEN PRINT THE GROUPS SIDE BY SIDE.** Drawn
## positions for the crowd and the other players alike, so both are measured through
## the same interpolation a hunter watches — `bot_census.gd` says why a comparison
## rather than a verdict.
func _take_census() -> void:
	var census: RefCounted = CENSUS.new()
	var npcs := _find_named(_root, "NpcView") as NpcView
	var remotes := _find_named(_root, "RemotePawns") as RemotePawns
	var start := Time.get_ticks_msec() / 1000.0
	var now := start
	while now - start < _census_for:
		await get_tree().create_timer(0.2).timeout
		now = Time.get_ticks_msec() / 1000.0
		for index: int in npcs.indices():
			census.add("npc:%d" % index, now, npcs.body_of(index).global_position)
		for slot: int in remotes.slots():
			census.add("player:%d" % slot, now, remotes.pawn_of(slot).global_position)
		if _pawn() != null:
			census.add("self", now, _pawn().position)
	print("bot %d census over %.0f s:" % [_index, _census_for])
	for group: Array in [["crowd", "npc:"], ["players", "player:"], ["this bot", "self"]]:
		print("  " + CENSUS.line(group[0], census.summary(census.keys_with_prefix(group[1]))))


func _pawn() -> PawnContext:
	var driver := _find_named(_root, "LocalPawnDriver")
	return driver.get("ctx") as PawnContext if driver != null else null


## Release whatever was held and press these instead. **One place**, so a bot
## cannot end a leg still holding the previous one's keys — which reads as a bot
## that walks into a wall and stays there.
## **AN UNCHANGED SET IS LEFT ALONE, WHICH IS THE WHOLE OF WHY `--hunt` WORKED.**
## A stalking bot re-decides its keys ten times a second, and releasing then
## re-pressing the same action every 0.1 s is not *holding* it: the first hunting
## bot walked **0.0 m in forty seconds** while pressing forward continuously.
## `TUN-SPEED-RUN-RESOLVE` alone would have been enough to break — a run that is
## released before 0.15 s never resolves — and a released-and-re-pressed movement
## key gives the sampler nothing to integrate either.
func _hold(actions: Array) -> void:
	var wanted := PackedStringArray()
	for action: Variant in actions:
		wanted.append(str(action))
	# **COMPARED AS A STRING, NOT AS TWO PACKED ARRAYS.** A reference comparison
	# here would be false every time and reinstate the thrash this guard exists to
	# stop, silently — which is exactly the failure being fixed.
	var key := ",".join(wanted)
	if key == _held_key:
		return
	_held_key = key
	for action: String in _held:
		Input.action_release(action)
	_held = PackedStringArray()
	for action: String in wanted:
		Input.action_press(action)
		_held.append(action)


static func _string_after(args: PackedStringArray, flag: String, fallback: String) -> String:
	var at := Array(args).find(flag)
	return str(args[at + 1]) if at >= 0 and at + 1 < args.size() else fallback


static func _int_after(args: PackedStringArray, flag: String, fallback: int) -> int:
	return int(_string_after(args, flag, str(fallback)))
