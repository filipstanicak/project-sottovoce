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


func test_in_a_pocket_every_standing_civilian_around_me_is_greyed_and_no_walker() -> void:
	# In a knot, standing alone, or holding a seat: all three stand, and all three
	# are what a pocket rests on. The walker at 1 m is not.
	var tags := _tags(
		{
			1: BlendGroupTag.STANDING,
			2: BlendGroupTag.STANDING,
			4: BlendGroupTag.prop(0),
			5: BlendGroupTag.STANDING
		}
	)
	var drawn := {
		1: ME + Vector3(1, 0, 0),
		2: ME + Vector3(0, 0, 2),
		3: ME + Vector3(0, 0, 1),
		4: ME + Vector3(-2, 0, 0),
		5: ME + Vector3(30, 0, 0),
	}
	var greyed := BlendCueRules.greyed(BlendKind.Kind.POCKET, ME, tags, drawn, [])
	greyed.sort()
	assert_eq(Array(greyed), [1, 2, 4])


func test_on_a_bench_the_holders_of_its_other_seats_are_greyed_wherever_they_stand() -> void:
	var seats := [Vector3(40, 0, 3), Vector3(40.8, 0, 3), Vector3(41.6, 0, 3)]
	var props: Array = seats + [Vector3(60, 0, 20)]
	# 1 holds seat 2 from 0.7 m away, inside the 1.2 m arrival; 2 walks past seat 1
	# at 0.2 m holding nothing; 3 holds the counter across the square.
	var tags := _tags({1: BlendGroupTag.prop(2), 3: BlendGroupTag.prop(3)})
	var drawn := {1: seats[2] + Vector3(0, 0, 0.7), 2: seats[1] + Vector3(0.2, 0, 0), 3: props[3]}
	var greyed := BlendCueRules.greyed(BlendKind.Kind.PROP_STATIC, seats[0], tags, drawn, props)
	assert_eq(Array(greyed), [1], "a holder missed, a passer-by greyed, or another prop's holder")


func test_at_a_counter_a_passer_by_brushing_it_is_not_greyed() -> void:
	var counter := Vector3(60, 0, 20)
	var drawn := {3: counter + Vector3(0.3, 0, 0)}
	var greyed := BlendCueRules.greyed(
		BlendKind.Kind.PROP_STATIC, counter, _tags({}), drawn, [counter]
	)
	assert_eq(greyed.size(), 0, "the review of #252's passer-by, greyed as a sitter")


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


func test_a_walking_group_and_a_full_circle_have_nets_and_three_standing_none() -> void:
	var walking := BlendGroupTag.formation(2)
	var tags := PackedByteArray()
	tags.resize(256)
	var drawn: Dictionary = {1: Vector3(10, 0, 10), 2: Vector3(12, 0, 10)}
	tags[1] = walking
	tags[2] = walking
	var anchor := Vector3(40, 0, 40)
	for i: int in 4:
		var turn := TAU * i / 4.0
		drawn[10 + i] = anchor + Vector3(cos(turn), 0, sin(turn)) * 0.9
		tags[10 + i] = BlendGroupTag.STANDING
	for i: int in 3:
		drawn[20 + i] = Vector3(80.0 + i, 0, 80)
		tags[20 + i] = BlendGroupTag.STANDING
	var nets := BlendCueRules.group_nets(tags, drawn)
	assert_eq(nets.size(), 2, "one walking group and one full circle; three standing are no pocket")
	var walking_net: Array = nets[0]
	assert_almost_eq((walking_net[0] as Vector3).x, 11.0, 0.001, "centred on its members")
	assert_almost_eq(float(walking_net[1]), 1.0 + BlendCueRules.NET_MARGIN, 0.001)
	var circle_net: Array = nets[1]
	assert_almost_eq(_flat_gap(circle_net[0], anchor), 0.0, 0.001, "centred in the circle")
	assert_almost_eq(
		float(circle_net[1]),
		Tuning.suspicion.blend_pocket_radius - 0.9,
		0.001,
		"every member within reach"
	)


func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_untagged_civilians_lie_under_no_net() -> void:
	assert_eq(BlendCueRules.group_nets(_tags({}), {1: ME, 2: ME + Vector3.RIGHT}).size(), 0)
