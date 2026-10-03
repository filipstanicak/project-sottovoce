## **THE STUN HINT LIGHTS FOR ANY FIGURE IN REACH, SO IT NAMES NOBODY.** ADR-0022 A,
## owner decision 2026-10-01.
##
## `stun_ready` is drawn on the prey's own screen. Since any pursuer can be stunned,
## a hint lit for the pursuer alone would point them out of the crowd for free —
## the leak the tier gate used to close for this bit. Lit for every figure in reach
## and cone, player or civilian, it says *a swing would reach someone* and nothing
## about who. Moved out of `test_stun_system.gd`, which the length guard capped.
extends GutTest

const PREY := 81
const HUNTER := 82
const STRANGER := 83

var _kills: KillSystem
var _ctx: MatchContext
var _machines: Array[PawnStateMachine] = []


func before_each() -> void:
	_machines.clear()
	_ctx = MatchContext.new()
	_ctx.tick = 200
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


func _advance() -> void:
	_ctx.tick += 1
	_kills.tick(_ctx, MatchContext.net_dt())


func _ready_bit(peer: int) -> bool:
	return (_ctx.pawn_contexts[peer] as PawnContext).stun_ready


func _crowd(points: PackedVector3Array) -> void:
	_ctx.crowd_hash.setup(AABB(Vector3(-20, -10, -20), Vector3(40, 20, 40)), 8)
	_ctx.crowd_hash.rebuild(points, [], points.size())


## **A PURSUER AND A STRANGER AT THE SAME SPOT GIVE THE SAME BIT**, or the hint
## would tell them apart.
func test_the_ready_bit_lights_for_any_player_in_reach() -> void:
	_place(PREY, Vector3.ZERO)
	_place(HUNTER, Vector3(0.0, 0.0, 2.0), PI)
	_ctx.announced_contracts[HUNTER] = PREY
	(_ctx.pawn_contexts[HUNTER] as PawnContext).tier = SuspicionMath.Tier.ANONYMOUS
	_advance()
	assert_true(_ready_bit(PREY), "the hint is dark for an Anonymous pursuer in reach")
	_ctx.announced_contracts.erase(HUNTER)
	_advance()
	assert_true(_ready_bit(PREY), "the hint told a pursuer from a stranger at the same spot")


func test_the_ready_bit_lights_for_a_civilian_in_reach_and_not_behind() -> void:
	_place(PREY, Vector3.ZERO)
	_crowd(PackedVector3Array([Vector3(0.0, 0.0, 2.0)]))
	_advance()
	assert_true(_ready_bit(PREY), "the hint is dark for a civilian in reach")
	_crowd(PackedVector3Array([Vector3(0.0, 0.0, -2.0)]))
	_advance()
	assert_false(_ready_bit(PREY), "the hint lit for a civilian behind the prey")


func test_the_ready_bit_is_dark_for_nobody_and_for_a_concealed_occupant() -> void:
	_place(PREY, Vector3.ZERO)
	var other := _place(STRANGER, Vector3(0.0, 0.0, 6.0))
	_advance()
	assert_false(_ready_bit(PREY), "the hint lit with nobody in reach")
	other.position = Vector3(0.0, 0.0, 2.0)
	other.blend_state = BlendKind.Kind.PROP_CONCEAL
	_advance()
	assert_false(_ready_bit(PREY), "the hint opened a hiding spot")
