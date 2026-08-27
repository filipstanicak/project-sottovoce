## **A PLAYER INSIDE A CONCEALMENT PROP CANNOT BE KILLED, STUNNED OR DRAWN.**
## GDD-03 §4.1.4, US-0054.
##
## **THIS IS THE ONE EXCEPTION TO "BLEND PROTECTS ANONYMITY, NEVER THE BODY"**,
## and the exception is the GDD's rather than this project's convenience: *"cannot
## be broken from outside; a player inside cannot be killed"*. It is priced with
## total blindness and a fixed, learnable location — the prop is perfect and the
## walk to it never is.
##
## Every other blend is deliberately **not** protective. `test_blend_revalidated.gd`
## asserts that half; this file asserts the exception, so that a future reader
## comparing them can see the line rather than infer it.
extends GutTest

const HUNTER := 31
const PREY := 32

var _kills: KillSystem
var _ctx: MatchContext
var _machines: Array[PawnStateMachine] = []


func before_each() -> void:
	_machines.clear()
	_ctx = MatchContext.new()
	_ctx.tick = 300
	_kills = KillSystem.new()
	add_child_autofree(_kills)
	_kills.setup(_ctx)


func after_each() -> void:
	for machine: PawnStateMachine in _machines:
		machine.free()
	_machines.clear()


func _place(peer: int, at: Vector3, yaw: float = 0.0) -> PawnContext:
	var machine := PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		machine.register(script.new())
	_machines.append(machine)
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, yaw)
	machine.spawn_into(pawn, PawnStateId.IDLE)
	_ctx.pawn_contexts[peer] = pawn
	_ctx.pawn_machines[peer] = machine
	return pawn


## The hunter at the origin facing +Z with their contract 1.5 m ahead — inside
## both kill range and stun range, and Exposed so the stun's tier gate is open.
func _a_hunt() -> void:
	_place(HUNTER, Vector3.ZERO)
	_place(PREY, Vector3(0.0, 0.0, 1.5), PI)
	_ctx.announced_contracts[HUNTER] = PREY
	(_ctx.pawn_contexts[HUNTER] as PawnContext).tier = SuspicionMath.Tier.EXPOSED
	_settle()


func _settle() -> void:
	_ctx.lag_comp.clear()
	for back: int in range(8, 0, -1):
		var ids := PackedInt32Array()
		var places := PackedVector3Array()
		var yaws := PackedFloat32Array()
		for peer: int in _ctx.pawn_contexts.keys():
			var pawn := _ctx.pawn_contexts[peer] as PawnContext
			ids.append(peer)
			places.append(pawn.position)
			yaws.append(pawn.yaw)
		_ctx.lag_comp.record(_ctx.tick - back, ids, places, yaws)


func _conceal(peer: int) -> void:
	(_ctx.pawn_contexts[peer] as PawnContext).blend_state = BlendKind.Kind.PROP_CONCEAL


func _press(peer: int, bit: int) -> void:
	var command := InputCommand.empty(1)
	command.buttons = bit
	command.received_ordinal = 1
	if bit == InputBits.KILL:
		_kills.report_input(peer, command, MatchContext.step_dt())
		_kills.report_input(peer, command, MatchContext.step_dt())
	else:
		_kills.report_stun_input(peer, command, MatchContext.step_dt())
		_kills.report_stun_input(peer, command, MatchContext.step_dt())


func _advance() -> void:
	_ctx.tick += 1
	_kills.tick(_ctx, MatchContext.net_dt())


func test_the_hunt_lands_when_nobody_is_hiding() -> void:
	# **THE PREMISE.** Both refusals below are true of a fixture in which no kill
	# could ever land, and this is what stops the file passing that way.
	_a_hunt()
	_press(HUNTER, InputBits.KILL)
	_advance()
	assert_eq(
		(_ctx.pawn_contexts[HUNTER] as PawnContext).state_id,
		PawnStateId.KILL_ANIM,
		"the fixture cannot land a kill at all"
	)


func test_a_concealed_contract_cannot_be_killed() -> void:
	var rejected: Array = []
	_kills.kill_rejected.connect(func(k: int, v: int, t: int) -> void: rejected.append([k, v, t]))
	_a_hunt()
	_conceal(PREY)
	_press(HUNTER, InputBits.KILL)
	_advance()
	assert_eq(
		(_ctx.pawn_contexts[HUNTER] as PawnContext).state_id,
		PawnStateId.IDLE,
		"the killer committed to a target who is inside a hay cart"
	)
	assert_eq(rejected.size(), 1, "the press produced no whiff — silence is failure mode 7")
	assert_eq(int(rejected[0][1]), KillVerdict.V.TARGET_CONCEALED, "the wrong verdict")


func test_the_refused_killer_is_charged_nothing() -> void:
	# They pressed at somebody who is not there to be pressed at. Charging
	# suspicion would make a hiding spot a trap for whoever walked past it.
	_a_hunt()
	_conceal(PREY)
	_press(HUNTER, InputBits.KILL)
	_advance()
	assert_eq(_ctx.impulses.pending(HUNTER), 0.0, "the killer paid for the prop being occupied")
	assert_false(KillVerdict.costs_suspicion(KillVerdict.V.TARGET_CONCEALED))


func test_the_reticle_goes_dark_for_a_concealed_contract() -> void:
	_a_hunt()
	assert_true(_kills.ready_for(HUNTER, _ctx), "the hint is dark before anybody hides")
	_conceal(PREY)
	assert_false(_kills.ready_for(HUNTER, _ctx), "the reticle still promises a kill")


func test_a_concealed_pursuer_cannot_be_stunned() -> void:
	# The mirror image, and very nearly unreachable in a real match: a hunter
	# inside a hay cart can see nothing and is not closing on anybody. It exists
	# so the invulnerability means the same thing to both verbs.
	var landed: Array = []
	_kills.stun.stunned.connect(func(a: int, b: int, t: int) -> void: landed.append([a, b, t]))
	_a_hunt()
	_conceal(HUNTER)
	_press(PREY, InputBits.STUN)
	_advance()
	assert_eq(landed.size(), 0, "a player inside a hiding spot was stunned")
	assert_false(StunVerdict.costs_the_stunner(StunVerdict.V.TARGET_CONCEALED))


func test_every_other_blend_leaves_the_body_exactly_as_killable() -> void:
	# **THE LINE, ASSERTED FROM THE OTHER SIDE.** A pocket, a group and a lean are
	# anonymity and nothing else; only the concealment prop is cover. If this ever
	# went red the exception would have quietly become the rule, and patience would
	# be free rather than merely strongest — design law 4 read backwards.
	for kind: int in [BlendKind.Kind.POCKET, BlendKind.Kind.GROUP, BlendKind.Kind.PROP_STATIC]:
		_a_hunt()
		(_ctx.pawn_contexts[PREY] as PawnContext).blend_state = kind
		_press(HUNTER, InputBits.KILL)
		_advance()
		assert_eq(
			(_ctx.pawn_contexts[HUNTER] as PawnContext).state_id,
			PawnStateId.KILL_ANIM,
			"blend kind %d protected the body" % kind
		)
		after_each()
		before_each()
