## **THE CLOUD CATCHES EVERYBODY IN IT BUT THE CASTER, AND THE CASTER STRIKES.**
## ADR-0023, US-0104.
##
## The reference's cloud makes everyone around its caster double over coughing,
## unable to run or fight back, for as long as it stands, including anybody who
## walks in after the burst; a pursuer caught in it is a free stun; and *cloud, then
## kill inside it* is the ability's main use. Each of those is a test here, driven
## through the real `KillSystem`, which runs the catch before it judges any press.
extends GutTest

const A := 81
const B := 82
const C := 83

var _system: KillSystem
var _ctx: MatchContext
var _machines: Array[PawnStateMachine] = []
var _ordinal: int = 0


func before_each() -> void:
	_ordinal = 0
	_machines.clear()
	_ctx = MatchContext.new()
	_ctx.tick = 200
	_system = KillSystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)


func after_each() -> void:
	for machine: PawnStateMachine in _machines:
		machine.free()
	_machines.clear()


func _place(peer: int, at: Vector3) -> PawnContext:
	var machine := PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		machine.register(script.new())
	_machines.append(machine)
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, 0.0)
	machine.spawn_into(pawn, PawnStateId.IDLE)
	_ctx.pawn_contexts[peer] = pawn
	_ctx.pawn_machines[peer] = machine
	return pawn


## A hunts B, two metres ahead, and the ring holds enough history for a rewind.
func _hunter_and_contract() -> void:
	_place(A, Vector3.ZERO)
	_place(B, Vector3(0.0, 0.0, 2.0))
	_ctx.announced_contracts[A] = B
	_fill_the_ring(8)


func _fill_the_ring(ticks: int) -> void:
	for back: int in range(ticks, 0, -1):
		var ids := PackedInt32Array()
		var places := PackedVector3Array()
		var yaws := PackedFloat32Array()
		for peer: int in _ctx.pawn_contexts.keys():
			var pawn := _ctx.pawn_contexts[peer] as PawnContext
			ids.append(peer)
			places.append(pawn.position)
			yaws.append(pawn.yaw)
		_ctx.lag_comp.record(_ctx.tick - back, ids, places, yaws)


func _press(peer: int) -> void:
	var command := InputCommand.empty(1)
	command.buttons = InputBits.KILL
	_ordinal += 1
	command.received_ordinal = _ordinal
	_system.report_input(peer, command, MatchContext.step_dt())
	_system.report_input(peer, command, MatchContext.step_dt())


func _release(peer: int) -> void:
	_system.report_input(peer, InputCommand.empty(1), MatchContext.step_dt())


func _advance(ticks: int = 1) -> void:
	for _i: int in ticks:
		_fill_the_ring(1)
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func _state(peer: int) -> StringName:
	return (_ctx.pawn_contexts[peer] as PawnContext).state_id


# ------------------------------------------------------------ the catch --


func test_everybody_but_the_caster_is_caught() -> void:
	_hunter_and_contract()
	_place(C, Vector3(3.0, 0.0, 0.0))
	_ctx.cinderfall.add(Vector3.ZERO, _ctx.tick, A)
	_advance()
	assert_eq(_state(A), PawnStateId.IDLE, "the caster was caught by their own cloud")
	assert_eq(_state(B), PawnStateId.CHOKING, "the contract beside the caster was not caught")
	assert_eq(_state(C), PawnStateId.CHOKING, "a bystander in the cloud was not caught")


func test_the_catch_stops_at_the_radius() -> void:
	_hunter_and_contract()
	var beyond := Tuning.ability_data(Ids.ABIL_CINDERFALL).radius + 1.0
	_place(C, Vector3(beyond, 0.0, 0.0))
	_ctx.cinderfall.add(Vector3.ZERO, _ctx.tick, A)
	_advance()
	assert_eq(_state(C), PawnStateId.IDLE, "the cloud caught somebody outside its radius")


func test_somebody_who_walks_in_later_is_caught_too() -> void:
	# The owner's answer, 2026-09-25: *"auch wer danach reinläuft"*.
	_hunter_and_contract()
	var late := _place(C, Vector3(20.0, 0.0, 0.0))
	_ctx.cinderfall.add(Vector3.ZERO, _ctx.tick, A)
	_advance(10)
	assert_eq(_state(C), PawnStateId.IDLE, "the premise: C was never near the cloud")
	late.position = Vector3(2.0, 0.0, 0.0)
	_advance()
	assert_eq(_state(C), PawnStateId.CHOKING, "a late entrant walked through the cloud")


func test_the_caught_cough_until_the_cloud_ends_and_no_longer() -> void:
	# *"Das Husten ist für die komplette Dauer da"*: no duration of its own.
	_hunter_and_contract()
	_ctx.cinderfall.add(Vector3.ZERO, _ctx.tick, A)
	_advance(Tuning.ticks(&"TUN-CINDERFALL-DURATION") - 1)
	assert_eq(_state(B), PawnStateId.CHOKING, "the contract recovered before the cloud ended")
	_advance(2)
	assert_eq(_state(B), PawnStateId.IDLE, "the contract was still held after the cloud ended")


func test_a_caught_figure_cannot_strike() -> void:
	# B hunts A here, and is caught in A's cloud: it can neither run nor fight back.
	_hunter_and_contract()
	_ctx.announced_contracts.erase(A)
	_place(C, Vector3(0.0, 0.0, 3.0))
	_ctx.announced_contracts[B] = C
	_ctx.cinderfall.add(Vector3(0.0, 0.0, 2.5), _ctx.tick, A)
	_advance()
	# **THE VISIBLE HALF**: `kill_ready` lights the crosshair ring, and a ring on a
	# coughing player's screen promises a kill the state graph will refuse.
	assert_false(
		(_ctx.pawn_contexts[B] as PawnContext).kill_ready,
		"a coughing figure's crosshair says a kill would land"
	)
	_press(B)
	_advance(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY") + 2)
	assert_eq(_state(B), PawnStateId.CHOKING, "a coughing figure started a kill")
	# **THE STATE ALONE PROVES NOTHING**: there is no `Choking -> KillAnim` edge, so
	# a system that judged the press anyway would leave B coughing and C dead.
	assert_false(
		CombatTargets.is_dead(_ctx.pawn_contexts[C] as PawnContext),
		"a coughing figure's kill landed although it never swung"
	)


# ------------------------------------------------- what the caster gets --


func test_the_caster_kills_inside_their_own_cloud() -> void:
	# **ADR-0023: CLOUD, THEN KILL INSIDE IT, IS THE ABILITY.**
	_hunter_and_contract()
	_ctx.cinderfall.add(Vector3.ZERO, _ctx.tick - 6, A)
	_press(A)
	_advance()
	assert_eq(_state(A), PawnStateId.KILL_ANIM, "the caster could not kill inside their own cloud")


func test_the_casters_pursuer_is_stunned_rather_than_caught() -> void:
	# The guide's *free 200-point stun*, and a prey's tooth in design law 5's sense.
	# **No tier floor on this route**: C has done nothing to be noticed.
	var landed: Array = []
	_system.stun.stunned.connect(func(s: int, t: int, _l: int) -> void: landed.append([s, t]))
	_hunter_and_contract()
	_place(C, Vector3(-2.0, 0.0, 0.0))
	_ctx.announced_contracts[C] = A
	_ctx.cinderfall.add(Vector3.ZERO, _ctx.tick, A)
	_advance()
	assert_eq(_state(C), PawnStateId.STUNNED, "the caster's pursuer was not stunned by the cloud")
	assert_eq(landed, [[A, C]], "the stun was not credited to the caster")
	assert_eq(_state(A), PawnStateId.IDLE, "the caster swung, but nobody pressed stun")


func test_with_the_switch_on_a_cloud_refuses_the_initiation_including_the_casters_own() -> void:
	# TDD-10 §3's first gate, **neutralised by ADR-0023 rather than removed**: with
	# `TUN-CINDERFALL-BLOCKS-KILL` back on, the gate still covers the caster, so
	# restoring the number restores the rule.
	var data := Tuning.ability_data(Ids.ABIL_CINDERFALL)
	var shipped := data.blocks_kill
	data.blocks_kill = true
	_hunter_and_contract()
	_ctx.cinderfall.add(Vector3.ZERO, _ctx.tick - 6, A)
	_press(A)
	_advance()
	data.blocks_kill = shipped
	assert_eq(_state(A), PawnStateId.IDLE, "the switch no longer reaches the kill gate")
	# The counterfactual: with the cloud gone, the identical press lands.
	_ctx.cinderfall.clear()
	_release(A)
	_advance()
	_press(A)
	_advance()
	assert_eq(_state(A), PawnStateId.KILL_ANIM, "the fixture cannot tell a cloud from a bad kill")


# ---------------------------------------------------------------- NPCs --


func test_the_cloud_holds_npcs_too() -> void:
	# Clone parity: if only players coughed, the still figures would be the players.
	_ctx.cinderfall.add(Vector3.ZERO, _ctx.tick, A)
	var crowd := PackedVector3Array([Vector3(1.0, 0.0, 0.0), Vector3(30.0, 0.0, 0.0)])
	var held := _ctx.cinderfall.held_among(crowd, crowd.size(), _ctx.tick)
	assert_true(held.has(0), "an NPC inside the cloud was not held")
	assert_false(held.has(1), "an NPC 30 m away was held")
	var later := _ctx.tick + Tuning.ticks(&"TUN-CINDERFALL-DURATION") + 1
	assert_true(
		_ctx.cinderfall.held_among(crowd, crowd.size(), later).is_empty(),
		"NPCs were still held after the cloud ended"
	)
