## **A KILL NEEDS A CLEAR LINE TO ITS CONTRACT.** ADR-0015.
##
## `KillRules` is pure and cannot reach `has_los`, so the requirement arrives as a
## `Callable` and this file supplies fake ones. What it asserts is the *shape* the
## ADR chose: **sight filters target selection, exactly like range and cone** — an
## occluded contract is simply not a candidate, rather than a gate applied after
## one has been picked.
extends GutTest

const KILLER := 1
const CONTRACT := 2
const STRANGER := 3

var _t: CombatTuning
var _asked: Array = []


func before_each() -> void:
	_t = Tuning.combat
	_asked = []


## Killer at the origin facing +Z; everybody else is placed by the caller.
func _world(places: Dictionary) -> RewoundWorld:
	var world := RewoundWorld.new()
	for peer: int in places:
		world.add(peer, places[peer] as Vector3, 0.0)
	return world


func _blind() -> Callable:
	return func(a: Vector3, b: Vector3) -> bool:
		_asked.append([a, b])
		return false


func _clear() -> Callable:
	return func(a: Vector3, b: Vector3) -> bool:
		_asked.append([a, b])
		return true


func _resolve(places: Dictionary, others: PackedInt32Array, sees := Callable()) -> Array:
	return KillRules.resolve(_world(places), KILLER, CONTRACT, others, _t, sees)


func test_a_clear_line_kills() -> void:
	# **THE PREMISE.** Every refusal below is satisfied by a rule that refuses
	# everything, and this is what stops the file passing that way.
	var v := _resolve(
		{KILLER: Vector3.ZERO, CONTRACT: Vector3(0.0, 0.0, 2.0)},
		PackedInt32Array([CONTRACT]),
		_clear()
	)
	assert_eq(int(v[0]), KillVerdict.V.ALLOWED, "a contract two metres ahead in the open")
	assert_eq(int(v[1]), CONTRACT)


func test_geometry_between_you_refuses_the_kill() -> void:
	var v := _resolve(
		{KILLER: Vector3.ZERO, CONTRACT: Vector3(0.0, 0.0, 2.0)},
		PackedInt32Array([CONTRACT]),
		_blind()
	)
	assert_eq(int(v[0]), KillVerdict.V.OUT_OF_SIGHT, "the kill went through the wall")
	assert_true(
		KillVerdict.costs_suspicion(KillVerdict.V.OUT_OF_SIGHT), "swinging at a wall is free"
	)


func test_an_unbound_predicate_answers_nothing_blocks() -> void:
	# **NOT A SPECIAL CASE**: it is what `DetectionSystem._clear_of_geometry`
	# answers in a context with no world, so a pure test and a district agree.
	# `test_sight_is_wired_into_the_kill.gd` is what stops it reaching a server.
	var v := _resolve(
		{KILLER: Vector3.ZERO, CONTRACT: Vector3(0.0, 0.0, 2.0)}, PackedInt32Array([CONTRACT])
	)
	assert_eq(int(v[0]), KillVerdict.V.ALLOWED, "an unbound predicate refused a kill")


func test_sight_is_asked_about_the_two_bodies_and_nothing_else() -> void:
	_resolve(
		{KILLER: Vector3.ZERO, CONTRACT: Vector3(0.0, 0.0, 2.0)},
		PackedInt32Array([CONTRACT]),
		_clear()
	)
	assert_gt(_asked.size(), 0, "the predicate was never consulted; the gate is inert")
	for pair: Array in _asked:
		assert_eq(pair[0] as Vector3, Vector3.ZERO, "asked from somewhere other than the killer")


func test_an_occluded_contract_does_not_shield_a_stranger_in_the_open() -> void:
	# **THIS IS WHY SIGHT FILTERS SELECTION RATHER THAN GATING THE RESULT.** A
	# stranger standing in the open between you and a contract behind a stall must
	# still absorb the press and still earn `TUN-KILL-INVALID-TARGET-PENALTY` — you
	# may not safely test whether a stranger is your contract, and a rule that
	# refused the whole press on the contract's occlusion would hand you exactly
	# that test for free.
	var sees := func(_a: Vector3, b: Vector3) -> bool: return not is_equal_approx(b.z, 2.0)
	var v := _resolve(
		{KILLER: Vector3.ZERO, CONTRACT: Vector3(0.0, 0.0, 2.0), STRANGER: Vector3(0.0, 0.0, 1.0)},
		PackedInt32Array([CONTRACT, STRANGER]),
		sees
	)
	assert_eq(int(v[0]), KillVerdict.V.WRONG_TARGET, "the occluded contract swallowed the press")
	assert_eq(int(v[1]), STRANGER, "the stranger did not absorb it")


func test_no_refusal_reports_occlusion_to_the_presser() -> void:
	# **THE VERDICT IS SERVER-SIDE AND STAYS THERE.** `NET-S2C-KILL-RESULT` carries
	# slots, a tick and a bonus group — never a reason — so the whiff is identical
	# whatever refused it. A reason on the wire would make the kill button a probe
	# for where a wall stands relative to your contract, which is the same leak
	# `StunVerdict` refuses for identity.
	var wire := SourceScanner.read("res://scripts/net/event_wire.gd")
	assert_false(wire.contains("KillVerdict"), "a kill verdict reached the wire")
	assert_false(wire.contains("OUT_OF_SIGHT"), "occlusion is reported to the client")
