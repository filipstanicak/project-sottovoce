## **HOW MANY IDLE ANCHORS EACH ZONE ACTUALLY GETS, AND WHAT EACH SPAWN CAN SEE.**
## GDD-05 §4.4 and §2.7, US-0096.
##
##     godot --headless -s res://tools/anchor_census.gd
##
## US-0096 found three of six spawn points unable to hold
## `TUN-CROWD-CLONE-LOCAL-MIN` at any arrangement, one of them seeing no NPC at
## all. This prints the two tables that say why: what each zone asked for against
## what the grid gave it, and what each spawn point can see.
extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var data := load("res://data/maps/map_vetraio.tres") as MapData
	print("--- zones: wanted vs placed ---")
	var placed_total := 0
	for zone: MapZone in data.zones:
		var wanted := zone.expected_anchors()
		var placed := 0
		for anchor: Vector3 in data.idle_anchors:
			if zone.bounds.has_point(Vector3(anchor.x, zone.bounds.position.y, anchor.z)):
				placed += 1
		placed_total += placed
		var spacing := 0.0
		if wanted > 0:
			spacing = sqrt((zone.bounds.size.x * zone.bounds.size.z) / float(wanted))
		print(
			(
				"  %-18s %6.0f x %-5.0f m  wanted %3d  placed %3d  spacing %5.2f m%s"
				% [
					zone.zone_name,
					zone.bounds.size.x,
					zone.bounds.size.z,
					wanted,
					placed,
					spacing,
					(
						"   <-- SPACING EXCEEDS THE SHORT SIDE"
						if wanted > 0 and spacing > minf(zone.bounds.size.x, zone.bounds.size.z)
						else ""
					)
				]
			)
		)
	print(
		(
			"  total placed: %d of %d anchors in the resource"
			% [placed_total, data.idle_anchors.size()]
		)
	)

	print("--- spawn points: anchors within the local radius ---")
	var radius := 25.0
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

	_search_for_spawn_sites(data)
	quit()


## **IS THERE ANYWHERE LEGAL TO PUT A STARVED SPAWN POINT?** GDD-05 §2.7 rule 1 is
## 30 m spawn-to-spawn and rule 5 is street level outside Piazza Secca; US-0096
## adds that a spawn needs 4 x `TUN-CROWD-CLONE-LOCAL-MIN` clone seats within
## `TUN-CROWD-CLONE-LOCAL-RADIUS`. Searching the floor rectangles on a 2 m grid
## turns "moving it will not help" from an opinion into a count.
func _search_for_spawn_sites(data: MapData) -> void:
	print("--- legal relocations for a starved spawn, 2 m grid over every street floor ---")
	var seats_needed := 8
	for slot: int in data.spawn_points.size():
		var here: Vector3 = data.spawn_points[slot]
		var others: Array[Vector3] = []
		for other: int in data.spawn_points.size():
			if other != slot:
				others.append(data.spawn_points[other])
		var found := 0
		var best := 0
		# **THE NEAREST LEGAL SITE, NOT THE BEST ONE.** GDD-05 §2.7 names where each
		# spawn is and its anti-spawn-camp analysis assumes they are spread; dragging
		# them all to the anchor-rich centre would satisfy the seat count and quietly
		# put three of them inside one camper's 40 m.
		var nearest := Vector3.INF
		var nearest_gap := INF
		for floor_row: Array in VetraioLayout.FLOORS:
			if floor_row[5] != VetraioLayout.STREET_Y or String(floor_row[0]) == "PiazzaSecca":
				continue
			var x: float = floor_row[1]
			while x < float(floor_row[1]) + float(floor_row[3]):
				var z: float = floor_row[2]
				while z < float(floor_row[2]) + float(floor_row[4]):
					var at := Vector3(x, 0.0, z)
					if _far_enough(at, others):
						var seats := _seats_at(at, data)
						best = maxi(best, seats)
						if seats >= seats_needed:
							found += 1
							var gap := Vector2(at.x - here.x, at.z - here.z).length()
							if gap < nearest_gap:
								nearest_gap = gap
								nearest = at
					z += 2.0
				x += 2.0
		print(
			(
				"  spawn (%6.1f, %6.1f): %2d anchors now | %d legal sites with %d+ | nearest such %v at %.1f m"
				% [here.x, here.z, _seats_at(here, data), found, seats_needed, nearest, nearest_gap]
			)
		)


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
	for anchor: Vector3 in data.idle_anchors:
		if Vector2(anchor.x - at.x, anchor.z - at.z).length() <= 25.0:
			near += 1
	return near
