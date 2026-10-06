## **THE SERVER TAGS WHICH CIVILIANS FORM A GROUP, FROM CIVILIANS ALONE.** US-0107.
##
## The net every client draws comes from these tags, so a tag that depended on a
## player would be a marker over that player on every screen.
extends GutTest

const BOUNDS := AABB(Vector3.ZERO, Vector3(120.0, 12.0, 120.0))
const IDLE := NpcBrain.State.IDLE
const STROLL := NpcBrain.State.STROLL
const WALKING := NpcBrain.State.WALKING_GROUP


func _hash(points: Array) -> SpatialHash:
	var hash := SpatialHash.new()
	hash.setup(BOUNDS, 16)
	hash.rebuild(PackedVector3Array(points), [], points.size())
	return hash


## Four positions in a 1 m ring round `at`.
func _ring(at: Vector3) -> Array:
	return [
		at + Vector3(1, 0, 0), at + Vector3(-1, 0, 0), at + Vector3(0, 0, 1), at + Vector3(0, 0, -1)
	]


func test_enough_standing_civilians_together_are_a_group() -> void:
	var states := PackedInt32Array([IDLE, IDLE, IDLE, IDLE])
	var tags := CrowdGroups.tag_all(states, [], _hash(_ring(Vector3(50, 0, 50))), 4)
	for index: int in 4:
		assert_eq(tags[index], BlendGroupTag.STANDING, "civilian %d" % index)


func test_one_too_few_standing_is_no_group() -> void:
	var points := _ring(Vector3(50, 0, 50))
	var states := PackedInt32Array([IDLE, IDLE, IDLE, STROLL])
	var tags := CrowdGroups.tag_all(states, [], _hash(points), 4)
	assert_eq(Tuning.suspicion.blend_pocket_min_npc, 4, "PREMISE: four standing make a pocket")
	for index: int in 4:
		assert_eq(tags[index], BlendGroupTag.NONE, "a passer-by made civilian %d a group" % index)


func test_standing_civilians_far_apart_are_no_group() -> void:
	var points: Array = []
	for i: int in 4:
		points.append(Vector3(10.0 + i * 10.0, 0.0, 50.0))
	var tags := CrowdGroups.tag_all(
		PackedInt32Array([IDLE, IDLE, IDLE, IDLE]), [], _hash(points), 4
	)
	assert_eq(tags.count(BlendGroupTag.STANDING), 0)


func test_a_walking_group_is_its_npc_occupants() -> void:
	var points := [Vector3(10, 0, 10), Vector3(11, 0, 10), Vector3(80, 0, 80), Vector3(12, 0, 10)]
	var states := PackedInt32Array([WALKING, WALKING, STROLL, WALKING])
	# Two groups; the last slot of each is the player's and holds no NPC.
	var occupants := [PackedInt32Array([-1, -1, -1]), PackedInt32Array([0, 1, 3, -1])]
	var tags := CrowdGroups.tag_all(states, occupants, _hash(points), 4)
	assert_eq(tags[0], BlendGroupTag.formation(1))
	assert_eq(tags[1], BlendGroupTag.formation(1))
	assert_eq(tags[3], BlendGroupTag.formation(1))
	assert_eq(tags[2], BlendGroupTag.NONE)


func test_tags_cover_the_whole_pool_and_inactive_npcs_are_none() -> void:
	var tags := CrowdGroups.tag_all(PackedInt32Array([IDLE]), [], _hash([Vector3(5, 0, 5)]), 90)
	assert_eq(tags.size(), 90)
	assert_eq(tags.count(BlendGroupTag.NONE), 90)


func test_only_what_changed_is_reported_and_the_table_lists_every_group() -> void:
	var groups := CrowdGroups.new()
	var first := PackedByteArray([0, 1, 1, 0])
	assert_eq(groups.apply(first), PackedByteArray([1, 1, 2, 1]), "the first table is all news")
	assert_eq(groups.apply(first), PackedByteArray(), "nothing moved, nothing to say")
	assert_eq(groups.apply(PackedByteArray([0, 0, 1, 2])), PackedByteArray([1, 0, 3, 2]))
	assert_eq(groups.full_table(), PackedByteArray([2, 1, 3, 2]))
