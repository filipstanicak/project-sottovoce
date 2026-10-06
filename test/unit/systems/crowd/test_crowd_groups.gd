## **THE SERVER TAGS WHAT EACH CIVILIAN IS, FROM CIVILIANS ALONE.** US-0107.
##
## The net every client draws and the grey a blender sees both come from these
## tags, so a tag that depended on a player would be a marker over that player, and
## a tag that said less than membership would make the client guess from distance —
## which is what the review of #252 found it doing.
extends GutTest

const BOUNDS := AABB(Vector3.ZERO, Vector3(120.0, 12.0, 120.0))
const IDLE := NpcBrain.State.IDLE
const STROLL := NpcBrain.State.STROLL
const WALKING := NpcBrain.State.WALKING_GROUP
const FREE := LeanSpots.VACANT


func _hash(points: Array) -> SpatialHash:
	var hash := SpatialHash.new()
	hash.setup(BOUNDS, 16)
	hash.rebuild(PackedVector3Array(points), [], points.size())
	return hash


func _nobody_holds(count: int) -> PackedInt32Array:
	var holds := PackedInt32Array()
	holds.resize(count)
	holds.fill(FREE)
	return holds


func _tag(states: Array, holds := PackedInt32Array()) -> PackedByteArray:
	var held := holds if not holds.is_empty() else _nobody_holds(states.size())
	return CrowdGroups.tag_all(PackedInt32Array(states), [], held, states.size())


func test_a_standing_civilian_is_standing_and_a_walker_is_nothing() -> void:
	var tags := _tag([IDLE, STROLL, IDLE])
	assert_eq(Array(tags), [BlendGroupTag.STANDING, BlendGroupTag.NONE, BlendGroupTag.STANDING])


func test_a_walking_group_is_its_npc_occupants() -> void:
	var states := PackedInt32Array([WALKING, WALKING, STROLL, WALKING])
	# Two groups; the last slot of each is the player's and holds no NPC.
	var occupants := [PackedInt32Array([-1, -1, -1]), PackedInt32Array([0, 1, 3, -1])]
	var tags := CrowdGroups.tag_all(states, occupants, _nobody_holds(4), 4)
	assert_eq(Array(tags), [3, 3, 0, 3], "group 1 is FORMATION_BASE + 1")
	assert_eq(tags[0], BlendGroupTag.formation(1))


func test_a_civilian_holding_a_seat_is_tagged_with_that_seat() -> void:
	var tags := _tag([IDLE, IDLE], PackedInt32Array([13, FREE]))
	assert_eq(tags[0], BlendGroupTag.prop(13))
	assert_eq(BlendGroupTag.prop_of(tags[0]), 13)
	assert_eq(tags[1], BlendGroupTag.STANDING)


func test_tags_cover_the_whole_pool_and_inactive_npcs_are_none() -> void:
	var tags := CrowdGroups.tag_all(PackedInt32Array([STROLL]), [], _nobody_holds(1), 90)
	assert_eq(tags.size(), 90)
	assert_eq(tags.count(BlendGroupTag.NONE), 90)


func test_every_static_prop_and_circuit_fits_its_range_of_tags() -> void:
	var data: MapData = load(MapCatalogue.data_path(&"vetraio"))
	assert_ne(BlendGroupTag.prop(data.static_props.size() - 1), BlendGroupTag.NONE)
	assert_true(BlendGroupTag.is_formation(BlendGroupTag.formation(data.circuits.size() - 1)))


## **THE POCKET THE SERVER GRANTS GREYS EVERY STANDING CIVILIAN IT RESTS ON**, with
## the server's own tags rather than tags written by hand (review of #252).
func test_a_granted_pocket_greys_all_its_standing_civilians_and_no_walker() -> void:
	var me := Vector3(50, 0, 50)
	var points := [
		Vector3(50, 0, 50),
		Vector3(53.4, 0, 50),
		Vector3(46.6, 0, 50),
		Vector3(50, 0, 53.4),
		Vector3(50, 0, 47),
	]
	var hash := _hash(points)
	assert_gte(
		hash.count_within(me, Tuning.suspicion.blend_pocket_radius),
		Tuning.suspicion.blend_pocket_min_npc,
		"PREMISE: the server grants this pocket"
	)
	var tags := CrowdGroups.tag_all(
		PackedInt32Array([IDLE, IDLE, IDLE, IDLE, STROLL]), [], _nobody_holds(5), 5
	)
	var drawn: Dictionary = {}
	for index: int in points.size():
		drawn[index] = points[index]
	var greyed := BlendCueRules.greyed(BlendKind.Kind.POCKET, me, tags, drawn, [])
	greyed.sort()
	assert_eq(Array(greyed), [0, 1, 2, 3])


func test_only_what_changed_is_reported_and_the_table_lists_every_group() -> void:
	var groups := CrowdGroups.new()
	var first := PackedByteArray([0, 1, 1, 0])
	assert_eq(groups.apply(first), PackedByteArray([1, 1, 2, 1]), "the first table is all news")
	assert_eq(groups.apply(first), PackedByteArray(), "nothing moved, nothing to say")
	assert_eq(groups.apply(PackedByteArray([0, 0, 1, 2])), PackedByteArray([1, 0, 3, 2]))
	assert_eq(groups.full_table(), PackedByteArray([2, 1, 3, 2]))
