## Every case the resolver can return names a state the graph can actually enter.
##
## Split from `test_traversal_resolution.gd`, which asserts the *ordering*. This
## asserts the *mapping* — a different failure with a different symptom: a
## resolver that ordered its cases perfectly and then requested a state no edge
## reaches would assert at the first vault, in play, not in a test.
##
## **Seven cases, four states.** Gap jump and drop both enter `Drop`; vault and
## mantle both enter `Vault`. Each state branches internally on the numbers the
## probes left, and the collapse is asserted here so it stays a decision rather
## than becoming a surprise.
extends GutTest


func test_every_case_maps_to_a_declared_state() -> void:
	var wrong: PackedStringArray = []
	for case: int in TraversalResolver.Case.values():
		var id := TraversalResolver.state_for(case)
		if case == TraversalResolver.Case.NONE:
			if id != PawnState.STAY:
				wrong.append("NONE maps to %s, not silence" % id)
			continue
		if not PawnStateId.exists(id):
			wrong.append("case %d maps to unknown state %s" % [case, id])
	assert_eq(wrong.size(), 0, "\n".join(wrong))


func test_the_two_pairs_collapse_as_the_tdd_says() -> void:
	# Gap jump and drop both enter Drop; vault and mantle both enter Vault. Each
	# state branches internally on the numbers the probes left. Asserted so the
	# collapse stays a decision rather than becoming a surprise.
	assert_eq(TraversalResolver.state_for(TraversalResolver.Case.GAP_JUMP), PawnStateId.DROP)
	assert_eq(TraversalResolver.state_for(TraversalResolver.Case.DROP), PawnStateId.DROP)
	assert_eq(TraversalResolver.state_for(TraversalResolver.Case.VAULT), PawnStateId.VAULT)
	assert_eq(TraversalResolver.state_for(TraversalResolver.Case.MANTLE), PawnStateId.VAULT)
	assert_eq(TraversalResolver.state_for(TraversalResolver.Case.LEDGE_GRAB), PawnStateId.CLIMB)


func test_every_resolved_state_is_reachable_from_locomotion() -> void:
	# A resolver that returned a state the graph cannot enter would assert at the
	# first vault. Checked against the real transition table, from every
	# locomotion state, because that is where a traverse is pressed from.
	var illegal: PackedStringArray = []
	for case: int in TraversalResolver.Case.values():
		var id := TraversalResolver.state_for(case)
		if id == PawnState.STAY:
			continue
		for from: StringName in PawnStateId.LOCOMOTION:
			if not PawnTransitions.allows(from, id):
				illegal.append("%s -> %s" % [from, id])
	illegal.sort()
	assert_eq(illegal.size(), 0, "the resolver can request an illegal edge:\n" + "\n".join(illegal))
