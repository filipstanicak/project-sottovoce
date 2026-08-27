## **THE GATE IS ONLY REAL IF SOMEBODY BINDS IT.** ADR-0015.
##
## `KillSystem.sight` is unbound by default and an unbound predicate answers
## *nothing blocks*, which is the correct answer for a unit test with no district
## and the **wrong** one for a shipped server. That is a vacuous-success shape by
## construction: forget the binding and every kill passes, every existing test
## stays green, and the only symptom is a kill through a market stall.
##
## So the binding is asserted, and so is the default it depends on — an assertion
## about the binding alone would still pass if the default became permissive in
## the other direction, and one about the default alone proves nothing ships.
extends GutTest

const KILLER := 1
const CONTRACT := 2

const SERVER := "res://scripts/server/server_root.gd"
const DETECTION := "res://scripts/systems/detection/detection_system.gd"
const STUN := "res://scripts/systems/combat/stun_system.gd"


func test_the_server_binds_the_predicate() -> void:
	assert_true(
		SourceScanner.code_contains(SERVER, "kills.sight = detection.clear_line"),
		"server_root does not bind SYS-KILL's sight; every kill passes through geometry"
	)


func test_the_default_is_unbound_so_the_binding_is_load_bearing() -> void:
	var kills := KillSystem.new()
	assert_false(kills.sight.is_valid(), "the predicate is bound somewhere other than the server")
	assert_true(
		KillRules.can_see(kills.sight, Vector3.ZERO, Vector3(0, 0, 2)),
		"an unbound predicate refuses; a district-less unit test would see no kills at all"
	)
	kills.free()


func test_the_lift_to_chest_height_happens_once_and_in_the_query() -> void:
	# **A FOOT-TO-FOOT RAY HITS THE FLOOR.** `RewoundWorld` holds feet, so a caller
	# that forgets the lift gets a world with no line of sight in it — which looks
	# exactly like a rule that works and refuses everything. It lives beside
	# `sight_point` rather than at each call site for that reason.
	assert_true(
		SourceScanner.code_contains(DETECTION, "has_los(sight_point(from), sight_point(to))"),
		"clear_line no longer lifts both endpoints"
	)
	assert_gt(DetectionSystem.sight_point(Vector3.ZERO).y, 0.0, "sight_point is the identity")


## A killer at the origin facing +Z with their contract 1.5 m ahead — inside both
## reach and cone, so only sight can refuse it.
func _a_hunt(kills: KillSystem) -> MatchContext:
	var ctx := MatchContext.new()
	ctx.tick = 300
	for peer: int in [KILLER, CONTRACT]:
		var pawn := PawnContext.new()
		pawn.peer_id = peer
		pawn.reset_for_spawn(Vector3(0.0, 0.0, 1.5) if peer == CONTRACT else Vector3.ZERO, 0.0)
		pawn.state_id = PawnStateId.IDLE
		ctx.pawn_contexts[peer] = pawn
	ctx.announced_contracts[KILLER] = CONTRACT
	kills.setup(ctx)
	return ctx


func test_the_reticle_hint_carries_the_gate_too() -> void:
	# **A HINT THAT DISAGREES WITH THE RULE TEACHES THE PLAYER TO STOP READING IT**
	# — `stun_ready`'s lesson from US-0061, in the other combat verb. Without this,
	# the reticle would light up across a market stall and the press would whiff.
	var kills := KillSystem.new()
	add_child_autofree(kills)
	var ctx := _a_hunt(kills)
	assert_true(kills.ready_for(KILLER, ctx), "the fixture cannot light the reticle at all")
	kills.sight = func(_a: Vector3, _b: Vector3) -> bool: return false
	assert_false(kills.ready_for(KILLER, ctx), "the reticle still promises a kill through a wall")


func test_the_stun_deliberately_has_no_sight_gate() -> void:
	# **NEVER-DO #13: DO NOT WEAKEN STUN.** A sight gate on the stun would be a
	# weakening, and the asymmetry it leaves is the same one the range advantage
	# already expresses — the stun reaches 3.35 m where the kill reaches 2.85, and
	# now it reaches through a stall where the kill does not. Design law 5.
	#
	# **ASSERTED SO THAT "FIXING" IT IS A DELIBERATE ACT.** ADR-0015 records it as
	# the one part of that decision the owner may want the other way.
	assert_false(
		(
			SourceScanner.code_contains(STUN, "clear_line")
			or SourceScanner.code_contains(STUN, "has_los")
		),
		"SYS-STUN gained a line-of-sight gate; that is a weakening — read ADR-0015 first"
	)
