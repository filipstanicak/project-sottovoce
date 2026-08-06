## `SYS-CAMERA`. The third-person spring arm. GDD-02 §4.1 and §4.4.
##
## **CLIENT ONLY**, and the thing `DebugFollowCamera` was standing in for since
## US-0016. Where the camera goes is `CameraArm`, which is pure; what is in the
## way is the raycast below, which is the only part that needs a world.
##
## Two rules here are fairness rules rather than feel ones, and neither may be
## traded away for a nicer shot:
##
## 1. **NPCs do not occlude.** The arm collides with `WORLD` only. If a crowd
##    pushed the camera in, the safest place in the game would become the place
##    where the camera is least usable — and the crowd is the game.
## 2. **The arm pulls IN, never sideways.** A spring arm that slides along a
##    surface hands a player pressed against a corner a free look down the street
##    beyond it. Camera position must never be an information channel.
##
## The FOV ladder is US-0022 and crowd-scan is US-0023. This rig holds a fixed
## FOV and does not read `INPUT-SCAN`.
class_name CameraRig
extends Camera3D

## Radians per pixel of mouse motion, and per second at full stick deflection.
##
## NOT TUNABLES. A tunable decides how the game plays for everyone; look
## sensitivity is a per-player preference in the same class as a volume slider,
## and belongs to `IProfileStore` — stubbed in MVP (ASM-0026), so it does not
## persist yet. `InputSampler` carries the same two for the same reason.
@export var mouse_sensitivity: float = 0.0022
@export var pad_look_speed: float = 3.2

## How far the player may look up and down, in degrees. Not a tunable either:
## it is the gimbal limit, and past it the arm inverts.
@export var pitch_limit_degrees: float = 70.0

@export var driver_path: NodePath
@export var sampler_path: NodePath

var _driver: LocalPawnDriver
var _yaw: float = 0.0
var _pitch: float = 0.0
var _shoulder: float = float(CameraArm.Shoulder.RIGHT)
var _shoulder_target: float = float(CameraArm.Shoulder.RIGHT)
var _distance: float = 0.0
var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_driver = get_node_or_null(driver_path) as LocalPawnDriver
	var sampler := get_node_or_null(sampler_path) as InputSampler
	if _driver == null or sampler == null:
		Log.error("CameraRig is not wired to a driver and a sampler", &"camera")
		set_process(false)
		return
	sampler.command_sampled.connect(_on_command_sampled)
	_distance = CameraArm.max_distance()
	fov = Tuning.camera.fov_stroll


## The look is read from the sampled command rather than from `Input`, so the
## camera turns with the same numbers the pawn does — and so a replay that
## re-feeds commands would reproduce the framing exactly.
func _on_command_sampled(command: InputCommand) -> void:
	if not _controlled():
		return
	_yaw = command.look_yaw
	_pitch = clampf(command.look_pitch, -_pitch_limit(), _pitch_limit())


## Swap shoulders. Called by whoever handles `INPUT-SHOULDER`; the swap itself
## takes `TUN-CAM-SHOULDER-SWAP-TIME` and is interruptible half-way.
func swap_shoulder() -> void:
	_shoulder_target = -_shoulder_target


func shoulder_blend() -> float:
	return _shoulder


func arm_distance() -> float:
	return _distance


## Rendered rate, not the physics tick: the camera is presentation, and a camera
## that moved at 60 Hz on a 144 Hz display would judder against a pawn whose
## position is interpolated.
func _process(delta: float) -> void:
	if _driver == null:
		return
	var ctx := _driver.ctx
	if not _controlled():
		# **SNAPPED TO A FIXED OFFSET.** Being stunned takes the look as well as
		# the legs; the player watches whatever is in front of them while their
		# target walks away. Design law 5, and not to be softened.
		_yaw = ctx.yaw
		_pitch = 0.0

	_shoulder = CameraArm.blend_shoulder(_shoulder, _shoulder_target, delta)
	_distance = CameraArm.step_distance(_distance, _wanted_distance(ctx), delta)

	global_position = CameraArm.position_at(ctx.position, _yaw, _pitch, _shoulder, _distance)
	look_at(CameraArm.pivot(ctx.position), Vector3.UP)


func _controlled() -> bool:
	return _driver == null or _driver.camera_controlled()


func _pitch_limit() -> float:
	return deg_to_rad(pitch_limit_degrees)


## How long the arm may be this frame: the full length, or short of whatever the
## world put in the way.
func _wanted_distance(ctx: PawnContext) -> float:
	var offset := CameraArm.offset_direction(_yaw, _pitch, _shoulder)
	var ideal := offset.length()
	if ideal <= 0.0:
		return 0.0
	return CameraArm.occluded_distance(ideal, _hit_distance(ctx, offset))


## Distance to the first `WORLD` surface along the arm, or `INF`.
##
## **`WORLD` ONLY.** Named through `CollisionLayers`, the same mask the traversal
## probes use and for a related reason: a camera that collided with `PAWN` or
## `NPC` would be pushed in by the crowd, and §4.4 rule 1 forbids exactly that.
func _hit_distance(ctx: PawnContext, offset: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return INF
	var from := CameraArm.pivot(ctx.position)
	_query.from = from
	_query.to = from + offset
	_query.collision_mask = CollisionLayers.WORLD
	_query.collide_with_areas = false
	_query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(_query)
	return INF if hit.is_empty() else from.distance_to(hit["position"] as Vector3)
