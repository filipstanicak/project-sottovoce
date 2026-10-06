## **THE GREY NAMES THE GROUP, NOT THE RADIUS; THE NET LIES UNDER EACH GROUP.**
## US-0107.
extends GutTest

const ME := Vector3(50, 0, 50)


func _tags(pairs: Dictionary) -> PackedByteArray:
	var tags := PackedByteArray()
	tags.resize(256)
	for index: int in pairs:
		tags[index] = pairs[index]
	return tags


func test_in_a_walking_group_the_members_of_the_nearest_group_are_greyed() -> void:
	var near := BlendGroupTag.formation(0)
	var far := BlendGroupTag.formation(1)
	var tags := _tags({1: near, 2: near, 3: far, 4: BlendGroupTag.NONE})
	var drawn := {
		1: ME + Vector3(1, 0, 0),
		2: ME + Vector3(2.5, 0, 0),
		3: ME + Vector3(9, 0, 0),
		4: ME + Vector3(0.5, 0, 0),
	}
	var greyed := BlendCueRules.greyed(BlendKind.Kind.GROUP, ME, tags, drawn, [])
	assert_eq(Array(greyed), [1, 2], "not the other group, and not the passer-by beside me")


func test_in_a_pocket_the_standing_civilians_around_me_are_greyed_and_no_walker() -> void:
	var tags := _tags(
		{1: BlendGroupTag.STANDING, 2: BlendGroupTag.STANDING, 5: BlendGroupTag.STANDING}
	)
	var drawn := {
		1: ME + Vector3(1, 0, 0),
		2: ME + Vector3(0, 0, 2),
		3: ME + Vector3(0, 0, 1),
		5: ME + Vector3(30, 0, 0),
	}
	var greyed := BlendCueRules.greyed(BlendKind.Kind.POCKET, ME, tags, drawn, [])
	greyed.sort()
	assert_eq(Array(greyed), [1, 2])


func test_on_a_bench_the_other_sitters_are_greyed_and_at_a_counter_nobody() -> void:
	var seats := [Vector3(40, 0, 3), Vector3(40.8, 0, 3), Vector3(41.6, 0, 3)]
	var counter := Vector3(60, 0, 20)
	var props: Array = seats + [counter]
	var drawn := {1: seats[2], 2: Vector3(45, 0, 3), 3: counter + Vector3(0.3, 0, 0)}
	var tags := _tags({})
	var on_bench := BlendCueRules.greyed(BlendKind.Kind.PROP_STATIC, seats[0], tags, drawn, props)
	assert_eq(Array(on_bench), [1])
	var leaning := BlendCueRules.greyed(BlendKind.Kind.PROP_STATIC, counter, tags, drawn, props)
	assert_eq(Array(leaning), [3], "only the counter itself, which a player holding it keeps empty")


func test_a_bench_is_one_piece_of_furniture_and_a_stall_has_two_sides() -> void:
	# The seats of one bench stand 0.8 m apart; a stall's two lean spots 2.8 m.
	var props := [
		Vector3(0, 0, 0),
		Vector3(0.8, 0, 0),
		Vector3(1.6, 0, 0),
		Vector3(10, 0, 0),
		Vector3(10, 0, 2.8)
	]
	assert_eq(Array(BlendCueRules.furniture_of(1, props)).size(), 3)
	assert_eq(Array(BlendCueRules.furniture_of(3, props)), [3])


func test_nothing_is_greyed_when_not_blended_or_hidden() -> void:
	var tags := _tags({1: BlendGroupTag.STANDING})
	var drawn := {1: ME + Vector3(1, 0, 0)}
	for kind: int in [BlendKind.Kind.NONE, BlendKind.Kind.PROP_CONCEAL]:
		assert_eq(BlendCueRules.greyed(kind, ME, tags, drawn, []).size(), 0)


func test_each_group_has_one_net_and_two_circles_apart_are_two() -> void:
	var walking := BlendGroupTag.formation(2)
	var tags := _tags(
		{
			1: walking,
			2: walking,
			3: BlendGroupTag.STANDING,
			4: BlendGroupTag.STANDING,
			5: BlendGroupTag.STANDING
		}
	)
	var drawn := {
		1: Vector3(10, 0, 10),
		2: Vector3(12, 0, 10),
		3: Vector3(40, 0, 40),
		4: Vector3(41, 0, 40),
		5: Vector3(70, 0, 40),
	}
	var nets := BlendCueRules.group_nets(tags, drawn)
	assert_eq(nets.size(), 3, "one walking group and two knots of standing civilians")
	var walking_net: Array = nets[0]
	assert_almost_eq((walking_net[0] as Vector3).x, 11.0, 0.001, "centred on its members")
	assert_almost_eq(float(walking_net[1]), 1.0 + BlendCueRules.NET_MARGIN, 0.001)


func test_untagged_civilians_lie_under_no_net() -> void:
	assert_eq(BlendCueRules.group_nets(_tags({}), {1: ME, 2: ME + Vector3.RIGHT}).size(), 0)
