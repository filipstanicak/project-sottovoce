## **FIVE SLOTS, ONE OF THEM ALWAYS FREE.** US-0043, GDD-03 §4.1.2.
##
## The formation is pure arithmetic over a circuit, so "1.3 m spacing" and "with a
## joinable slot" — two thirds of an acceptance criterion — are asked directly
## rather than eyeballed in a running match.
extends GutTest

const SQUARE := [
	Vector3(0.0, 0.0, 0.0),
	Vector3(40.0, 0.0, 0.0),
	Vector3(40.0, 0.0, 40.0),
	Vector3(0.0, 0.0, 40.0),
]

var _group: WalkingGroup


func before_each() -> void:
	var circuit := CrowdCircuit.new()
	circuit.setup(PackedVector3Array(SQUARE))
	_group = WalkingGroup.new()
	_group.setup(circuit, int(Tuning.crowd.group_size), Tuning.crowd.group_spacing)


func test_there_is_one_more_slot_than_there_are_npcs() -> void:
	assert_eq(_group.slot_count(), int(Tuning.crowd.group_size) + 1)
	assert_eq(_group.joinable_slot(), int(Tuning.crowd.group_size))


func test_the_joinable_slot_is_never_given_to_an_npc() -> void:
	# **THE CRITERION'S REAL CONTENT.** A group whose last slot could be taken by
	# an NPC would be joinable or not depending on recruitment luck, and "there is
	# a group over there I can join" would stop being something a player can plan
	# around — which is the whole value of the only blend that lets you travel.
	for npc: int in 20:
		var slot := _group.free_npc_slot()
		if slot == WalkingGroup.EMPTY:
			break
		_group.occupy(slot, npc)
	assert_eq(_group.npc_count(), int(Tuning.crowd.group_size), "NPCs filled the joinable slot")
	assert_eq(
		_group.occupants[_group.joinable_slot()],
		WalkingGroup.EMPTY,
		"the joinable slot was taken by an NPC"
	)
	# And it refuses directly, not merely by never being offered.
	_group.occupy(_group.joinable_slot(), 99)
	assert_eq(_group.occupants[_group.joinable_slot()], WalkingGroup.EMPTY)


func test_the_closest_two_slots_are_exactly_the_documented_spacing() -> void:
	# **"LOOSE FORMATION AT 1.3 M SPACING" IS A NUMBER, NOT A FEELING.** A layout
	# whose real nearest-neighbour distance was 1.84 m would satisfy nobody's
	# reading of the criterion, and nothing else in the game would notice.
	var closest := INF
	for a: int in _group.slot_count():
		for b: int in range(a + 1, _group.slot_count()):
			closest = minf(closest, _group.slot_position(a).distance_to(_group.slot_position(b)))
	gut.p("closest pair of slots: %.3f m" % closest)
	assert_almost_eq(closest, Tuning.crowd.group_spacing, 0.001)


func test_no_two_slots_share_a_position() -> void:
	# The other half: a formation that collapsed every slot onto the leader would
	# also report a "closest pair" of 0 and would stack four NPCs on one point.
	var seen: Dictionary = {}
	for slot: int in _group.slot_count():
		var key := "%.2f,%.2f" % [_group.slot_position(slot).x, _group.slot_position(slot).z]
		assert_false(seen.has(key), "two slots are in the same place")
		seen[key] = true


func test_the_formation_turns_with_the_route() -> void:
	# Slots are offsets in the group's own frame. Slid along world axes instead,
	# the formation would walk sideways round every corner — four groups of
	# civilians crabbing through the district.
	var down_x := _group.slot_position(1) - _group.slot_position(0)
	_group.advance(50.0)  # past the first corner: now heading +Z
	var down_z := _group.slot_position(1) - _group.slot_position(0)
	assert_gt(
		down_x.normalized().distance_to(down_z.normalized()),
		0.5,
		"the slot offsets did not rotate with the circuit"
	)


func test_walking_moves_every_slot_together() -> void:
	var before: PackedVector3Array = []
	for slot: int in _group.slot_count():
		before.append(_group.slot_position(slot))
	_group.advance(5.0)
	for slot: int in _group.slot_count():
		assert_almost_eq(
			before[slot].distance_to(_group.slot_position(slot)),
			5.0,
			0.001,
			"slot %d did not travel with the group" % slot
		)


func test_occupancy_is_answerable_both_ways() -> void:
	_group.occupy(0, 42)
	assert_eq(_group.slot_of(42), 0)
	assert_eq(_group.occupants[0], 42)
	assert_eq(_group.slot_of(43), WalkingGroup.EMPTY, "an absent NPC reported a slot")
	_group.release(0)
	assert_eq(_group.slot_of(42), WalkingGroup.EMPTY)
	assert_eq(_group.npc_count(), 0)


func test_a_group_without_a_circuit_answers_rather_than_crashing() -> void:
	var orphan := WalkingGroup.new()
	orphan.setup(null, 4, 1.3)
	assert_eq(orphan.slot_position(0), Vector3.ZERO)
	assert_eq(orphan.free_npc_slot(), 0)
