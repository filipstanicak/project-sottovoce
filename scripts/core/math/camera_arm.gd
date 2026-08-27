## The spring arm's arithmetic. GDD-02 §4.1 and §4.4.
##
## **THIRD-PERSON, BECAUSE THE PLAYER MUST SEE THEIR OWN SILHOUETTE.** Judging
## *how do I look right now* is a core skill in a game where anonymity is the
## resource, and a first-person camera makes it impossible. Everything below
## exists to keep that view legible without ever letting it become an
## information channel of its own.
##
## PURE. Where the camera goes is arithmetic on a pivot, a facing and five
## tunables; whether something is in the way is a raycast, and that lives in
## `CameraRig`. Splitting them is what makes the fairness rule in §4.4 — the one
## that decides what a player can see around a corner — a unit test rather than
## something only observable by standing in a doorway.
class_name CameraArm
extends RefCounted

## **THE PAWN IS CENTRED. THERE IS NO LATERAL OFFSET.** GDD-02 §4.1.
##
## There was one, and it did nothing: the rig slid the camera 0.45 m sideways and
## then aimed at the pivot — the pawn's own axis — so the pawn re-centred in view
## however far the camera moved. The offset changed the viewing *angle* and never
## the composition, and nobody could see that while the pawn was invisible.
##
## It is gone rather than fixed, deliberately. A centred model is the right shot
## for a game whose player is reading their own silhouette; an over-the-shoulder
## offset exists to clear a firing line, and this game has none.


## Where the arm pivots: above the pawn's feet by `TUN-CAM-ARM-HEIGHT`, roughly
## shoulder height on the tallest persona.
static func pivot(feet: Vector3) -> Vector3:
	return feet + Vector3.UP * Tuning.camera.arm_height


## The pawn's facing, on the ground plane. Yaw 0 faces +Z, matching
## `ProbeLayout.forward` — the camera and the traversal probes must agree about
## which way "forward" is or the player aims one thing and probes another.
static func forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


## **THE GAME'S YAW FROM THE CAMERA NODE'S OWN.** They are not the same number,
## and the difference is exactly pi.
##
## This game's yaw 0 faces **+Z** (`forward` above, `ProbeLayout.forward` and
## `CompassMath.bearing_to` all agree). **Godot's yaw 0 faces −Z**, because a
## Node3D looks down its local −Z. The rig calls `look_at(pivot)` from behind the
## pawn, so its view direction is `forward(yaw)` — correct — while the Euler angle
## you read back off that basis is `yaw + PI`.
##
## **MEASURED, NOT REASONED**: a rig built by `position_at` and `look_at` reports
## `global_rotation.y` exactly half a turn from the yaw it was built with, at every
## yaw tested. `test_the_cone_points_at_the_contract.gd` is that measurement.
##
## It shipped without this conversion in US-0072 and the Compass cone was drawn
## half a turn out. Nothing else in the project meets both conventions:
## `PawnMotion` writes `body.rotation.y = ctx.yaw` and `GreyboxBody` is authored
## front-on-+Z to match, so the pawn is self-consistent. **The camera is the one
## node whose heading the engine computes**, which is why it is the one that had to
## be converted and the one nobody had converted.
static func yaw_from_camera(node_yaw: float) -> float:
	return node_yaw + PI


## The pawn's right. `forward × up`, the same derivation the ledge probes use.
static func right(yaw: float) -> Vector3:
	return forward(yaw).cross(Vector3.UP).normalized()


## The offset from pivot to camera. **BEHIND** the pawn, raised or lowered by
## pitch, on the centre line.
##
## Its LENGTH is the arm distance, and the occlusion clamp shortens along this
## exact vector. That is what keeps §4.4's rule true: the direction never changes,
## so the camera can never be nudged somewhere with a better view than the pawn
## has.
##
## **POSITIVE PITCH LOWERS THE ARM, BECAUSE THE RIG LOOKS AT THE PIVOT.** Pitch
## is the direction the PLAYER is looking, and to look up over the pawn the camera
## has to drop behind it — a camera raised above the pivot and pointed at it is
## looking *down*.
##
## It shipped the other way round from US-0021 until the owner played it and
## reported the vertical inverted. `test_camera_arm.gd` had asserted that pitching
## up raised the arm, which is true and is not the question: the question is where
## the resulting VIEW points, and the test never asked.
static func offset_direction(yaw: float, pitch: float) -> Vector3:
	var behind := -forward(yaw) * cos(pitch) * Tuning.camera.arm_length
	var lift := Vector3.DOWN * sin(pitch) * Tuning.camera.arm_length
	return behind + lift


## Where the camera would sit with nothing in the way.
static func ideal_position(feet: Vector3, yaw: float, pitch: float) -> Vector3:
	return pivot(feet) + offset_direction(yaw, pitch)


## Where the camera actually sits, `distance` metres along the ideal direction.
static func position_at(feet: Vector3, yaw: float, pitch: float, distance: float) -> Vector3:
	var offset := offset_direction(yaw, pitch)
	var length := offset.length()
	if length <= 0.0:
		return pivot(feet)
	return pivot(feet) + offset / length * distance


## **THE FAIRNESS RULE.** GDD-02 §4.4: the arm never passes through a wall to a
## position where the player can see around a corner they could not see around on
## foot. Where the pull-in would grant that, the camera pulls *in* rather than
## sideways.
##
## So an occluded arm is SHORTENED ALONG ITS OWN LINE, never slid along the
## surface. Sliding is what an ordinary spring arm does, and it is exactly what
## turns camera position into an information channel: a player pressed against a
## corner would get a free look down the street beyond it. Pulling in costs them
## the view instead, which is the honest answer — you cannot see round it,
## because you are not round it.
##
## `hit_distance` is how far along the ideal direction the world was struck, or
## `INF` for a clear line.
static func occluded_distance(ideal_distance: float, hit_distance: float) -> float:
	if hit_distance == INF:
		return ideal_distance
	var margin := Tuning.camera.occlusion_margin
	return clampf(hit_distance - margin, 0.0, ideal_distance)


## Move the current arm distance toward `wanted`, respecting the two rates.
##
## **PULL-IN IS FAST AND RESTORE IS SLOW**, 12 m/s against 4. Fast in, because a
## camera stuck inside a wall in a game about looking at people is a critical
## failure and every frame of it is lost information. Slow out, because a
## symmetric restore oscillates in a doorway — the arm clears the frame, springs
## back, collides again — and an oscillating camera is worse than a short one.
static func step_distance(current: float, wanted: float, delta: float) -> float:
	var rate := (
		Tuning.camera.occlusion_pull_rate
		if wanted < current
		else Tuning.camera.occlusion_restore_rate
	)
	return move_toward(current, wanted, rate * delta)


## Full arm length, for a frame with nothing in the way.
static func max_distance() -> float:
	return Tuning.camera.arm_length
