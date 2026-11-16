## **ONE FIGURE'S MOTION, FRAME TO FRAME.** ADR-0026, US-0109. CLIENT ONLY.
##
## What a figure looks like right now is decided from three things and only three:
## **how its body is moving, where it is standing, and what it is doing.** A local
## player, another player and a civilian are all asked the same three questions
## by the same code, and none of the answers says which of them is asking. That is
## the whole of clone parity here (ANIMATION_SPEC §1): not a matched pair of clip
## libraries, but one function with no argument for "is a player".
##
## **THE STRIDE FOLLOWS THE GROUND**, not a clock: the cycle advances by distance
## covered, so feet do not slide and a figure that slows mid-step slows its step.
class_name FigureAnimator
extends RefCounted

## How fast a pose is eased toward the one wanted, per second.
const EASE := 14.0
## How fast the measured speed is smoothed. Snapshots arrive in steps.
const SPEED_EASE := 10.0
## How long a figure stands on a seat or at a counter before it settles into it.
const SETTLE := 0.4
## Metres of wall one hand-over-hand cycle climbs.
const CLIMB_REACH := 0.9
## The least a walking figure reaches with a step, as a share of a full stride.
const SHORT_STEP := 0.4

## Every figure takes the next step of one sequence for its own idle offset, so no
## two breathe in time and nothing about the offset says who the figure is.
static var _made := 0

var act := FigureMotion.Act.NONE

var _pose := FigurePose.new()
var _phase := 0.0
var _clock := 0.0
var _own := 0.0
var _still := 0.0
var _act_time := 0.0
var _speed := 0.0


func _init() -> void:
	_own = fposmod(float(_made) * 0.618034, 1.0) * TAU
	_made += 1


## What the figure is doing beyond moving. The same act again changes nothing.
func set_act(to: FigureMotion.Act) -> void:
	if to == act:
		return
	act = to
	_act_time = 0.0


## The smoothed ground speed this figure is animated at.
func speed() -> float:
	return _speed


## Whether the figure has stood long enough to take the posture of where it is.
func is_settled() -> bool:
	return _still >= SETTLE and act == FigureMotion.Act.NONE


## The pose after `delta` more seconds, moving at `velocity` and facing `forward`.
## `place` is `FigurePlaces.at()`'s answer for where the figure stands.
func advance(
	delta: float, velocity: Vector3, forward: Vector3, shape: FigureShape, place: Array
) -> FigurePose:
	_clock += delta
	_act_time += delta
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	_speed = lerpf(_speed, flat.length(), 1.0 - exp(-SPEED_EASE * delta))
	if act == FigureMotion.Act.CLIMB:
		_phase += absf(velocity.y) * delta / CLIMB_REACH * TAU
	elif _speed > FigureMotion.STILL:
		# Backwards, the cycle runs backwards: the legs reach the way the body goes.
		var going := -1.0 if flat.dot(forward) < 0.0 else 1.0
		_phase += going * _speed * delta / FigureMotion.cycle_metres(_speed) * TAU
	_still = _still + delta if _speed < FigureMotion.STILL else 0.0
	_pose.ease_toward(_wanted(shape, place), 1.0 - exp(-EASE * delta))
	return _pose


## The pose this figure is heading for.
func _wanted(shape: FigureShape, place: Array) -> FigurePose:
	var target := FigurePose.new()
	var posture: int = place[0] if is_settled() and not place.is_empty() else 0
	if posture == FigureMotion.Posture.SIT:
		FigureMotion.sit(target, shape.hip_y() - FigurePlaces.SEAT_HEIGHT, float(place[2]))
		FigureMotion.look_round(target, _clock, _own)
	elif posture == FigureMotion.Posture.LEAN:
		FigureMotion.lean(target)
		FigureMotion.look_round(target, _clock, _own)
	elif FigureActs.keeps_the_gait(act) and _speed > FigureMotion.STILL:
		var stride := clampf(_speed / Tuning.movement.blend_walk, SHORT_STEP, 1.0)
		FigureMotion.gait(target, _phase, stride, FigureMotion.haste(_speed))
	elif FigureActs.keeps_the_gait(act):
		FigureMotion.idle(target, _clock, _own)
	FigureActs.pose(target, act, _act_time, _phase)
	_carry(target, shape)
	return target


## An arm with something in it holds it, and does not swing.
func _carry(target: FigurePose, shape: FigureShape) -> void:
	if act == FigureMotion.Act.FALL or act == FigureMotion.Act.CLIMB:
		return
	if shape.holds(FigureRig.RIGHT):
		target.put(FigurePose.SHOULDER_R, 0.5)
		target.put(FigurePose.ELBOW_R, 1.25)
		target.put(FigurePose.ARM_OUT_R, 0.12)
	if shape.holds(FigureRig.LEFT):
		target.put(FigurePose.SHOULDER_L, 0.15)
		target.put(FigurePose.ELBOW_L, 0.95)
		target.put(FigurePose.ARM_OUT_L, 0.22)
