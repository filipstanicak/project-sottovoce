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

## How many bodies to watch.
##
## **TWELVE WAS TOO FEW, AND THE WAY IT FAILED IS WORTH KNOWING.** The bodies are
## taken in child order, which is spawn order, not a spread across the district —
## so four consecutive runs sampled 0, 1 and 3 *walking* NPCs beyond
## `TUN-NET-NPC-RATE-LOD-RADIUS`, and two of them reported no far band at all. A
## per-band rate computed from one NPC is not a measurement, and an A/B against it
## cannot decide anything.
const WATCHED := 48

var _frames: PackedFloat32Array = PackedFloat32Array()
var _last_usec: int = 0
var _drawn: Dictionary = {}
var _render_frames: int = 0
var _moved_frames: int = 0
var _steps: Dictionary = {}
var _far: Dictionary = {}


## Call once per rendered frame, with the nodes whose motion should be judged.
func sample(bodies: Array, observer: Vector3 = Vector3.INF) -> void:
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
		if was != null:
			_note_step(body.name, (was as Vector3).distance_to(at), at, observer)
		_drawn[body.name] = at
	_render_frames += 1
	if moved:
		_moved_frames += 1


## **A HOLD FOLLOWED BY A CATCH-UP IS WHAT RUBBERBANDING IS.** A body drawn from
## `SnapshotInterpolator` stops moving whenever the render clock passes its newest
## sample — the interpolator refuses to extrapolate, by design — and then jumps
## when the next record lands. Counted per body against that body's own median
## step, and split by distance, because `TUN-NET-NPC-RATE-LOD-RADIUS` is where the
## send rate drops to `TUN-NET-NPC-RATE-LOD-HZ` and the buffer margin vanishes.
func _note_step(name: String, step: float, at: Vector3, observer: Vector3) -> void:
	if not _steps.has(name):
		_steps[name] = []
	(_steps[name] as Array).append(step)
	if observer != Vector3.INF:
		_far[name] = Vector2(at.x - observer.x, at.z - observer.z).length() > _lod_radius()


static func _lod_radius() -> float:
	return Tuning.net.npc_rate_lod_radius


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
	out.append_array(_stall_lines())
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


## **HOLD-THEN-CATCH-UP, WHICH IS WHAT RUBBERBANDING ACTUALLY IS.**
##
## The first version of this counted every frame whose step was near zero, and
## **an NPC standing at an idle anchor is near zero on every frame** — the crowd's
## commonest state by design, 8-25 s at a time. It reported 36-43 % for the far
## band and could not tell a stalled interpolator from a person standing still.
##
## A hold only matters if the body then *catches up*: a frame that barely moves
## followed by one that moves far more than usual. Idle NPCs never produce the
## second half. Only bodies that are genuinely walking are counted at all.
func _stall_lines() -> Array[String]:
	var out: Array[String] = []
	for band: bool in [false, true]:
		var walking := 0
		var events := 0
		var frames := 0
		for name: String in _steps:
			if bool(_far.get(name, false)) != band:
				continue
			var steps: Array = _steps[name]
			var median := _median(steps)
			# A body whose median frame step is under a third of a stroll step is
			# standing, not walking, and has nothing to stall.
			if median < _stroll_step() / 3.0:
				continue
			walking += 1
			frames += steps.size()
			events += _catch_ups(steps, median)
		if walking == 0:
			continue
		out.append(
			(
				"  %s: %d walking NPCs, %d hold-then-catch-up events in %d frames (%.2f %%)"
				% [
					"beyond the rate-LOD radius" if band else "inside the rate-LOD radius",
					walking,
					events,
					frames,
					float(events) / float(maxi(frames, 1)) * 100.0
				]
			)
		)
	return out


## A frame that barely moved, immediately followed by one that moved far more than
## this body's own median.
static func _catch_ups(steps: Array, median: float) -> int:
	var found := 0
	for i: int in range(steps.size() - 1):
		if float(steps[i]) < median * 0.25 and float(steps[i + 1]) > median * 1.8:
			found += 1
	return found


## What one rendered frame of walking looks like, from the tunables rather than
## from the sample: a stroll divided by the measured frame rate.
func _stroll_step() -> float:
	if _frames.is_empty():
		return 0.0
	var total := 0.0
	for value: float in _frames:
		total += float(value)
	var mean_ms := total / float(_frames.size())
	return Tuning.crowd.npc_speed_stroll * mean_ms / 1000.0


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2]) if sorted.size() > 0 else 0.0
