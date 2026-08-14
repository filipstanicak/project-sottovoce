## **500 MS OF THE WORLD, RECORDED EVERY TICK.** TDD-04 §8.3, ADR-0010, US-0035.
## SERVER ONLY.
##
## PURE — transforms in, transforms out. It holds no pawns, reads no autoload but
## `Tuning`, and decides nothing: **recording only**, because kill and stun do not
## exist until M4. Building it now means the ring is proven before anything
## depends on it, and the M4 work is validation logic rather than infrastructure.
##
## **RECORDED AT THE END OF THE TICK, ON THE SAME TIMELINE THE CLIENT SEES.** It
## is fed from `MatchDirector.tick_completed`, which is the same signal the
## snapshot builder uses. That is the story's one genuine correctness property:
## a rewind resolves against a tick a client observed in a snapshot, so if the
## two were stamped differently every rewind would carry a silent extra tick past
## the ceiling `TUN-NET-LAGCOMP-MAX` exists to impose — and **nothing would fail
## until M4**, in code nobody would then suspect.
##
## **THE RING IS SIZED FROM TUNING, NEVER WRITTEN AS 15.** Invariant 16 keeps
## `lagcomp_max <= lagcomp_history / 2`, so the buffer is never the binding
## constraint; a hardcoded length would let somebody widen the rewind ceiling and
## discover at M4 that the history had quietly stopped reaching far enough.
class_name LagCompHistory
extends RefCounted


## One recorded tick. Parallel packed arrays rather than an array of objects:
## 96 entities × 15 frames is 1 440 records, and 1 440 `RefCounted`s per match
## would cost more in Godot object headers than the transforms themselves.
class Frame:
	extends RefCounted
	var tick: int = -1
	var ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var yaws := PackedFloat32Array()

	func bytes() -> int:
		return ids.size() * 4 + positions.size() * 12 + yaws.size() * 4


var _frames: Array[Frame] = []
var _next: int = 0
var _capacity: int = 0


func _init() -> void:
	_capacity = capacity_from_tuning()
	_frames.resize(_capacity)


## Frames the ring holds: `TUN-NET-LAGCOMP-HISTORY` at the server tick rate.
## 500 ms at 30 Hz is 15, and the arithmetic is here rather than the number.
static func capacity_from_tuning() -> int:
	var ms: float = Tuning.net.lagcomp_history
	return maxi(int(round(ms / 1000.0 * Tuning.net.server_tick)), 1)


func capacity() -> int:
	return _capacity


## How many ticks are actually recorded. Below `capacity()` until the ring fills.
func size() -> int:
	var n := 0
	for frame: Frame in _frames:
		if frame != null:
			n += 1
	return n


## Record one tick. **Overwrites the oldest** — a ring that grew would hold the
## whole match by the end of it, which is 14 400 frames rather than 15.
func record(
	tick: int, ids: PackedInt32Array, positions: PackedVector3Array, yaws: PackedFloat32Array
) -> void:
	var frame := Frame.new()
	frame.tick = tick
	frame.ids = ids.duplicate()
	frame.positions = positions.duplicate()
	frame.yaws = yaws.duplicate()
	_frames[_next] = frame
	_next = (_next + 1) % _capacity


func newest_tick() -> int:
	var newest := -1
	for frame: Frame in _frames:
		if frame != null:
			newest = maxi(newest, frame.tick)
	return newest


func oldest_tick() -> int:
	var oldest := -1
	for frame: Frame in _frames:
		if frame != null and (oldest < 0 or frame.tick < oldest):
			oldest = frame.tick
	return oldest


## **THE WORLD AT `tick`, NEAR `around`, AND NOTHING ELSE.** §8.3's optimisation:
## rewinding only entities within `TUN-CINDERFALL-RADIUS + TUN-KILL-RANGE` of the
## action is typically fewer than 10 entities rather than 96, and the cost of a
## validation is what decides whether lag compensation is affordable per kill.
##
## **A tick outside the ring is CLAMPED, not refused.** The ring holds 2.5× the
## maximum rewind, so a request past its edge means the clamp in §8.1 did not
## hold — and the safe answer is the oldest world actually recorded, which is
## *less* far into the past. Failing instead would make a high-ping player's kill
## error out rather than resolve conservatively.
func rewind(tick: int, around: Vector3, radius: float) -> RewoundWorld:
	var world := RewoundWorld.new()
	var frame := _frame_at(tick)
	if frame == null:
		return world
	world.tick = frame.tick
	var r2 := radius * radius
	for i: int in frame.ids.size():
		if frame.positions[i].distance_squared_to(around) <= r2:
			world.add(frame.ids[i], frame.positions[i], frame.yaws[i])
	return world


## The recorded frame for `tick`, or the nearest one still held.
func _frame_at(tick: int) -> Frame:
	var exact: Frame = null
	var nearest: Frame = null
	var best := -1
	for frame: Frame in _frames:
		if frame == null:
			continue
		if frame.tick == tick:
			exact = frame
			break
		var distance: int = absi(frame.tick - tick)
		if best < 0 or distance < best:
			best = distance
			nearest = frame
	return exact if exact != null else nearest


## Bytes of transform data actually held. **Measured, not budgeted** — §7.1's
## bandwidth table was written from sizes nobody had measured and reported 87 %
## of a budget it was actually at 113 % of. `test_lagcomp_history.gd` reads this
## against §8.3's ~23 KB rather than trusting the arithmetic.
func bytes() -> int:
	var total := 0
	for frame: Frame in _frames:
		if frame != null:
			total += frame.bytes()
	return total


func clear() -> void:
	_frames.clear()
	_frames.resize(_capacity)
	_next = 0
