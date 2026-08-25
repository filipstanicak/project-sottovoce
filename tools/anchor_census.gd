## **HOW MANY IDLE ANCHORS EACH ZONE ACTUALLY GETS, AND WHAT EACH SPAWN CAN SEE.**
## GDD-05 §4.4 and §2.7, US-0096.
##
##     godot --headless -s res://tools/anchor_census.gd
##
## US-0096 found three of six spawn points unable to hold
## `TUN-CROWD-CLONE-LOCAL-MIN` at any arrangement, one of them seeing no NPC at
## all. This prints the two tables that say why: what each zone asked for against
## what the grid gave it, and what each spawn point can see.
##
## **IT LOADS THE TUNING PROFILE ITSELF AND MUST.** A `-s` script gets **no
## autoloads**, so `Tuning` does not exist here and any Core class that reads it —
## `CloneParity`, for one — fails to compile, reporting only "nonexistent function"
## at the call site. Trap 13's family: the diagnostic that cannot see reports the
## same thing as a healthy answer.
extends SceneTree

## Every number this tool grades against comes from here, never from a literal.
const PROFILE := "res://data/tuning/default/profile.tres"

## GDD-05 §2.7 rule 4's 25 m. **A level-design constant, not a tunable** — it is
## written in the rule table and nowhere else, which is why it is a literal here
## and in `test_spawn_points.gd` and not read from the profile.
const CIRCUIT_REACH := 25.0

## How many candidate relocations to print per starved spawn.
const SHORTLIST := 5

var _tuning: TuningProfile = null


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var data := load("res://data/maps/map_vetraio.tres") as MapData
	_tuning = load(PROFILE) as TuningProfile
	_report_zones(data)
	_report_spawns(data)
	_search_for_spawn_sites(data)
	quit()


## What each zone asked GDD-05 §4.4 for, against what the grid gave it.
func _report_zones(data: MapData) -> void:
	print("--- zones: wanted vs placed ---")
	for zone: MapZone in data.zones:
		# **A THEATRE ASKS AND IS DELIBERATELY REFUSED.** `expected_anchors()` is a
		# function of area and density class and knows nothing about theatres, so
		# `PiazzaSecca` reads "wanted 24, placed 0" — which is the exact shape of the
		# `Fondaco` defect US-0096 found, and is not one. The empty plaza staying
		# empty is its whole function (GDD-05 §5.3). Said here so the next reader
		# does not spend an afternoon chasing it.
		var wanted := 0 if zone.is_theatre else zone.expected_anchors()
		var placed := 0
		for anchor: Vector3 in data.idle_anchors:
			if zone.bounds.has_point(Vector3(anchor.x, zone.bounds.position.y, anchor.z)):
				placed += 1
		var spacing := 0.0
		if wanted > 0:
			spacing = sqrt((zone.bounds.size.x * zone.bounds.size.z) / float(wanted))
		var thin := wanted > 0 and spacing > minf(zone.bounds.size.x, zone.bounds.size.z)
		print(
			(
				"  %-18s %5.0f x %-5.0f m  wanted %3d  placed %3d  spacing %5.2f m%s"
				% [
					zone.zone_name,
					zone.bounds.size.x,
					zone.bounds.size.z,
					wanted,
					placed,
					spacing,
					(
						"   <-- theatre: no anchors on purpose"
						if zone.is_theatre
						else ("   <-- thinner than its own cell" if thin else "")
					)
				]
			)
		)
	print("  %d anchors in the resource" % data.idle_anchors.size())


## What each spawn point can see, which is what US-0096 measures the crowd by.
func _report_spawns(data: MapData) -> void:
	print("--- spawn points: anchors within the local radius ---")
	var radius := _radius()
	for at: Vector3 in data.spawn_points:
		var near := 0
		var nearest := INF
		for anchor: Vector3 in data.idle_anchors:
			var gap := Vector2(anchor.x - at.x, anchor.z - at.z).length()
			nearest = minf(nearest, gap)
			if gap <= radius:
				near += 1
		print(
			(
				"  (%6.1f, %6.1f)  %3d anchors within %.0f m, nearest %.1f m"
				% [at.x, at.z, near, radius, nearest]
			)
		)


## **IS THERE ANYWHERE LEGAL TO PUT A STARVED SPAWN POINT?** GDD-05 §2.7 rule 1 is
## 30 m spawn-to-spawn and rule 5 is street level outside Piazza Secca; US-0096
## adds that a spawn needs 4 x `TUN-CROWD-CLONE-LOCAL-MIN` clone seats within
## `TUN-CROWD-CLONE-LOCAL-RADIUS`. Searching the floor rectangles on a 2 m grid
## turns "moving it will not help" from an opinion into a count.
func _search_for_spawn_sites(data: MapData) -> void:
	print("--- relocations legal on GDD-05 §2.7 rules 1, 4, 5, 6 and 8, 2 m grid ---")
	for slot: int in data.spawn_points.size():
		var here: Vector3 = data.spawn_points[slot]
		var others: Array[Vector3] = []
		for other: int in data.spawn_points.size():
			if other != slot:
				others.append(data.spawn_points[other])
		var result := _sites_for(here, others, data)
		print(
			(
				"  spawn (%6.1f, %6.1f): %2d seats now | %d sites legal on rules 1, 4, 5, 6 and 8"
				% [here.x, here.z, _seats_at(here, data), result[0]]
			)
		)
		_print_candidates(result[1], data)


## **THE NEAREST LEGAL SITE IS NOT NECESSARILY THE RIGHT ONE**, and a tool that
## prints one answer invites it being taken. §2.7 names where each spawn *is* —
## "Mercato Piccolo, north" — so a relocation that satisfies every rule while moving
## a spawn out of the district it is named for has changed the level rather than
## repaired it. The shortlist carries its zone for exactly that judgement.
func _print_candidates(shortlist: Array, data: MapData) -> void:
	for candidate: Array in shortlist:
		var at: Vector3 = candidate[0]
		print(
			(
				"      %6.1f m -> (%6.1f, %6.1f)  %2d seats  %s"
				% [candidate[1], at.x, at.z, _seats_at(at, data), _where(at, data)]
			)
		)


## `[how many legal sites exist, the nearest one to `here`]`.
##
## **THE NEAREST LEGAL SITE, NOT THE BEST ONE.** GDD-05 §2.7 names where each spawn
## is and its anti-spawn-camp analysis assumes they are spread; dragging them all
## to the anchor-rich centre would satisfy the seat count and quietly put three of
## them inside one camper's 40 m.
##
## **AND "LEGAL" MEANS EVERY RULE, WHICH THIS ASKED FOR EXACTLY ONE OF UNTIL
## 2026-08-21.** It graded candidates on seats and spawn separation and offered
## (90, 66) as `S5`'s nearest site — which is **on Piazza Secca's own boundary**,
## the empty theatre plaza §2.7 rule 5 exists to keep spawns out of. The filter it
## had excluded a *floor* named `PiazzaSecca`; the plaza is a **zone** spanning
## several floors, so the check passed over the thing it was written to catch.
## **An instrument that grades against one of four rules answers confidently and
## wrongly**, and this one was about to move a spawn point.
func _sites_for(here: Vector3, others: Array[Vector3], data: MapData) -> Array:
	var found := 0
	var shortlist: Array = []
	for floor_row: Array in VetraioLayout.FLOORS:
		if floor_row[5] != VetraioLayout.STREET_Y:
			continue
		var x: float = floor_row[1]
		while x < float(floor_row[1]) + float(floor_row[3]):
			var z: float = floor_row[2]
			while z < float(floor_row[2]) + float(floor_row[4]):
				var at := Vector3(x, 0.0, z)
				if _legal(at, others, data):
					found += 1
					shortlist.append([at, Vector2(at.x - here.x, at.z - here.z).length()])
				z += 2.0
			x += 2.0
	shortlist.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	return [found, shortlist.slice(0, SHORTLIST)]


## Every GDD-05 §2.7 rule a *position* can be judged against. Rules 2, 3 and 7 are
## the respawn system's and depend on a live match.
##
## **RULE 6 IS HERE AS OF 2026-08-21 AND IT IS THE ONE THAT WOULD HAVE BITTEN.** It
## reads as a property of the whole arrangement rather than of one point, which is
## why it was left to `test_spawn_points.gd` — but the interior massing closed it at
## 0 of 15, and **a relocation is exactly what re-opens it**. A tool that grades a
## candidate against the rules while omitting the one the last pass fixed is how a
## level pass undoes the pass before it.
func _legal(at: Vector3, others: Array[Vector3], data: MapData) -> bool:
	if _in_a_theatre(at, data):  # rule 5
		return false
	if not _far_enough(at, others):  # rule 1
		return false
	if _nearest_circuit(at, data) > CIRCUIT_REACH:  # rule 4
		return false
	if not _occluded_from_all(at, others):  # rule 6
		return false
	return _seats_at(at, data) >= _seats_required()  # rule 8


## Rule 6: no other spawn may be in clear sight. The same sampled line of sight
## `test_spawn_points.gd` measures, against blocks tall enough to stand behind.
func _occluded_from_all(at: Vector3, others: Array[Vector3]) -> bool:
	for other: Vector3 in others:
		if not _blocked(Vector2(at.x, at.z), Vector2(other.x, other.z)):
			return false
	return true


func _blocked(a: Vector2, b: Vector2) -> bool:
	var eye: float = _tuning.camera.arm_height
	for row: Array in VetraioLayout.BLOCKS:
		if float(row[5]) < eye:
			continue
		if _crosses(Rect2(float(row[1]), float(row[2]), float(row[3]), float(row[4])), a, b):
			return true
	return false


## Sampled at a quarter of a metre, far finer than `MIN_ALLEY_WIDTH`, so no block
## this can miss is one a player could see past.
static func _crosses(box: Rect2, a: Vector2, b: Vector2) -> bool:
	if box.has_point(a) or box.has_point(b):
		return true
	var steps := int(a.distance_to(b) / 0.25) + 1
	for step: int in range(1, steps):
		if box.has_point(a.lerp(b, float(step) / float(steps))):
			return true
	return false


## Which named zone and floor a point sits in, so a candidate can be judged against
## §2.7's own description of where the spawn belongs. **A point in no zone is not
## illegal** — most of the district's street area is outside every zone rectangle.
func _where(at: Vector3, data: MapData) -> String:
	var parts: PackedStringArray = []
	for zone: MapZone in data.zones:
		if zone.bounds.has_point(Vector3(at.x, zone.bounds.position.y, at.z)):
			parts.append(String(zone.zone_name))
	var floor_name := "off every floor"
	for row: Array in VetraioLayout.FLOORS:
		if float(row[5]) != VetraioLayout.STREET_Y:
			continue
		if Rect2(float(row[1]), float(row[2]), float(row[3]), float(row[4])).has_point(
			Vector2(at.x, at.z)
		):
			floor_name = String(row[0])
			break
	if parts.is_empty():
		return floor_name + ", no zone"
	return "%s, %s" % [floor_name, ", ".join(parts)]


## Rule 5. **The zone data, not a floor name and not the layout's theatre table.**
## `PiazzaSecca` is a zone spanning several floors, so filtering by floor name — what
## this tool did until 2026-08-21 — passed over the thing rule 5 is about.
##
## **AND IT MUST BE THE SAME POINT-IN-BOX TEST THE ZONES THEMSELVES USE.** A first
## fix asked `Rect2.has_point` against `VetraioLayout.THEATRES`, which is **exclusive
## at the far edge**, while `MapZone.bounds` is an `AABB` and `AABB.has_point` is
## **inclusive**. So (90, 66) — Piazza Secca's own eastern boundary — was reported
## outside the plaza by one convention and inside it by the other, and the tool
## offered it as `S5`'s nearest legal relocation. Two conventions for one question is
## how an instrument disagrees with the game while looking correct.
func _in_a_theatre(at: Vector3, data: MapData) -> bool:
	for zone: MapZone in data.zones:
		if zone.is_theatre and zone.bounds.has_point(Vector3(at.x, zone.bounds.position.y, at.z)):
			return true
	return false


## Rule 4, measured against circuit **segments** rather than waypoints: §4.4 spaces
## waypoints 6–10 m apart, so "near a corner" and "near the route" differ by half a
## spacing. Same measurement `test_spawn_points.gd` makes.
func _nearest_circuit(at: Vector3, data: MapData) -> float:
	var best := INF
	var here := Vector2(at.x, at.z)
	for route: PackedVector3Array in data.circuits:
		for leg: int in route.size():
			var a: Vector3 = route[leg]
			var b: Vector3 = route[(leg + 1) % route.size()]
			best = minf(best, _to_segment(here, Vector2(a.x, a.z), Vector2(b.x, b.z)))
	return best


func _to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	var length_squared := span.length_squared()
	if length_squared < 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(span) / length_squared, 0.0, 1.0)
	return point.distance_to(a + span * t)


## What `CloneParity.seats_required()` answers, computed here because that class
## reads `Tuning` and this script has no autoloads. **Read from the profile, never
## written down**, so the day the floor or the persona list moves this tool moves
## with `test_spawn_points.gd` instead of grading against a number no document holds.
func _seats_required() -> int:
	return int(_tuning.crowd.clone_local_min) * CrowdRoster.PLAYABLE.size()


func _radius() -> float:
	return _tuning.crowd.clone_local_radius


func _far_enough(at: Vector3, others: Array[Vector3]) -> bool:
	for other: Vector3 in others:
		if Vector2(at.x - other.x, at.z - other.z).length() < 30.0:
			return false
	return true


## Anchors are what `CrowdPlacement` deals from, and 78 NPCs over 66 anchors is
## about 1.18 each — so seats are counted as anchors, which is the quantity a level
## author can actually move.
func _seats_at(at: Vector3, data: MapData) -> int:
	var near := 0
	var reach := _radius()
	for anchor: Vector3 in data.idle_anchors:
		if Vector2(anchor.x - at.x, anchor.z - at.z).length() <= reach:
			near += 1
	return near
