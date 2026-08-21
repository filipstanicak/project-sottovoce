## **WHICH NPCs ARE GOING NOWHERE, AND IS THE SERVER THE ONE DOING IT?** US-0041.
##
##     godot --headless --path . res://tools/stuck_census.tscn -- --seed 4242
##
## Two faults produce "trembling and stuck" and they are fixed in different places:
## if the **server** position fidgets, steering or RVO is doing it; if the server is
## still, the tremble is drawn and belongs to the wire or the interpolator.
##
## **JUDGED IN ONE-SECOND WINDOWS.** Asking whether a body went nowhere across the
## whole watch reports **zero** for one that fidgets and then walks off, which is
## the case being looked for.
##
## **IT CANNOT DECIDE A SMALL A/B**, and says so: the navigation layer is not
## reproducible run to run — the same seed and code gave 10 then 7 trembling
## body-seconds of 4680. That scale needs a deterministic test. US-0041.
extends Node

const SERVER_ROOT := "res://scenes/server_root.tscn"
const MAP := "res://data/maps/map_vetraio.tres"
const SAMPLE_EVERY := 900
const SAMPLES := 4

## One second at the physics rate: the window a tremble is judged inside.
const WINDOW := 60

## Ground covered inside one window against the displacement it achieved. Moving
## this far to get nowhere is not walking, it is fidgeting.
const TREMBLE_PATH := 0.10
const TREMBLE_NET := 0.02

## A walk that ends this far from an anchor never got there.
const SHORT := 0.5

var _root: Node
var _pool: NpcPool
var _map_data: MapData
var _tremble: Dictionary = {}
var _at: Dictionary = {}


func _ready() -> void:
	_map_data = load(MAP) as MapData
	_root = (load(SERVER_ROOT) as PackedScene).instantiate()
	get_tree().get_root().add_child.call_deferred(_root)
	_run()


func _run() -> void:
	await get_tree().physics_frame
	_pool = _root.get_node("World/Crowd") as NpcPool
	for _i: int in 300:
		await get_tree().physics_frame
		if _pool.active_count() > 0:
			break
	print("crowd active: %d" % _pool.active_count())
	print("frame   inside a stall   of active")
	for s: int in SAMPLES:
		await _watch(SAMPLE_EVERY)
		var inside := _inside_stalls().size()
		print("%5d   %13d   %9d" % [(s + 1) * SAMPLE_EVERY, inside, _pool.active_count()])
	_report_trembling()
	_report_unreachable_anchors()
	_report_islands()
	_report_the_gap()
	_report_circuits()
	_report_floaters()
	_report_inside_masonry()
	Net.bind_router(null, null)
	get_tree().quit(0)


## Walk the crowd for `frames`, scoring each one-second window per body.
func _watch(frames: int) -> void:
	var last: Dictionary = {}
	var mark: Dictionary = {}
	var walked: Dictionary = {}
	for f: int in frames:
		await get_tree().physics_frame
		for index: int in _pool.active_count():
			var body := _pool.body_of(index)
			if body == null:
				continue
			var now := body.global_position
			if not last.has(index):
				last[index] = now
				mark[index] = now
			walked[index] = (
				float(walked.get(index, 0.0)) + (last[index] as Vector3).distance_to(now)
			)
			last[index] = now
			_at[index] = now
		if (f + 1) % WINDOW == 0:
			_score(mark, last, walked)


func _score(mark: Dictionary, last: Dictionary, walked: Dictionary) -> void:
	for index: int in mark:
		var moved := float(walked.get(index, 0.0))
		var got: float = (mark[index] as Vector3).distance_to(last[index] as Vector3)
		if moved > TREMBLE_PATH and got < TREMBLE_NET:
			_tremble[index] = int(_tremble.get(index, 0)) + 1
		walked[index] = 0.0
		mark[index] = last[index]


## **THE SERVER'S OWN ANSWER, WHICH IS THE HALF A CLIENT CANNOT SEE.**
func _report_trembling() -> void:
	var busy: Array = []
	var seconds := 0
	for index: int in _tremble:
		seconds += int(_tremble[index])
		busy.append([index, int(_tremble[index]), _at[index]])
	busy.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var watched := (SAMPLE_EVERY * SAMPLES / WINDOW) * _pool.active_count()
	print(
		(
			"--- trembling: %d NPCs, %d body-seconds of %d watched ---"
			% [busy.size(), seconds, watched]
		)
	)
	var members := 0
	for entry: Array in busy:
		if _procession_of(int(entry[0])) != "":
			members += 1
	print("  of those, %d are walking a procession circuit" % members)
	for entry: Array in busy.slice(0, 10):
		var at := entry[2] as Vector3
		print(
			(
				"  index %d trembled for %d s, at (%.1f, %.1f)%s%s"
				% [entry[0], entry[1], at.x, at.z, _stall_note(at), _procession_of(int(entry[0]))]
			)
		)


## **PROXIMITY IS THE WRONG TEST.** `map_get_closest_point` knows nothing about
## connectivity, so an anchor inside a stall answers with the stall's own **top** —
## on the navmesh and unreachable. This walks instead of measuring.
func _report_unreachable_anchors() -> void:
	var from := _walkable_point(Vector3(60.0, 0.0, 45.0))
	var off: Array = []
	for at: Vector3 in _map_data.idle_anchors:
		var short := _how_short(from, at)
		if short > SHORT:
			off.append([at, short])
	var total := _map_data.idle_anchors.size()
	print("--- idle anchors NOT REACHABLE on foot: %d of %d ---" % [off.size(), total])
	off.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	for entry: Array in off.slice(0, 10):
		var at := entry[0] as Vector3
		print(
			"  (%.1f, %.1f)%s — a walk ends %.1f m short" % [at.x, at.z, _stall_note(at), entry[1]]
		)


## **COVERAGE IS NOT CONNECTIVITY, AND ONLY ONE OF THEM WAS EVER CHECKED.**
## `test_navmesh_coverage.gd` samples 2011 street points and asks whether each is
## *on* the mesh. Every point on an isolated island passes that.
func _report_islands() -> void:
	var seeds := _street_centres()
	print("--- can a civilian walk from each street to each other? ---")
	for a: int in seeds.size():
		var row := ""
		for b: int in seeds.size():
			var short := _how_short(seeds[a][1] as Vector3, seeds[b][1] as Vector3)
			row += "1" if short <= 1.0 else "."
		print("  %-18s %s" % [str(seeds[a][0]), row])


## Where the island's edge is, in the floor table rather than in the mesh.
func _report_the_gap() -> void:
	var uncovered := 0
	var sampled := 0
	var z := 30.0
	while z < 36.0:
		var x := 30.0
		while x < 90.0:
			sampled += 1
			if not _on_a_floor(Vector2(x, z)):
				uncovered += 1
			x += 2.0
		z += 2.0
	print("--- the strip between the piazza and the Loggia (x 30-90, z 30-36) ---")
	print("  %d of %d sampled points have NO FLOOR UNDER THEM" % [uncovered, sampled])


func _street_centres() -> Array:
	var out: Array = []
	for row: Array in VetraioLayout.FLOORS:
		if not is_equal_approx(float(row[5]), VetraioLayout.STREET_Y):
			continue
		var mid := Vector3(
			float(row[1]) + float(row[3]) * 0.5, 0.0, float(row[2]) + float(row[4]) * 0.5
		)
		out.append([str(row[0]), mid])
	return out


## How far short of `to` a walk from `from` ends. `INF` if there is no path at all.
func _how_short(from: Vector3, to: Vector3) -> float:
	var map := get_tree().get_root().get_world_3d().get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, _walkable_point(from), to, true)
	if path.is_empty():
		return INF
	return Vector2(path[-1].x - to.x, path[-1].z - to.z).length()


func _walkable_point(near: Vector3) -> Vector3:
	var map := get_tree().get_root().get_world_3d().get_navigation_map()
	return NavigationServer3D.map_get_closest_point(map, near)


func _on_a_floor(at: Vector2) -> bool:
	for row: Array in VetraioLayout.FLOORS:
		if not is_equal_approx(float(row[5]), VetraioLayout.STREET_Y):
			continue
		if Rect2(float(row[1]), float(row[2]), float(row[3]), float(row[4])).has_point(at):
			return true
	return false


func _inside_stalls() -> Array:
	var out: Array = []
	for index: int in _pool.active_count():
		var body := _pool.body_of(index)
		if body != null and _stall_at(body.global_position) != "":
			out.append(index)
	return out


func _stall_note(at: Vector3) -> String:
	var hit := _stall_at(at)
	return "" if hit == "" else "  INSIDE " + hit


func _stall_at(at: Vector3) -> String:
	for stall: Array in VetraioLayout.STALLS:
		var r := Rect2(float(stall[1]), float(stall[2]), float(stall[3]), float(stall[4]))
		if r.has_point(Vector2(at.x, at.z)):
			return str(stall[0])
	return ""


## **CAN THE FOUR PROCESSIONS ACTUALLY WALK THEIR ROUTES?** GDD-05 SS2.5.
##
## `CrowdCircuit` interpolates between waypoints and `CrowdFormations` drives NPCs
## at them, so a waypoint that is inside a building or on the far side of a cut is
## a slot no NPC can occupy. Nothing has ever checked either: `test_circuit_
## separation.gd` measures how close two routes pass, which is a different question.
func _report_circuits() -> void:
	print("--- can each procession walk its own route? ---")
	for circuit: Array in VetraioLayout.CIRCUITS:
		var name := str(circuit[0])
		var points: Array = circuit[2]
		var in_block: Array = []
		var off_floor: Array = []
		var unreachable := 0
		for point: Vector2 in points:
			var at := Vector3(point.x, VetraioLayout.STREET_Y, point.y)
			var block := _block_at(point)
			if block != "":
				in_block.append("(%.0f, %.0f) in %s" % [point.x, point.y, block])
			elif not _on_a_floor(point):
				off_floor.append("(%.0f, %.0f)" % [point.x, point.y])
			if _how_short(Vector3(60.0, 0.0, 45.0), at) > 1.0:
				unreachable += 1
		print(
			(
				"  %-8s %d waypoints: %d inside a block, %d off any floor, %d unreachable"
				% [name, points.size(), in_block.size(), off_floor.size(), unreachable]
			)
		)
		for note: String in in_block:
			print("      BLOCKED  " + note)
		for note: String in off_floor:
			print("      NO FLOOR " + note)
		_report_route_solidity(points)


## **THE WAYPOINTS ARE NOT THE ROUTE.** `CrowdCircuit` interpolates between them and
## `CrowdFormations` drives members at a slot on that line, so a segment that clips
## a corner puts a slot inside masonry even when both of its endpoints are clear.
## Sampled every half metre, which is a third of `TUN-CROWD-GROUP-SPACING`.
func _report_route_solidity(points: Array) -> void:
	var solid := 0
	var nowhere := 0
	var sampled := 0
	for i: int in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var steps := int(maxf(1.0, a.distance_to(b) / 0.5))
		for k: int in steps:
			var at := a.lerp(b, float(k) / float(steps))
			sampled += 1
			if _block_at(at) != "":
				solid += 1
			elif not _on_a_floor(at):
				nowhere += 1
	var bad := float(solid + nowhere) / float(maxi(sampled, 1)) * 100.0
	print(
		(
			"      route: %d of %d sampled points unwalkable (%.1f %%) - %d in masonry, %d over nothing"
			% [solid + nowhere, sampled, bad, solid, nowhere]
		)
	)


func _block_at(at: Vector2) -> String:
	for block: Array in VetraioLayout.BLOCKS:
		var r := Rect2(float(block[1]), float(block[2]), float(block[3]), float(block[4]))
		if r.has_point(at):
			return str(block[0])
	return ""


## **IS THIS NPC WALKING A PROCESSION?** The distinction decides where a fix goes.
##
## A formation member is driven by `Steering.drive_to` — straight at its slot, with
## **no path query at all**, deliberately, because a slot moves every tick and
## pathing to one would starve `RepathQueue`. That is safe only while the route is
## walkable. Five of the four circuits' waypoints are **inside solid blocks**, so a
## member driven at a slot there presses into a wall and stays.
func _procession_of(index: int) -> String:
	var director := _root.get_node_or_null("Systems/CrowdDirector")
	if director == null:
		return ""
	var formations := director.get("_formations") as CrowdFormations
	if formations == null:
		return ""
	for g: int in formations.groups.size():
		if index in formations.groups[g].occupants:
			return "  PROCESSION group %d" % g
	return ""


## **IS ANYBODY STANDING ON NOTHING?** Reported as NPCs "floating above the hole".
## Asks how high they are and whether they walk a procession, since `drive_to` aims
## a member straight at its slot with no path query and is the one thing that can
## put a body over ground the navmesh does not cover. US-0041.
func _report_floaters() -> void:
	var over_nothing: Array = []
	for index: int in _pool.active_count():
		var body := _pool.body_of(index)
		if body == null:
			continue
		var at := body.global_position
		if _on_a_floor(Vector2(at.x, at.z)):
			continue
		over_nothing.append([index, at, body.velocity.y, body.is_on_floor()])
	print(
		(
			"--- NPCs standing over no floor: %d of %d ---"
			% [over_nothing.size(), _pool.active_count()]
		)
	)
	for entry: Array in over_nothing.slice(0, 12):
		var at := entry[1] as Vector3
		print(
			(
				"  index %d at (%.1f, %.2f, %.1f)  vy %.3f  grounded %s%s"
				% [entry[0], at.x, at.y, at.z, entry[2], entry[3], _procession_of(int(entry[0]))]
			)
		)


## **IS ANY NPC STANDING INSIDE A BUILDING?** Reported as NPCs moving "through
## objects like a vaultable wall". The stall census above only asks about `STALLS`;
## `BLOCKS` are the solid masses and five circuit waypoints sit inside them. A
## client-drawn NPC has no collider at all, so if the server says a body is inside a
## wall, the client draws it there. US-0041.
func _report_inside_masonry() -> void:
	var inside: Array = []
	for index: int in _pool.active_count():
		var body := _pool.body_of(index)
		if body == null:
			continue
		var at := body.global_position
		var block := _block_at(Vector2(at.x, at.z))
		if block != "":
			inside.append([index, at, block])
	print(
		(
			"--- NPCs standing INSIDE a building mass: %d of %d ---"
			% [inside.size(), _pool.active_count()]
		)
	)
	for entry: Array in inside.slice(0, 12):
		var at := entry[1] as Vector3
		print(
			(
				"  index %d at (%.1f, %.2f, %.1f) inside %s%s"
				% [entry[0], at.x, at.y, at.z, entry[2], _procession_of(int(entry[0]))]
			)
		)
