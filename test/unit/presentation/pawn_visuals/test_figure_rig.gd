## **ONE SKELETON, AND EVERY JOINT TURNS THE WAY ITS NAME SAYS.** US-0109.
##
## A pose is forward-positive numbers; the rig is where a sign can be wrong, and a
## knee that folds forwards is still a figure that walks.
extends GutTest

var _host: Node3D
var _rig: FigureRig


func before_each() -> void:
	_host = Node3D.new()
	add_child_autofree(_host)
	_rig = FigureRig.new(_host, FigureShape.of(&"", 1.8))


func _posed(joint: int, value: float) -> void:
	var pose := FigurePose.new()
	pose.put(joint, value)
	_rig.apply(pose)


## Every joint under `host`, by its path from the rig's root.
func _skeleton(host: Node3D) -> PackedStringArray:
	var out := PackedStringArray()
	for node: Node in host.find_children("*", "Node3D", true, false):
		if not node is MeshInstance3D:
			out.append(String(host.get_path_to(node)))
	return out


func test_every_figure_has_the_same_skeleton() -> void:
	var ids: Array[StringName] = []
	ids.append_array(CrowdRoster.PLAYABLE)
	ids.append_array(CrowdRoster.ARCHETYPES)
	var plain := _skeleton(_host)
	assert_eq(plain.size(), 14, "a pelvis, a trunk, a head, two arms and two legs")
	for id: StringName in ids:
		var host := Node3D.new()
		add_child_autofree(host)
		var built := FigureRig.new(host, FigureShape.of(id, 1.8))
		assert_not_null(built.root)
		assert_eq(_skeleton(host), plain, "%s has a skeleton of its own" % id)


func test_left_is_plus_x_as_the_probes_have_it() -> void:
	# `ProbeLayout.right(0)` is -X, so the figure's left is +X.
	assert_lt(ProbeLayout.right(0.0).x, 0.0)
	assert_gt(_rig.shoulders[FigureRig.LEFT].position.x, 0.0)
	assert_lt(_rig.shoulders[FigureRig.RIGHT].position.x, 0.0)
	assert_gt(_rig.thighs[FigureRig.LEFT].position.x, 0.0)


func test_at_rest_the_figure_stands_on_the_ground_with_its_arms_down() -> void:
	_rig.apply(FigurePose.new())
	var shape := _rig.shape
	for side: int in 2:
		assert_almost_eq(_rig.knees[side].global_position.y, shape.knee_y(), 0.001)
		assert_lt(_rig.hands[side].global_position.y, _rig.shoulders[side].global_position.y - 0.4)
	assert_almost_eq(_rig.knees[0].global_position.y - shape.shin(), FigureShape.FOOT_HEIGHT, 0.001)


func test_a_hip_swung_forward_puts_the_knee_ahead() -> void:
	_posed(FigurePose.HIP_L, 0.6)
	assert_gt(_rig.knees[FigureRig.LEFT].global_position.z, 0.15)
	assert_almost_eq(_rig.knees[FigureRig.RIGHT].global_position.z, 0.0, 0.001)


func test_a_bent_knee_takes_the_foot_back_and_up() -> void:
	_rig.apply(FigurePose.new())
	var foot := _rig.knees[FigureRig.LEFT].to_global(Vector3(0.0, -_rig.shape.shin(), 0.0))
	_posed(FigurePose.KNEE_L, 1.0)
	var bent := _rig.knees[FigureRig.LEFT].to_global(Vector3(0.0, -_rig.shape.shin(), 0.0))
	assert_lt(bent.z, foot.z - 0.2, "the knee folds forwards")
	assert_gt(bent.y, foot.y + 0.1)


func test_a_bent_elbow_brings_the_hand_forward() -> void:
	_posed(FigurePose.ELBOW_R, 1.2)
	assert_gt(_rig.hands[FigureRig.RIGHT].global_position.z, 0.15)


func test_an_arm_swung_forward_goes_forward() -> void:
	_posed(FigurePose.SHOULDER_L, 1.0)
	assert_gt(_rig.hands[FigureRig.LEFT].global_position.z, 0.3)


func test_an_arm_held_out_goes_outward_on_either_side() -> void:
	var pose := FigurePose.new()
	pose.both(FigurePose.ARM_OUT_L, 0.8)
	_rig.apply(pose)
	var left := _rig.hands[FigureRig.LEFT].global_position.x
	var right := _rig.hands[FigureRig.RIGHT].global_position.x
	assert_gt(left, _rig.shoulders[FigureRig.LEFT].global_position.x + 0.2)
	assert_lt(right, _rig.shoulders[FigureRig.RIGHT].global_position.x - 0.2)


func test_a_bend_at_the_waist_takes_the_head_forward() -> void:
	_posed(FigurePose.SPINE_PITCH, 0.6)
	assert_gt(_rig.neck.global_position.z, 0.2)


func test_a_figure_on_its_back_has_its_head_behind_its_feet() -> void:
	_posed(FigurePose.ROOT_PITCH, -PI * 0.5)
	assert_lt(_rig.neck.global_position.z, -1.0)
	assert_lt(_rig.neck.global_position.y, 0.2)


func test_a_stooped_shape_stoops_in_every_pose() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	var bent := FigureRig.new(host, FigureShape.of(Ids.ARCH_MENDICANT, 1.8))
	bent.apply(FigurePose.new())
	assert_gt(bent.neck.global_position.z, 0.1)


func test_a_seat_behind_the_figure_moves_all_of_it_back() -> void:
	_posed(FigurePose.ROOT_Z, -0.65)
	assert_almost_eq(_rig.hips.global_position.z, -0.65, 0.001)
