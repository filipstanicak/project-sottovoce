## **A FIGURE'S JOINTS, AND THE BODY HUNG ON THEM.** US-0109. CLIENT ONLY.
##
## The same skeleton for every figure in the district: pelvis, trunk, head, two
## arms of two bones, two legs of two bones. **One rig, built by one function**,
## so "the player rig and the clone rig" — the pair ANIMATION_SPEC §7 guards with
## four layers — is not a pair. What differs between figures is `FigureShape`'s
## numbers and what `FigureGarments` hangs on the joints.
##
## `+Z` is forward and `+X` is the figure's left, as `ProbeLayout` has it.
## A pose's angles are forward-positive; `apply` knows which way each joint turns.
class_name FigureRig
extends RefCounted

const LEFT := 0
const RIGHT := 1

var shape: FigureShape
## Everything turns about this, at the feet.
var root: Node3D
var hips: Node3D
var spine: Node3D
var neck: Node3D
var shoulders: Array[Node3D] = []
var elbows: Array[Node3D] = []
var hands: Array[Node3D] = []
var thighs: Array[Node3D] = []
var knees: Array[Node3D] = []


func _init(host: Node3D, figure: FigureShape) -> void:
	shape = figure
	root = _joint(host, "Rig", Vector3.ZERO)
	hips = _joint(root, "Hips", Vector3(0.0, shape.hip_y(), 0.0))
	spine = _joint(hips, "Spine", Vector3.ZERO)
	var shoulder_rise := shape.shoulder_y() - shape.hip_y()
	neck = _joint(spine, "Neck", Vector3(0.0, shoulder_rise + 0.05 * shape.scale(), 0.0))
	for side: int in 2:
		var out := side_sign(side)
		var shoulder := Vector3(out * shape.shoulder_half(), shoulder_rise - 0.02, 0.0)
		shoulders.append(_joint(spine, "Shoulder%d" % side, shoulder))
		elbows.append(_joint(shoulders[side], "Elbow", Vector3(0.0, -shape.upper_arm(), 0.0)))
		hands.append(_joint(elbows[side], "Hand", Vector3(0.0, -shape.forearm(), 0.0)))
		thighs.append(_joint(hips, "Thigh%d" % side, Vector3(out * shape.hip_half(), 0.0, 0.0)))
		knees.append(_joint(thighs[side], "Knee", Vector3(0.0, -shape.thigh(), 0.0)))


## `+1` on the figure's left, `-1` on its right.
static func side_sign(side: int) -> float:
	return 1.0 if side == LEFT else -1.0


static func _joint(parent: Node3D, name: String, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = name
	joint.position = at
	parent.add_child(joint)
	return joint


## One part of the body: `mesh` in `colour`, `at` on `joint`.
func part(joint: Node3D, name: String, mesh: Mesh, at: Vector3, colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.position = at
	instance.material_override = FigureParts.paint(colour)
	instance.set_meta(&"base", colour)
	joint.add_child(instance)
	return instance


## Put every joint where `pose` says.
func apply(pose: FigurePose) -> void:
	root.position = Vector3(0.0, pose.at(FigurePose.ROOT_Y), pose.at(FigurePose.ROOT_Z))
	root.rotation.x = pose.at(FigurePose.ROOT_PITCH)
	hips.position = Vector3(
		pose.at(FigurePose.HIPS_X),
		shape.hip_y() + pose.at(FigurePose.HIPS_Y),
		pose.at(FigurePose.HIPS_Z)
	)
	hips.rotation = Vector3(0.0, pose.at(FigurePose.HIPS_YAW), pose.at(FigurePose.HIPS_ROLL))
	spine.rotation = Vector3(
		pose.at(FigurePose.SPINE_PITCH) + shape.stoop,
		pose.at(FigurePose.SPINE_YAW),
		pose.at(FigurePose.SPINE_ROLL)
	)
	neck.rotation = Vector3(pose.at(FigurePose.HEAD_PITCH), pose.at(FigurePose.HEAD_YAW), 0.0)
	for side: int in 2:
		var out := side_sign(side)
		shoulders[side].rotation = Vector3(
			-pose.at(FigurePose.SHOULDER_L + side), 0.0, out * pose.at(FigurePose.ARM_OUT_L + side)
		)
		elbows[side].rotation.x = -pose.at(FigurePose.ELBOW_L + side)
		thighs[side].rotation.x = -pose.at(FigurePose.HIP_L + side)
		knees[side].rotation.x = pose.at(FigurePose.KNEE_L + side)
