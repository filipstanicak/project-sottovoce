## **PRESS AN ABILITY ON A REAL SERVER AND SAY WHAT HAPPENED.** US-0067.
##
## Every ability test in `test/unit/systems/ability/` drives `AbilitySystem`
## directly, which is the right place to prove the rules and **cannot see the
## wiring**: `server_root` connects `ability_startled` to `CrowdDirector`, loads
## `cinderfall.tres` with its `effect_script`, and hands every joining peer a
## placeholder loadout. US-0074 lost a whole integration run to exactly that gap —
## a handler whose arity did not match the signal, accepted by `connect` and
## failing at every emission.
##
## **IT BOOTS `server_root.tscn`, WHICH IS TRAP 4's SCENE.** Headless is fine here:
## nothing about an ability is rendered, which is itself worth saying — a Cinderfall
## is an *absence* of information on a client until there is a VFX pass.
##
## ```
## godot --headless --path . res://tools/ability_probe.tscn
## ```
extends Node

const SERVER := "res://scenes/server_root.tscn"
const PEER := 4242
const SETTLE := 40

var _root: Node = null


func _ready() -> void:
	_run()


func _run() -> void:
	_root = (load(SERVER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_root)
	for _i: int in SETTLE:
		await get_tree().physics_frame
	var abilities: AbilitySystem = _root.get("abilities")
	var ctx: MatchContext = (_root.get("director") as MatchDirector).ctx
	if abilities == null or ctx == null:
		print("REFUSING: the server has no ability system, so there is nothing to press.")
		get_tree().quit(1)
		return

	_root.call(&"_on_peer_joined", PEER)
	await get_tree().physics_frame
	var kit: Array = abilities.loadout.get(PEER, [])
	print("loadout: ", kit)
	if kit.is_empty():
		print("REFUSING: the joined peer carries nothing, so a press would be refused by rule 1.")
		get_tree().quit(1)
		return

	await _throw(abilities, ctx)
	get_tree().quit()


## Press slot 0 and watch for `TUN-CINDERFALL-CAST-TIME` plus a margin.
func _throw(abilities: AbilitySystem, ctx: MatchContext) -> void:
	var pawn: PawnContext = ctx.pawn_contexts.get(PEER)
	var here := pawn.position if pawn != null else Vector3.ZERO
	var startled: Array[int] = []
	abilities.ability_startled.connect(func(_at: Vector3, _r: float) -> void: startled.append(1))
	var before := ctx.crowd_hash.count()
	abilities.report_request(PEER, 0, here, Vector3(0.0, 0.0, 40.0))
	print("pressed at ", here, "   NPCs in the grid: ", before)

	var wind_up := Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME")
	for step: int in wind_up + 12:
		await get_tree().physics_frame
		await get_tree().physics_frame
		if step == wind_up - 2:
			print("  wind-up, %d ticks in: clouds %d" % [step, ctx.cinderfall.count_at(ctx.tick)])
	print(
		(
			"  after the burst: clouds %d, startle waves %d"
			% [ctx.cinderfall.count_at(ctx.tick), startled.size()]
		)
	)
	# **THE PAWN'S VALUE, NOT THE QUEUE'S, AND THE FIRST VERSION READ THE QUEUE.**
	# `SYS-SUSPICION` drains impulses at step 1 of its own pass, so `pending` is back
	# to zero a tick after the cast — it printed `0.0` and read exactly like a cost
	# that was never charged. The probe found my own expectation wrong, which is what
	# it is for.
	print("  suspicion now: %.1f" % (pawn.suspicion if pawn != null else -1.0))
	print("  cooldown ticks left: %d" % abilities.cooldown_ticks(PEER, 0))
	print("")
	print("EXPECT: 0 clouds during the wind-up, 1 after it, 1 startle wave,")
	print(
		(
			"        suspicion at or above %.0f, and a cooldown near %d ticks."
			% [
				Tuning.ability_data(Ids.ABIL_CINDERFALL).suspicion_cost,
				Tuning.ticks(&"TUN-CINDERFALL-COOLDOWN")
			]
		)
	)
