extends RefCounted
## **HOW A FIGURE MOVES, MEASURED THE WAY AN OBSERVER SEES IT.** US-0102. DEBUG TOOL.
##
## The civilian bot claims behavioural parity with the crowd; this is what checks the
## claim instead of taking it. It is fed drawn positions — what a hunter's client puts
## on screen, NPC and player alike — and summarises each group of tracks with the
## four numbers a watching player actually reads a walk by:
##
## - **speed while moving**, because a figure faster than its crowd is the first tell;
## - **the share of time spent standing**, because a figure that never stops is the
##   second;
## - **how long a stop lasts**, because a crowd that idles 8–25 s and a bot that
##   pauses for one is the third;
## - **how sharply it turns while walking**, because a walk made of straight legs and
##   snap turns is the one the owner reported.
##
## **A COMPARISON, NOT A VERDICT.** It prints the groups side by side and says nothing
## about what is close enough — that is the owner's eye at a windowed client, which is
## the Turing-test half of this story and cannot be replaced by a threshold.
##
## PURE: positions and times in, numbers out, so it is tested on synthetic tracks.

## Below this, a figure is standing. Well under the 1.4 m/s stroll and above the
## jitter of an interpolated position.
const STANDING := 0.25
## Samples closer together than this are skipped: a speed over a few milliseconds is
## mostly interpolation noise.
const MIN_DT := 0.1
## A longer gap is a figure that left the view and came back — an NPC crosses the
## cull radius whenever the observer walks — and the displacement across it is not
## a walk anybody saw. Such intervals are skipped rather than read as a sprint.
const MAX_GAP := 1.0

## key -> Array of `[t, position]`.
var _tracks: Dictionary = {}


func add(key: Variant, t: float, at: Vector3) -> void:
	var track: Array = _tracks.get(key, [])
	if not track.is_empty() and t - float(track[-1][0]) < MIN_DT:
		return
	track.append([t, at])
	_tracks[key] = track


func track_count() -> int:
	return _tracks.size()


## Every key that starts with `prefix`, so a caller can group `npc:*` against `player:*`.
func keys_with_prefix(prefix: String) -> Array:
	return _tracks.keys().filter(func(k: Variant) -> bool: return str(k).begins_with(prefix))


## `{tracks, moving_speed, standing_share, mean_stop, turn_rate}` over the given keys.
## `moving_speed` is a median in m/s, `turn_rate` a median in rad/s while walking,
## `mean_stop` seconds. A group with no usable samples answers `tracks: 0`.
func summary(keys: Array) -> Dictionary:
	var speeds: Array[float] = []
	var turns: Array[float] = []
	var stops: Array[float] = []
	var standing := 0.0
	var total := 0.0
	var used := 0
	for key: Variant in keys:
		var track: Array = _tracks.get(key, [])
		if track.size() < 3:
			continue
		used += 1
		var result := _walk_the_track(track)
		speeds.append_array(result[0])
		turns.append_array(result[1])
		stops.append_array(result[2])
		standing += float(result[3])
		total += float(result[4])
	return {
		"tracks": used,
		"moving_speed": _median(speeds),
		"standing_share": standing / total if total > 0.0 else 0.0,
		"mean_stop": _mean(stops),
		"turn_rate": _median(turns),
	}


## `[speeds, turn_rates, stop_lengths, standing_seconds, total_seconds]` for one track.
func _walk_the_track(track: Array) -> Array:
	var speeds: Array[float] = []
	var turns: Array[float] = []
	var stops: Array[float] = []
	var standing := 0.0
	var total := 0.0
	var stop_run := 0.0
	var heading := INF
	for i: int in range(1, track.size()):
		var dt := float(track[i][0]) - float(track[i - 1][0])
		if dt > MAX_GAP:
			heading = INF
			continue
		var step := CompassMath.distance_to(track[i - 1][1], track[i][1])
		var speed := step / dt
		total += dt
		if speed < STANDING:
			standing += dt
			stop_run += dt
			heading = INF
			continue
		if stop_run > 0.0:
			stops.append(stop_run)
			stop_run = 0.0
		speeds.append(speed)
		var now := CompassMath.bearing_to(track[i - 1][1], track[i][1])
		if heading != INF:
			turns.append(absf(CompassMath.angle_between(heading, now)) / dt)
		heading = now
	if stop_run > 0.0:
		stops.append(stop_run)
	return [speeds, turns, stops, standing, total]


## A group summary as one fixed-width line, for the bot's log.
static func line(label: String, s: Dictionary) -> String:
	return (
		"%-10s %3d tracks  moving %.2f m/s  standing %3.0f %%  stop %5.1f s  turning %.2f rad/s"
		% [
			label,
			s["tracks"],
			s["moving_speed"],
			100.0 * float(s["standing_share"]),
			s["mean_stop"],
			s["turn_rate"]
		]
	)


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for v: float in values:
		sum += v
	return sum / values.size()
