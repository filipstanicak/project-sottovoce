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

## Which shoulder the camera sits over. The sign multiplies
## `TUN-CAM-SHOULDER-OFFSET`.
enum Shoulder { RIGHT = 1, LEFT = -1 }


## Where the arm pivots: above the pawn's feet by `TUN-CAM-ARM-HEIGHT`, roughly
## shoulder height on the tallest persona.
static func pivot(feet: Vector3) -> Vector3:
	return feet + Vector3.UP * Tuning.camera.arm_height


## The pawn's facing, on the ground plane. Yaw 0 faces +Z, matching
## `ProbeLayout.forward` — the camera and the traversal probes must agree about
## which way "forward" is or the player aims one thing and probes another.
static func forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


## The pawn's right. `forward × up`, the same derivation the ledge probes use.
static func right(yaw: float) -> Vector3:
	return forward(yaw).cross(Vector3.UP).normalized()


## The offset from pivot to camera. **BEHIND** the pawn, raised or lowered by
## pitch, and displaced to one shoulder.
##
## `shoulder_blend` runs −1 (left) to +1 (right) and is interpolated during a
## swap, so the camera slides across rather than teleporting.
##
## Its LENGTH is the arm distance including the lateral component, and the
## occlusion clamp shortens along this exact vector. That is what keeps §4.4's
## rule true: the direction never changes, so the camera can never be nudged
## somewhere with a better view than the pawn has.
static func offset_direction(yaw: float, pitch: float, shoulder_blend: float) -> Vector3:
	var behind := -forward(yaw) * cos(pitch) * Tuning.camera.arm_length
	var lift := Vector3.UP * sin(pitch) * Tuning.camera.arm_length
	var lateral := right(yaw) * Tuning.camera.shoulder_offset * clampf(shoulder_blend, -1.0, 1.0)
	return behind + lift + lateral


## Where the camera would sit with nothing in the way.
static func ideal_position(
	feet: Vector3, yaw: float, pitch: float, shoulder_blend: float
) -> Vector3:
	return pivot(feet) + offset_direction(yaw, pitch, shoulder_blend)


## Where the camera actually sits, `distance` metres along the ideal direction.
static func position_at(
	feet: Vector3, yaw: float, pitch: float, shoulder_blend: float, distance: float
) -> Vector3:
	var offset := offset_direction(yaw, pitch, shoulder_blend)
	var length := offset.length()
	if length <= 0.0:
		return pivot(feet)
	return pivot(feet) + offset / length * distance


## How far the shoulder blend moves in `delta`, given `TUN-CAM-SHOULDER-SWAP-TIME`.
##
## The blend spans 2.0 — right to left is +1 to −1 — so the rate is 2 / the time,
## and a swap takes exactly the tunable however far through a previous one it was
## interrupted.
static func shoulder_step(delta: float) -> float:
	var seconds := maxf(Tuning.camera.shoulder_swap_time, 0.001)
	return delta * 2.0 / seconds


## Advance a shoulder blend toward `target`, which is +1 or −1.
static func blend_shoulder(current: float, target: float, delta: float) -> float:
	return move_toward(current, clampf(target, -1.0, 1.0), shoulder_step(delta))


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
