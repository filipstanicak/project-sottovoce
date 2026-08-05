## A blunt follow camera so a human can SEE the pawn move. US-0016 only.
##
## **THIS IS NOT THE CAMERA RIG.** `SYS-CAMERA` — spring arm, shoulder offset and
## swap, occlusion pull-in, the FOV ladder, crowd-scan — is US-0021 through
## US-0023, and every one of those is a design surface with its own tunables and
## its own acceptance criteria. Nothing here anticipates them.
##
## It exists because US-0016 connects a keyboard to the speed ladder, and M1's
## exit gate is *subjective*: it needs a human at the controls, and a human
## cannot judge how movement feels through a headless test. A pawn that walks
## with nothing rendering it is indistinguishable from one that does not.
##
## In `scripts/debug/`, which is stripped from release, so it cannot outlive the
## rig it is standing in for.
class_name DebugFollowCamera
extends Camera3D

@export var driver_path: NodePath

var _ctx: PawnContext


func _ready() -> void:
	var driver := get_node_or_null(driver_path) as LocalPawnDriver
	if driver == null:
		Log.error("DebugFollowCamera has no driver", &"debug")
		return
	driver.pawn_stepped.connect(_on_pawn_stepped)
	fov = Tuning.camera.fov_stroll


func _on_pawn_stepped(ctx: PawnContext) -> void:
	_ctx = ctx


func _process(_delta: float) -> void:
	if _ctx == null:
		return
	# Straight trigonometry, no smoothing and no spring. Smoothing is a feel
	# decision, and making one here would prejudge US-0021 with a number nobody
	# tuned.
	var pivot := _ctx.position + Vector3.UP * Tuning.camera.arm_height
	var back := Vector3(sin(_ctx.yaw), 0.0, cos(_ctx.yaw)) * Tuning.camera.arm_length
	global_position = pivot + back
	look_at(pivot, Vector3.UP)
