## **THE FIVE VALIDATIONS, EACH REFUSING FOR ITS OWN REASON.** TDD-09 §1.1,
## US-0066.
##
## Every one is server-side, and the request carries **no outcome** — only a slot
## and an aim. So the only thing a client can get wrong that is not simply refused
## is where it was pointing, and that is clamped (`test_ability_aim_clamped.gd`).
##
## **THE ORDER IS PART OF THE SPECIFICATION, NOT AN IMPLEMENTATION DETAIL.** It is
## cheapest-first, and it is also the order a player would want to hear: *you do
## not have that* before *not yet*, and both before anything about your body. A
## player told `ILLEGAL_STATE` for a slot they never equipped would go looking for
## the wrong problem.
extends GutTest

const READY := 100
const LATER := 200


func _why(
	equipped: bool = true,
	tick: int = READY,
	ready_at: int = 0,
	global_at: int = 0,
	state: StringName = PawnStateId.IDLE
) -> AbilityDenial.Why:
	return AbilityRules.check(equipped, tick, ready_at, global_at, state)


func test_a_legal_request_is_not_refused() -> void:
	# **THE PREMISE.** Every assertion below is satisfied by a validator that
	# refuses everything, which is the commonest way a gate test passes wrongly.
	assert_eq(_why(), AbilityDenial.Why.NONE, "a legal request was refused")


func test_an_unequipped_slot_is_refused() -> void:
	assert_eq(_why(false), AbilityDenial.Why.NOT_EQUIPPED)


func test_a_slot_still_on_its_own_cooldown_is_refused() -> void:
	assert_eq(_why(true, READY, LATER), AbilityDenial.Why.ON_COOLDOWN)
	assert_eq(_why(true, LATER, LATER), AbilityDenial.Why.NONE, "the deadline is inclusive")


func test_the_global_cooldown_is_refused_separately() -> void:
	# A separate reason because it is a separate fact: your other ability is
	# available and you still may not cast, which a player needs told differently
	# from "that one is not ready".
	assert_eq(_why(true, READY, 0, LATER), AbilityDenial.Why.GLOBAL_COOLDOWN)


func test_every_forbidden_state_is_refused_and_the_rest_are_not() -> void:
	# **A DENYLIST, NOT AN ALLOWLIST.** The legal states are every other one —
	# walking, running, climbing, vaulting, blending, falling — and an allowlist
	# would silently forbid each future locomotion state nobody remembered.
	for state: StringName in AbilityRules.FORBIDDEN:
		assert_eq(
			_why(true, READY, 0, 0, state), AbilityDenial.Why.ILLEGAL_STATE, "%s allowed" % state
		)
	var allowed := 0
	for state: StringName in PawnStateId.ALL:
		if state in AbilityRules.FORBIDDEN:
			continue
		allowed += 1
		assert_eq(
			_why(true, READY, 0, 0, state), AbilityDenial.Why.NONE, "%s was forbidden" % state
		)
	assert_gt(
		allowed, 7, "only %d states were allowed; the denylist has grown into a list" % allowed
	)


func test_the_forbidden_states_are_the_ones_the_document_names() -> void:
	# TDD-09 §1.1: *not `Stunned`, `Dead`, `KillAnim`, `Respawning`*. `StunAnim` is
	# the fifth and is this file's own addition — a player mid-stun-swing is as
	# committed as one mid-kill, and GDD-02 §3.1 gives both the same interrupt row.
	for state: StringName in [
		PawnStateId.STUNNED,
		PawnStateId.DEAD,
		PawnStateId.KILL_ANIM,
		PawnStateId.RESPAWNING,
		PawnStateId.STUN_ANIM,
	]:
		assert_has(AbilityRules.FORBIDDEN, state, "%s is castable" % state)
	assert_eq(AbilityRules.FORBIDDEN.size(), 5, "the denylist grew without a decision")


func test_the_order_is_cheapest_and_most_useful_first() -> void:
	# All four wrong at once. The answer must be the first rung, not the last —
	# telling a player their state is illegal for a slot they never equipped sends
	# them after the wrong problem.
	assert_eq(
		_why(false, READY, LATER, LATER, PawnStateId.DEAD),
		AbilityDenial.Why.NOT_EQUIPPED,
		"the ladder does not answer with its first rung"
	)
	assert_eq(
		_why(true, READY, LATER, LATER, PawnStateId.DEAD),
		AbilityDenial.Why.ON_COOLDOWN,
		"the ladder does not answer with its second rung"
	)


func test_every_reason_has_a_string_key() -> void:
	# **A REASON WITH NO STRING IS A DENIAL THE PLAYER IS NEVER TOLD**, and it would
	# be invisible: the HUD would simply say nothing, which is GDD-02 §9's failure
	# mode 7 with a mechanism.
	for why: int in AbilityDenial.Why.values():
		if why == AbilityDenial.Why.NONE:
			continue
		assert_ne(AbilityDenial.key_for(why), &"", "reason %d has no string key" % why)


func test_no_reason_describes_anybody_but_the_presser() -> void:
	# **THE OPPOSITE OF THE STUN REFUSAL, DELIBERATELY.** `SYS-STUN` answers every
	# rejection identically, because a reason there would be a free identity probe.
	# Every reason here is a fact about the presser's own kit, cooldown, state or
	# aim — so being helpful costs nobody their anonymity.
	var source := "res://scripts/core/ability/ability_denial.gd"
	for term: String in ["contract", "pursuer", "target", "persona", "tier"]:
		assert_false(
			SourceScanner.code_contains(source, term),
			"a denial reason mentions `%s`, which is a fact about somebody else" % term
		)
