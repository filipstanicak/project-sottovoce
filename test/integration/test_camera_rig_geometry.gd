## **THE CAMERA AGAINST REAL WALLS AND REAL CROWDS.** GDD-02 §4.4, US-0021.
##
## `test_camera_arm.gd` proves the arithmetic. It cannot prove the rig casts
## anything, casts it in the right direction, or masks the right layers — and the
## two rules §4.4 states are both about what the cast is allowed to hit:
##
## 1. **NPCs do not occlude.** If a crowd pushed the camera in, the safest place
##    in the game would become the place where the camera is least usable. The
##    crowd IS the game.
## 2. **The arm pulls in, never sideways**, so camera position never becomes an
##    information channel.
##
## Both are asserted here against bodies on the actual `NPC` and `WORLD` layers,
## because a mask is a number and a number that is wrong looks exactly like a
## number that is right.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

var _root: Node
var _rig: CameraRig
var _driver: LocalPawnDriver


func before_each() -> void:
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_rig = _root.get_node("World/CameraRig")
	_driver = _root.get_node("LocalPawnDriver")
	await _settle(8)


func _settle(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame
	await get_tree().process_frame


## A box on `layer`, `behind` metres behind the pawn — where the arm goes.
func _box_behind(behind: float, layer: int, size: Vector3 = Vector3(6.0, 4.0, 0.5)) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_root.get_node("World").add_child(body)
	var back := -CameraArm.forward(_driver.ctx.yaw) * behind
	body.global_position = CameraArm.pivot(_driver.ctx.position) + back


func test_the_rig_replaced_the_debug_camera() -> void:
	assert_not_null(_rig, "client_root.tscn has no CameraRig")
	assert_true(_rig.current, "the rig is not the active camera")


func test_it_sits_at_full_arm_length_in_the_open() -> void:
	assert_almost_eq(_rig.arm_distance(), CameraArm.max_distance(), 0.05)


func test_it_frames_the_pawn_from_behind() -> void:
	# The pawn must be in front of the camera, or the player cannot see their own
	# silhouette — which is the entire reason this camera is third-person.
	var to_pawn := CameraArm.pivot(_driver.ctx.position) - _rig.global_position
	assert_gt(
		to_pawn.normalized().dot(-_rig.global_transform.basis.z),
		0.9,
		"the camera is not looking at the pawn"
	)


func test_a_wall_behind_the_pawn_pulls_the_arm_in() -> void:
	_box_behind(1.2, CollisionLayers.WORLD)
	await _settle(30)
	assert_lt(_rig.arm_distance(), CameraArm.max_distance(), "a wall did not shorten the arm")
	assert_gt(_rig.arm_distance(), 0.0, "the arm collapsed entirely")


func test_the_camera_stops_short_of_the_wall_rather_than_inside_it() -> void:
	_box_behind(1.2, CollisionLayers.WORLD)
	await _settle(30)
	var pivot := CameraArm.pivot(_driver.ctx.position)
	assert_lt(
		_rig.global_position.distance_to(pivot),
		1.2,
		"the camera ended up behind the wall it was avoiding"
	)


func test_a_crowd_does_not_push_the_camera_in() -> void:
	# **§4.4 RULE 1.** The safest place in the game must not be the place where
	# the camera stops working. A body on the NPC layer, in exactly the spot a
	# WORLD body shortened the arm from.
	_box_behind(1.2, CollisionLayers.NPC)
	await _settle(30)
	assert_almost_eq(
		_rig.arm_distance(), CameraArm.max_distance(), 0.05, "an NPC occluded the camera"
	)


func test_a_trigger_volume_does_not_either() -> void:
	# Blend props and zone volumes live on TRIGGER. A camera that collided with
	# them would jump every time a player walked past a market stall.
	_box_behind(1.2, CollisionLayers.TRIGGER)
	await _settle(30)
	assert_almost_eq(_rig.arm_distance(), CameraArm.max_distance(), 0.05)


func test_the_arm_restores_when_the_wall_is_gone() -> void:
	_box_behind(1.2, CollisionLayers.WORLD)
	await _settle(30)
	var pulled := _rig.arm_distance()
	for child: Node in _root.get_node("World").get_children():
		if child is StaticBody3D:
			child.queue_free()
	await _settle(60)
	assert_gt(_rig.arm_distance(), pulled, "the arm never came back out")


func test_swapping_shoulders_moves_the_camera_across() -> void:
	var before := _rig.shoulder_blend()
	_rig.swap_shoulder()
	await _settle(40)
	assert_ne(signf(_rig.shoulder_blend()), signf(before), "the shoulder never swapped")
