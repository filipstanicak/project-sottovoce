## **EVERY REMOTE ENTITY, RENDERED 100 ms IN THE PAST.** TDD-04 §5, US-0034.
##
## PURE. A buffer of stamped samples per entity and the arithmetic that reads
## between two of them — no nodes, no clock of its own, no snapshots. What time
## it is is the caller's business; this answers *where was this thing then*.
##
## **STAMPED, NEVER SPACED.** Each sample carries the server time it describes,
## and the search below brackets a render time between two of them. Assuming a
## fixed 33 ms interval would be simpler and would break the moment the crowd
## LOD kicks in: far NPCs arrive at 10 Hz and near ones at 30, and a fixed
## interval makes the two rates fight — the far ones race and the near ones
## stall (TDD-04 §7.2 mechanism 4).
##
## **NO EXTRAPOLATION, EVER.** Past the newest sample the last transform is held.
## An extrapolated player who was about to stop is a player who appears to walk
## through a wall, and in a game where thirty centimetres decides a kill,
## guessing is worse than lagging. A buffer underrun is visible as a brief stall,
## which is correct and honest.
##
## **THE BUFFER IS FIXED AT `TUN-NET-INTERP-BUFFER`, NOT ADAPTIVE** (ASM-0021).
## Adaptive would change remote timing between sessions and confound every
## balance judgement made against it.
class_name SnapshotInterpolator
extends RefCounted

## Samples kept per entity. At 30 Hz this is ~0.5 s of history — five times the
## interpolation delay, so a burst of late packets still finds a bracket.
const HISTORY := 16

var _tracks: Dictionary = {}


## Record where an entity was at `server_time`, in seconds on the server's
## timeline.
##
## Out-of-order samples are dropped rather than inserted: UDP reorders, and a
## sample older than one already held describes a past the buffer has moved past.
func push(id: int, server_time: float, position: Vector3, yaw: float) -> void:
	if not _tracks.has(id):
		_tracks[id] = []
	var track: Array = _tracks[id]
	if not track.is_empty() and server_time <= float((track[-1] as Array)[0]):
		return
	track.append([server_time, position, yaw])
	while track.size() > HISTORY:
		track.pop_front()


## Where the entity was at `render_time`, or `null` if nothing is known about it.
##
## Returns `[position, yaw]`. Before the oldest sample it holds the oldest —
## which is what a client that has just seen an entity for the first time gets,
## and holding is right there too: it has no evidence of anything earlier.
func sample(id: int, render_time: float) -> Array:
	var track: Array = _tracks.get(id, [])
	if track.is_empty():
		return []
	var newest: Array = track[-1]
	if render_time >= float(newest[0]):
		# **THE UNDERRUN CASE, AND IT IS THE COMMON ONE UNDER LOSS.** Hold, never
		# guess: see the class docstring.
		return [newest[1], newest[2]]
	var oldest: Array = track[0]
	if render_time <= float(oldest[0]):
		return [oldest[1], oldest[2]]
	return _between(track, render_time)


## Lerp between the two samples bracketing `render_time`.
##
## Yaw uses `lerp_angle`: a pawn turning past north goes from 359° to 1°, and a
## straight lerp spins it the long way round — 358 degrees of rotation in one
## frame, on a silhouette a player is trying to read.
func _between(track: Array, render_time: float) -> Array:
	for i: int in range(track.size() - 1, 0, -1):
		var later: Array = track[i]
		var earlier: Array = track[i - 1]
		if render_time < float(earlier[0]):
			continue
		var span := float(later[0]) - float(earlier[0])
		var t := 0.0 if span <= 0.0 else (render_time - float(earlier[0])) / span
		return [
			(earlier[1] as Vector3).lerp(later[1] as Vector3, t),
			lerp_angle(float(earlier[2]), float(later[2]), t),
		]
	var oldest: Array = track[0]
	return [oldest[1], oldest[2]]


## The newest server time held for an entity, or -1.0.
func newest_time(id: int) -> float:
	var track: Array = _tracks.get(id, [])
	return -1.0 if track.is_empty() else float((track[-1] as Array)[0])


func sample_count(id: int) -> int:
	return (_tracks.get(id, []) as Array).size()


func has(id: int) -> bool:
	return _tracks.has(id)


func forget(id: int) -> void:
	_tracks.erase(id)


func clear() -> void:
	_tracks.clear()
