## **WHERE EVERY JOINT OF A FIGURE IS.** ADR-0026, US-0109. CLIENT ONLY. PURE.
##
## One flat list of numbers, so two poses blend by blending their lists and a
## figure eases from one to the next without a clip, a tree or a track. Angles are
## in radians and **forward is positive** for every limb: a hip of 0.4 is a leg
## swung forward, an elbow of 1.0 is a forearm bent up. `FigureRig` knows which
## way each joint actually turns.
class_name FigurePose
extends RefCounted

enum {
	## The pelvis, in metres from where it stands, and its tilts.
	HIPS_X,
	HIPS_Y,
	HIPS_Z,
	HIPS_ROLL,
	HIPS_YAW,
	## The trunk over the pelvis.
	SPINE_PITCH,
	SPINE_ROLL,
	SPINE_YAW,
	HEAD_PITCH,
	HEAD_YAW,
	## Left then right, always.
	SHOULDER_L,
	SHOULDER_R,
	ARM_OUT_L,
	ARM_OUT_R,
	ELBOW_L,
	ELBOW_R,
	HIP_L,
	HIP_R,
	KNEE_L,
	KNEE_R,
	## The whole figure about its feet: lying down, and moved back onto a seat.
	ROOT_PITCH,
	ROOT_Y,
	ROOT_Z,
	COUNT,
}

## Add 1 to a left joint's index for the right one.
const RIGHT := 1

var values := PackedFloat32Array()


func _init() -> void:
	values.resize(COUNT)
	values.fill(0.0)


func at(index: int) -> float:
	return values[index]


func put(index: int, value: float) -> void:
	values[index] = value


## Both sides of a paired joint at once: `index` is the left one.
func both(index: int, value: float) -> void:
	values[index] = value
	values[index + RIGHT] = value


func copy() -> FigurePose:
	var out := FigurePose.new()
	out.values = values.duplicate()
	return out


## Move every joint `weight` of the way toward `target`'s.
func ease_toward(target: FigurePose, weight: float) -> void:
	for i: int in COUNT:
		values[i] = lerpf(values[i], target.values[i], weight)
