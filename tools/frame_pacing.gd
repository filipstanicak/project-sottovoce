## **HOW SMOOTHLY A CLIENT ACTUALLY DRAWS.** US-0045.
##
## The owner reported the pawn jittering when NPCs are present. Two different
## things can cause that and they need different fixes, so this measures both.
##
## **1. FRAME PACING — is the client missing frames?** Measured on **wall clock**,
## never `Performance.TIME_PROCESS`: TDD-08 §11.2.1 records that counter reporting
## 31 ms, then 5.69, then 24–28 for arrangements whose real frame time never moved
## off 16.73 ms. A cost larger than the frame containing it is a broken instrument.
## The interval between frames cannot be larger than itself.
##
## **2. DRAWN MOTION — does a rendered frame show anything new?** Everything in the
## world is moved in `_physics_process` at `physics_ticks_per_second`, and a client
## renders far faster than that. Without interpolation each position is drawn
## several times before it changes, so bodies advance in visible steps while the
## camera — which runs on `_process` — slides between them. **That is the jitter**,
## and the fraction below is the physics rate over the frame rate. A client that
## interpolates reads 100 %.
##
## Pure and node-free so the probe that owns it stays under 400 lines.
class_name FramePacing
extends RefCounted

## How many bodies to watch. A sample, not a census: the question is whether *any*
## position changed this frame, and twelve moving bodies answer it as well as
## seventy at a twelfth of the cost.
const WATCHED := 12

var _frames: PackedFloat32Array = PackedFloat32Array()
var _last_usec: int = 0
var _drawn: Dictionary = {}
var _render_frames: int = 0
var _moved_frames: int = 0


## Call once per rendered frame, with the nodes whose motion should be judged.
func sample(bodies: Array) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_frames.append(float(now - _last_usec) / 1000.0)
	_last_usec = now

	var moved := false
	for index: int in mini(WATCHED, bodies.size()):
		var body := bodies[index] as Node3D
		if body == null:
			continue
		# **THE DRAWN TRANSFORM, NOT THE SIMULATION ONE.** With
		# `physics/common/physics_interpolation` on, `global_position` still reports
		# the value from the last physics tick — the interpolated transform the
		# renderer actually uses is a different quantity. Reading the wrong one made
		# this tool report 36.9 % both before and after the fix, which reads exactly
		# like a fix that did nothing.
		var at := body.get_global_transform_interpolated().origin
		var was: Variant = _drawn.get(body.name)
		if was != null and not (was as Vector3).is_equal_approx(at):
			moved = true
		_drawn[body.name] = at
	_render_frames += 1
	if moved:
		_moved_frames += 1


## The lines a reader needs, or one saying why there are none.
func lines() -> Array[String]:
	if _frames.size() < 30:
		return ["too few frames to judge pacing"] as Array[String]
	var sorted := Array(_frames)
	sorted.sort()
	var total := 0.0
	var late := 0
	for value: float in sorted:
		total += float(value)
		if float(value) > 20.0:
			late += 1
	var out: Array[String] = []
	out.append("physics interpolation: %s" % ("ON" if _interpolating() else "OFF"))
	out.append(_interval_line(sorted, total))
	out.append(
		(
			"  %d of %d frames took over 20 ms (%.1f %%)"
			% [late, sorted.size(), float(late) / float(sorted.size()) * 100.0]
		)
	)
	out.append_array(_motion_lines())
	return out


static func _interpolating() -> bool:
	return bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))


static func _interval_line(sorted: Array, total: float) -> String:
	return (
		"frame interval over %d frames: mean %.2f ms, p50 %.2f, p95 %.2f, max %.2f"
		% [
			sorted.size(),
			total / float(sorted.size()),
			float(sorted[sorted.size() / 2]),
			float(sorted[int(float(sorted.size()) * 0.95)]),
			float(sorted[-1])
		]
	)


func _motion_lines() -> Array[String]:
	if _render_frames == 0:
		return [] as Array[String]
	var share := float(_moved_frames) / float(_render_frames) * 100.0
	var out: Array[String] = []
	out.append(
		(
			"  %d of %d rendered frames showed a NEW position (%.1f %%)"
			% [_moved_frames, _render_frames, share]
		)
	)
	out.append(
		(
			"  100 %% is a client that interpolates; %.0f %% draws each position %.1f times"
			% [share, 100.0 / maxf(share, 0.001)]
		)
	)
	return out
