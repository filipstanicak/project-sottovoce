## **THE DISTRICT WITH THE CROWD IN IT — WATCHED, NOT GLANCED AT.** US-0030,
## US-0031, US-0045.
##
## The corpus's own rule: **nine defects here were found by looking at the running
## game and none was reachable by any test** — no suite has a window, a display or
## an input device. `NpcView` is exactly what that rule is for: every assertion
## about it passes whether the district renders a crowd, renders nothing, or
## stacks seventy-eight bodies on the origin.
##
## **A SINGLE FRAME IS NOT ENOUGH, AND THE FIRST VERSION OF THIS TOOL TOOK ONE.**
## It showed four NPCs standing still against a wall, which is consistent with a
## working crowd and with a crowd frozen at spawn. What a still frame cannot show
## is **motion** — and motion carries the one number this whole system is built
## around: `TUN-CROWD-NPC-SPEED-STROLL` must equal `TUN-SPEED-BLENDWALK`, or a
## blend-walking player is distinguishable from the crowd **by gait**, which is
## `RISK-ANONYMITY-LEAK` at its purest. That number is asserted on the *server* by
## `test_crowd_moves.gd`. It has never been checked on the wire, and interpolation
## sits between the two.
##
## So it samples what is actually **drawn**, over several seconds, and reports the
## speed of everything that moved.
##
## Run it against a server that is already up:
##
##     godot --headless --path . -- --server --port 27015 --max-players 6 &
##     godot --path . res://tools/crowd_probe.tscn
##
## **IT IS A SCENE, NOT A `-s` SCRIPT, AND THAT IS NOT A STYLE CHOICE.** A
## `SceneTree` script run with `-s` compiles before the autoload globals are
## registered, so every script naming `Net` — `remote_pawns.gd` and `npc_view.gd`
## among them — fails to compile and the client silently loads without them. The
## first version did that and reported an empty district, which is trap 13's
## family: a probe that cannot see reports what a broken game reports.
##
## **`--headless` RENDERS NOTHING** and would write blank files. It refuses.
extends Node

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## Seconds before the first shot: the handshake, a pawn, and enough snapshots that
## the interpolator has two samples to work between.
const SETTLE := 6.0

## How long to watch, and how often to sample. Long enough that an NPC that was
## merely between two anchors when the watch began has time to walk somewhere.
const WATCH := 8.0
const SAMPLE_EVERY := 0.25

var _root: Node
var _view: NpcView
var _tracks: Dictionary = {}
var _counts: PackedInt32Array = PackedInt32Array()
var _appeared := 0
var _dropped := 0
var _flappers: Dictionary = {}
var _where: Dictionary = {}

## Where the observer was when the watch began. Every other number here is read
## differently if it changed.
var _began := Vector3.INF


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: headless renders nothing, and a blank PNG reads like an empty district.")
		get_tree().quit(1)
		return
	_root = (load(CLIENT_ROOT) as PackedScene).instantiate()
	get_tree().get_root().add_child.call_deferred(_root)
	Net.join("127.0.0.1", 27015)
	_probe()


func _probe() -> void:
	await get_tree().create_timer(SETTLE).timeout
	_view = _find(_root) as NpcView
	if _view == null:
		print("REFUSING: no NpcView in the client scene — nothing is drawing a crowd.")
		get_tree().quit(1)
		return
	# **COUNTED FROM THE SIGNALS, NOT INFERRED FROM THE TOTAL.** The first version
	# of this report called any change in the count "churn" and flagged monotonic
	# growth as a defect — NPCs walking INTO range is the ordinary case, and a
	# min/max pair cannot tell that from flapping at the boundary.
	_view.npc_appeared.connect(func(_i: int) -> void: _appeared += 1)
	_view.npc_dropped.connect(_on_dropped)
	_began = _at()
	await _shoot("crowd_ground")
	await _watch()
	await _shoot("crowd_after")
	_report()
	get_tree().quit(0)


## Sample every drawn NPC's position on a timer, so the numbers below describe
## what a **player** sees rather than what the server believes.
func _watch() -> void:
	var elapsed := 0.0
	while elapsed < WATCH:
		await get_tree().create_timer(SAMPLE_EVERY).timeout
		elapsed += SAMPLE_EVERY
		_counts.append(_view.count())
		for child: Node in _view.get_children():
			var at: Vector3 = (child as Node3D).global_position
			if not _tracks.has(child.name):
				_tracks[child.name] = []
			(_tracks[child.name] as Array).append(at)


## **WHICH NPCs FLAP, AND HOW FAR AWAY.** A total tells you something is wrong;
## the identities and the distance tell you what.
func _on_dropped(index: int) -> void:
	_dropped += 1
	var key := str(index)
	_flappers[key] = int(_flappers.get(key, 0)) + 1
	# **THE RECEIVED POSITION, NOT THE DRAWN ONE.** The first version of this read
	# the drawn transform and reported 72.8 m for every flapper — which is exactly
	# the distance from the observer to the world ORIGIN, because a body that
	# appears and drops between two samples is never drawn anywhere. A diagnostic
	# that reports a constant is reporting its own default.
	var at := _view.last_seen(index)
	_where[key] = -1.0 if at == Vector3.INF else _view.observer().distance_to(at)


func _shoot(basename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "user://%s.png" % basename
	get_viewport().get_texture().get_image().save_png(path)
	print("%s -> %s" % [basename, ProjectSettings.globalize_path(path)])


## **THE NUMBERS BESIDE THE PICTURE.** A screenshot cannot tell a crowd from one
## NPC near the camera, a placed crowd from a stacked one, or a walking crowd from
## a frozen one.
func _report() -> void:
	var speeds := _speeds()
	print("--- what a client actually draws ---")
	# **THE COUNT IS MEANINGLESS WITHOUT THE PLACE.** MAP-VETRAIO's six spawn
	# points do not see equal crowds — three of them cannot hold
	# TUN-CROWD-CLONE-LOCAL-MIN and one sees almost nothing (US-0096). A run
	# reporting 23 and a run reporting 66 can both be correct, and only the
	# observer's position says which.
	print("observer at (%.1f, %.1f, %.1f)" % [_at().x, _at().y, _at().z])
	_report_the_observer()
	print("NPCs drawn: %d, spread %.1f m, y from %.2f to %.2f" % _shape())
	print("count %d..%d over the watch: %d appeared, %d dropped %s" % _churn())
	if speeds.is_empty():
		print("MOVERS: none. A frozen crowd is what a still frame cannot rule out.")
		return
	speeds.sort()
	var median: float = speeds[speeds.size() / 2]
	var stroll: float = Tuning.crowd.npc_speed_stroll
	print(
		(
			(
				"movers: %d of %d, median drawn speed %.3f m/s against "
				+ "TUN-CROWD-NPC-SPEED-STROLL %.3f (%.1f %%)"
			)
			% [speeds.size(), _view.count(), median, stroll, median / stroll * 100.0]
		)
	)
	print("slowest mover %.3f, fastest %.3f m/s" % [speeds[0], speeds[speeds.size() - 1]])
	_report_flappers()


func _report_flappers() -> void:
	var worst: Array = []
	for key: String in _flappers:
		worst.append([int(_flappers[key]), key, float(_where.get(key, 0.0))])
	if worst.is_empty():
		return
	worst.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	print("%d distinct NPCs were dropped; the worst offenders:" % worst.size())
	for i: int in mini(6, worst.size()):
		var row: Array = worst[i]
		var cull: float = Tuning.net.npc_cull_radius
		var rule := "rule 1 (farewell)" if float(row[2]) <= cull + 1.0 else "rule 2 (safety)"
		print(
			(
				(
					"  Npc_%s dropped %d times, last seen %.3f m away — cull %.2f, "
					+ "farewell line %.3f, safety line %.3f, so %s"
				)
				% [
					row[1],
					row[0],
					row[2],
					cull,
					cull + Tuning.net.quant_pos,
					cull + _view.drop_margin(),
					rule
				]
			)
		)


## Median speed per NPC that moved at all, over the whole watch. Median rather
## than mean because an NPC that stops at an anchor half way through would drag a
## mean down and make a correct crowd look slow.
func _speeds() -> Array:
	var out: Array = []
	for key: String in _tracks:
		var track: Array = _tracks[key]
		var steps: Array = []
		for i: int in range(1, track.size()):
			var step: float = (track[i] as Vector3).distance_to(track[i - 1] as Vector3)
			if step > 0.001:
				steps.append(step / SAMPLE_EVERY)
		if steps.size() < 4:
			continue
		steps.sort()
		out.append(float(steps[steps.size() / 2]))
	return out


## Where the local player is standing, from the view's own record of it.
func _at() -> Vector3:
	return _view.observer()


## **DID THE PLAYER MOVE?** Every other line in this report means something
## different if it did. "Nothing was dropped" is the strongest evidence a cull
## boundary is quiet only when the observer stood still; with a player walking,
## NPCs leaving reach is the ordinary case and a drop count says almost nothing.
##
## **AND IT IS NOT A HYPOTHETICAL.** This tool has twice reported an observer tens
## of metres from its spawn point with nobody at the controls, while
## `tools/input_live.tscn` on the same build measured **0 of 240 sampled commands
## carrying movement** and a pawn that travelled 0.00 m. Both cannot be right, and
## the probe that says the player moved is the one that was not built to watch
## input. Recorded rather than explained away.
func _report_the_observer() -> void:
	if _began == Vector3.INF:
		return
	var travelled := Vector2(_at().x - _began.x, _at().z - _began.z).length()
	if travelled < 0.5:
		print(
			(
				"the observer stood still (%.2f m), so the churn line below is about the crowd"
				% travelled
			)
		)
		return
	print(
		(
			(
				"THE OBSERVER MOVED %.2f m, from (%.1f, %.1f) — so drops below are the "
				+ "player leaving NPCs behind as much as NPCs leaving, and this run says "
				+ "little about the cull boundary. Run tools/input_live.tscn."
			)
			% [travelled, _began.x, _began.z]
		)
	)


func _shape() -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for child: Node in _view.get_children():
		var at: Vector3 = (child as Node3D).global_position
		lo = Vector3(minf(lo.x, at.x), minf(lo.y, at.y), minf(lo.z, at.z))
		hi = Vector3(maxf(hi.x, at.x), maxf(hi.y, at.y), maxf(hi.z, at.z))
	if lo.x == INF:
		return [0, 0.0, 0.0, 0.0]
	return [_view.count(), Vector2(hi.x - lo.x, hi.z - lo.z).length(), lo.y, hi.y]


## **POPPING IS WHAT THE CULL BOUNDARY WOULD LOOK LIKE, AND GROWTH IS NOT IT.**
## An NPC walking into range is the ordinary case and should appear; one appearing
## and vanishing repeatedly is the defect. Counted from the signals so the two can
## be told apart — a min/max pair cannot.
func _churn() -> Array:
	if _counts.is_empty():
		return [0, 0, 0, 0, ""]
	var lo := _counts[0]
	var hi := _counts[0]
	for value: int in _counts:
		lo = mini(lo, value)
		hi = maxi(hi, value)
	var verdict := "(no NPC left the client's reach)"
	if _dropped > 0:
		verdict = "(NPCs walked out of reach, which is ordinary)"
	return [lo, hi, _appeared, _dropped, verdict]


func _find(node: Node) -> Node:
	if node is NpcView:
		return node
	for child: Node in node.get_children():
		var found := _find(child)
		if found != null:
			return found
	return null
