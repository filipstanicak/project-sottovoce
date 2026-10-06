## **THE NET LIES UNDER EVERY BENCH AND GROUP; THE GREY IS ON THE BLENDER'S OWN.**
## US-0107. Reported from the controls on 2026-10-06: the crowd felt right and
## nothing said where a player could blend or whether they were.
extends GutTest


## The crowd as `BlendCues` reads it, without a server to describe it.
class FakeCrowd:
	extends NpcView
	var bodies: Dictionary = {}

	func body_of(index: int) -> PersonaBody:
		return bodies.get(index) as PersonaBody

	func indices() -> Array:
		return bodies.keys()


var _crowd: FakeCrowd
var _me: Node3D
var _my_body: PersonaBody
var _cues: BlendCues


func before_each() -> void:
	_crowd = FakeCrowd.new()
	add_child_autofree(_crowd)
	_me = Node3D.new()
	add_child_autofree(_me)
	_me.position = Vector3(50, 0, 50)
	_my_body = PersonaBody.new()
	_me.add_child(_my_body)
	_cues = BlendCues.new()
	add_child_autofree(_cues)


func after_each() -> void:
	EventBus.blend_state_changed.emit(BlendKind.Kind.NONE)


func _civilian(index: int, at: Vector3) -> PersonaBody:
	var body := PersonaBody.new()
	_crowd.add_child(body)
	body.global_position = at
	_crowd.bodies[index] = body
	return body


func _nets_shown() -> int:
	var shown := 0
	for child: Node in _cues.get_children():
		if (child as MeshInstance3D).visible:
			shown += 1
	return shown


func test_every_bench_seat_and_counter_has_a_net_from_the_start() -> void:
	var props := [Vector3(40, 0, 3), Vector3(40.8, 0, 3), Vector3(60, 0, 20)]
	_cues.bind(_crowd, _me, _my_body, props)
	assert_eq(_nets_shown(), props.size())


func test_a_group_the_server_names_gets_a_net_and_loses_it_when_it_parts() -> void:
	_cues.bind(_crowd, _me, _my_body, [])
	_civilian(1, Vector3(20, 0, 20))
	_civilian(2, Vector3(21, 0, 20))
	_cues._process(0.0)
	assert_eq(_nets_shown(), 0, "a net under civilians the server never named")
	var walking := BlendGroupTag.formation(0)
	_cues.apply_groups(true, PackedByteArray([1, walking, 2, walking]))
	_cues._process(0.0)
	assert_eq(_nets_shown(), 1)
	_cues.apply_groups(false, PackedByteArray([1, 0, 2, 0]))
	_cues._process(0.0)
	assert_eq(_nets_shown(), 0)


func test_a_full_table_replaces_and_a_change_amends() -> void:
	_cues.apply_groups(true, PackedByteArray([1, 1, 2, 1]))
	_cues.apply_groups(false, PackedByteArray([2, 0]))
	assert_eq(_cues.tags[1], 1)
	assert_eq(_cues.tags[2], 0)
	_cues.apply_groups(true, PackedByteArray([3, 1]))
	assert_eq(_cues.tags[1], 0, "a full table kept a tag it did not list")


func test_blended_in_a_pocket_greys_me_and_my_group_and_nobody_else() -> void:
	_cues.bind(_crowd, _me, _my_body, [])
	var friend := _civilian(1, Vector3(51, 0, 50))
	var stranger := _civilian(2, Vector3(50, 0, 51))
	_cues.apply_groups(true, PackedByteArray([1, BlendGroupTag.STANDING]))
	EventBus.blend_state_changed.emit(BlendKind.Kind.POCKET)
	_cues._process(0.0)
	assert_true(_my_body.is_greyed(), "the blended player is not greyed")
	assert_true(friend.is_greyed())
	assert_false(stranger.is_greyed(), "a passer-by was greyed as one of the group")
	EventBus.blend_state_changed.emit(BlendKind.Kind.NONE)
	_cues._process(0.0)
	assert_false(_my_body.is_greyed(), "the grey outlived the blend")
	assert_false(friend.is_greyed())


func test_inside_a_hiding_spot_nothing_is_greyed() -> void:
	_cues.bind(_crowd, _me, _my_body, [])
	EventBus.blend_state_changed.emit(BlendKind.Kind.PROP_CONCEAL)
	_cues._process(0.0)
	assert_false(_my_body.is_greyed())
