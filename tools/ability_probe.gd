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
	await _lunge(abilities, ctx)
	get_tree().quit()


## **A PEER THAT NEVER SENDS INPUT IS NEVER STEPPED, AND THE FIRST VERSION OF THE
## LUNGE PROBE DID NOT KNOW THAT.** It joined a peer, pressed the ability and
## watched: the pawn entered `Lunging`, travelled **0.00 m** and stayed there
## forever, which reads exactly like a dash that does not work.
##
## It is US-0028's own rule, in `MatchDirector._repeat_last`: *"Nothing is repeated
## for a peer that has never sent one — there is no intent to extend, and a pawn
## that has not yet moved must not start."* `LungingState` is driven by
## `PawnMotion` at the `pawn` stage and nothing was driving it. **A probe that does
## not send input measures a pawn nobody is simulating**, which is trap 13's family
## — an instrument reporting a zero it cannot distinguish from a real one.
func _send_a_command(seq: int) -> void:
	var director := _root.get("director") as MatchDirector
	if director != null:
		director.enqueue_input(PEER, InputCommand.empty(seq + 1))


## **PRESS SLOT 1 AND WATCH THE PAWN MOVE.** US-0070.
##
## The unit tests drive `AbilitySystem` and `LungingState` directly and cannot see
## the wiring: that `server_root` equips Lunge at all, that the `abilities` stage
## runs before `combat` so an arrival is drained in the tick it is queued, and that
## `MatchDirector._substep_pawns` steps the state at the input rate. This is the
## gap US-0074 lost a whole integration run to.
func _lunge(abilities: AbilitySystem, ctx: MatchContext) -> void:
	var pawn: PawnContext = ctx.pawn_contexts.get(PEER)
	if pawn == null:
		print("REFUSING: the joined peer has no pawn, so there is nothing to dash.")
		return
	var from := pawn.position
	var data := Tuning.ability_data(Ids.ABIL_LUNGE)
	# **AIMED AT THE DISTRICT CENTRE, NOT BLINDLY AT +Z.** A spawn point is by design
	# near the map's edge and `VetraioGround` derives a parapet on every floor edge,
	# so a blind direction dashes into a wall and reports a short travel that reads
	# exactly like a dash that does not work. The first version did, at 1.15 m of 6.
	var toward := (Vector3(60.0, from.y, 60.0) - from).normalized()
	abilities.report_request(PEER, 1, from, toward * data.distance)
	print("")
	print("--- ABIL-LUNGE ---")
	print("pressed at ", from, " aiming ", toward)
	var seen_windup := false
	var dash_frames := 0
	for step: int in 90:
		_send_a_command(step)
		await get_tree().physics_frame
		if pawn.state_id == PawnStateId.LUNGING:
			dash_frames += 1
		elif dash_frames == 0:
			seen_windup = true
	_report_lunge(seen_windup, dash_frames, from, pawn, abilities)


## What the dash was, said separately from doing it. **Split for the length
## guard**, and the seam is the same one `hud_probe.gd` draws: above is *press and
## watch*, here is *tell somebody*.
func _report_lunge(
	seen_windup: bool, dash_frames: int, from: Vector3, pawn: PawnContext, abilities: AbilitySystem
) -> void:
	var data := Tuning.ability_data(Ids.ABIL_LUNGE)
	print("  the wind-up was spent OUT of the dash state: ", seen_windup)
	print("  the pawn entered Lunging: ", dash_frames > 0)
	print("  held it %d step ticks of %d" % [dash_frames, LungingState.dash_ticks()])
	print(
		"  travelled %.2f m against a tuned %.1f" % [from.distance_to(pawn.position), data.distance]
	)
	print("  ended in state: ", pawn.state_id)
	print("  suspicion now: %.1f" % pawn.suspicion)
	print("  cooldown ticks left: %d" % abilities.cooldown_ticks(PEER, 1))
	print("")
	print("EXPECT: a wind-up outside the dash state, then Lunging held its full")
	print(
		(
			"        %d ticks, about 5.85 m of travel (the last tick is spent"
			% LungingState.dash_ticks()
		)
	)
	print("        stopping dead), and Staggered — a whiff, with no contract to kill.")


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
