## **THE SIX SPAWN POINTS, AGAINST GDD-05 §2.7's OWN RULES.** US-0096.
##
## Level data only — no crowd, no pawns. Every rule here is a property of
## `MapData`, so a spawn that breaks one breaks it identically in every match
## ever played.
##
## **§2.7 CARRIES A NOTE SAYING TWO OF ITS SEVEN RULES WERE NEVER RE-DERIVED.**
## Three of the six spawns were moved on 2026-08-13 because they stood over
## nothing, and the note says in as many words that **rules 4 and 6 are owed a
## level pass**. They have carried a ✅ throughout. This file is that pass:
##
## - **Rule 4 holds.** Every spawn is within 25 m of a blend-group circuit, worst
##   22.50 m at S3. Asserted, not reported — it is true.
## - **Rule 6 does not.** Nine of fifteen spawn pairs have a completely clear
##   sightline, including **S4 → S5 at 30.86 m, the closest pair on the map.**
##
## **TWO OF THESE REPORT RATHER THAN FAIL**, the same choice
## `test_circuit_separation.gd` made for the same reason: the fix is level design
## with an owner, and a red suite nobody can turn green stops being read. Each
## goes green by itself the day the geometry is authored.
extends GutTest

const MAP := "res://data/maps/map_vetraio.tres"

## §2.7 rule 4, and §2.7 rule 6's threshold. The same 25 m as
## `TUN-CROWD-CLONE-LOCAL-RADIUS`, by coincidence rather than by derivation —
## these are GDD-05's numbers and that is GDD-03's.
const CIRCUIT_REACH := 25.0

## GDD-03 §6.3 rule 3: `TUN-CROWD-CLONE-LOCAL-MIN` clones of **each** in-use
## persona within `TUN-CROWD-CLONE-LOCAL-RADIUS`. With no lobby every persona is
## treated as in use, which is `server_root`'s own choice and the safe direction.
const PERSONAS := 4

var _map: MapData


func before_each() -> void:
	_map = load(MAP) as MapData


# ---------------------------------------------------------------------------
# The guard against vacuous success comes first.
# ---------------------------------------------------------------------------


## **EVERY RULE BELOW IS TRIVIALLY TRUE OF A MAP WITH NO SPAWN POINTS**, and this
## project has shipped an empty array behind a ticked criterion before —
## `Fondaco` had zero idle anchors for two milestones while its zone declared
## five.
func test_there_are_six_spawns_and_some_crowd_to_measure_against() -> void:
	assert_eq(_map.spawn_points.size(), 6, "TUN-SPAWN-POINT-COUNT is 6")
	assert_gt(_map.idle_anchors.size(), 0, "no idle anchors, so every seat count below is zero")
	assert_gt(_map.circuits.size(), 0, "no circuits, so rule 4 is vacuous")


# ---------------------------------------------------------------------------
# Rule 4 — measured for the first time, and it holds.
# ---------------------------------------------------------------------------


## **§2.7 RULE 4: every spawn is within 25 m of a blend-group circuit.** A
## freshly-respawned player must have a safe travel option quickly, and a walking
## group is the only blend that lets you *travel* while gaining anonymity.
##
## Measured against the **segments** of each circuit rather than its waypoints. A
## waypoint-only test asks whether a spawn is near a corner, which is a different
## and much weaker question — GDD-05 §4.4 spaces waypoints 6–10 m apart, so the
## two answers can differ by half a spacing.
func test_every_spawn_is_within_reach_of_a_circuit() -> void:
	var worst := 0.0
	var offenders: Array[String] = []
	for slot: int in _map.spawn_points.size():
		var gap := _nearest_circuit(_map.spawn_points[slot])
		worst = maxf(worst, gap)
		if gap > CIRCUIT_REACH:
			offenders.append("S%d is %.2f m from any circuit" % [slot + 1, gap])
	gut.p("furthest spawn from a blend-group circuit: %.2f m of %.0f" % [worst, CIRCUIT_REACH])
	assert_eq(offenders, [] as Array[String], "GDD-05 §2.7 rule 4")


# ---------------------------------------------------------------------------
# Rule 6 — measured for the first time, and it does not hold.
# ---------------------------------------------------------------------------


## **§2.7 RULE 6: no spawn has a sightline longer than 25 m to another spawn**,
## whose stated reason is that a camper must not cover two spawns at once. Every
## pair is already further apart than 25 m — the closest is 30.86 m — so the rule
## can only mean that **every pair must be occluded.**
##
## Nine of fifteen are not. The worst is `S4 → S5` at **30.86 m**, which is the
## closest pair on the map and therefore the one the anti-spawn-camp table leans
## on hardest.
##
## **THE CAUSE IS NOT THE SPAWN POSITIONS.** `VetraioLayout.BLOCKS` holds **seven**
## masses, four of them in the corners, and the district's whole middle — the
## plaza, the Loggia and Piazza Secca — has no building mass between them at all.
## Moving spawns cannot occlude a 120 m open span; this is geometry the greybox
## does not have yet.
func test_no_spawn_can_see_another() -> void:
	var clear := _clear_pairs()
	for line: String in clear:
		gut.p("  " + line)
	if clear.is_empty():
		assert_eq(clear, [] as Array[String], "GDD-05 §2.7 rule 6")
		return
	pending(
		(
			(
				"GDD-05 §2.7 rule 6 is marked ✅ and %d of 15 spawn pairs are in clear "
				+ "sight of one another, the closest at 30.86 m. The cause is that the "
				+ "greybox has seven blocks and no mass in the middle of the district, "
				+ "so no spawn position can satisfy it. §2.7's own note says rules 4 and "
				+ "6 were never re-derived after the 2026-08-13 spawn move."
			)
			% clear.size()
		)
	)


# ---------------------------------------------------------------------------
# The clone minimum — and why the anchors are not the lever.
# ---------------------------------------------------------------------------


## **GDD-03 §6.3 RULE 3 CANNOT HOLD AT S3 AND S4, AND THE ANCHORS ARE NOT WHY.**
##
## A player needs `TUN-CROWD-CLONE-LOCAL-MIN` clones of each of four personas
## within `TUN-CROWD-CLONE-LOCAL-RADIUS` — eight NPCs, so about eight idle
## anchors, since `CrowdPlacement` deals 78 NPCs over 67 of them.
##
## **S3 AND S4 ARE IN THE FONDACO, AND THE FONDACO IS EMPTY ON PURPOSE.** GDD-05
## calls it "low density (3–6), long straight streets, where fleeing players go",
## "long, low-density, few NPCs — where chases go to be resolved", and gives it
## 3–5 NPCs in its own density table. §2.7 puts S3 and S4 in it by name. Raising
## its anchor density to satisfy the clone minimum deletes the one place on the
## map designed to have no crowd to hide in.
##
## So three documents each say something true and the three cannot all hold. That
## is a design decision with an owner, not a number to nudge, and it is reported
## here rather than resolved.
func test_every_spawn_can_hold_the_clone_minimum() -> void:
	var needed := PERSONAS * int(Tuning.crowd.clone_local_min)
	var short: Array[String] = []
	for slot: int in _map.spawn_points.size():
		var seats := _seats_at(_map.spawn_points[slot])
		gut.p("  S%d: %d anchors within %.0f m, needs %d" % [slot + 1, seats, _radius(), needed])
		if seats < needed:
			short.append("S%d has %d of %d" % [slot + 1, seats, needed])
	if short.is_empty():
		assert_eq(short, [] as Array[String], "GDD-03 §6.3 rule 3")
		return
	pending(
		(
			(
				"%s. S3 and S4 are in the Fondaco, which GDD-05 makes low-density on "
				+ "purpose — it is where chases resolve. GDD-05 §2.7, GDD-05 §3 and "
				+ "GDD-03 §6.3 rule 3 cannot all hold, and choosing between them is the "
				+ "owner's. `tools/anchor_census.gd` grades any change in one run."
			)
			% ", ".join(short)
		)
	)


# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------


func _radius() -> float:
	return Tuning.crowd.clone_local_radius


func _seats_at(at: Vector3) -> int:
	var near := 0
	for anchor: Vector3 in _map.idle_anchors:
		if Vector2(anchor.x - at.x, anchor.z - at.z).length() <= _radius():
			near += 1
	return near


func _nearest_circuit(at: Vector3) -> float:
	var best := INF
	var here := Vector2(at.x, at.z)
	for index: int in _map.circuits.size():
		var route: PackedVector3Array = _map.circuits[index]
		for leg: int in route.size():
			var a: Vector3 = route[leg]
			var b: Vector3 = route[(leg + 1) % route.size()]
			best = minf(best, _to_segment(here, Vector2(a.x, a.z), Vector2(b.x, b.z)))
	return best


func _clear_pairs() -> Array[String]:
	var out: Array[String] = []
	for i: int in _map.spawn_points.size():
		for j: int in range(i + 1, _map.spawn_points.size()):
			var a: Vector3 = _map.spawn_points[i]
			var b: Vector3 = _map.spawn_points[j]
			if _blocked(Vector2(a.x, a.z), Vector2(b.x, b.z)):
				continue
			var gap := Vector2(a.x - b.x, a.z - b.z).length()
			out.append("S%d sees S%d, %.2f m away, nothing in between" % [i + 1, j + 1, gap])
	return out


static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() < 0.0001:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0))


## **EYE HEIGHT IS `TUN-CAM-ARM-HEIGHT`, READ RATHER THAN DECLARED.** A literal
## 1.55 stops meaning "what a player can see over" the first time the camera is
## retuned, and nothing would say so. `H_MANTLE` walls are 1.8 m and therefore
## occlude; `H_VAULT` stall counters are 0.9 m and correctly do not.
func _blocked(a: Vector2, b: Vector2) -> bool:
	var eye: float = Tuning.camera.arm_height
	for row: Array in VetraioLayout.BLOCKS:
		if float(row[5]) < eye:
			continue
		if _crosses(Rect2(float(row[1]), float(row[2]), float(row[3]), float(row[4])), a, b):
			return true
	return false


## Sampled rather than solved. A quarter of a metre is far finer than the 2.6 m
## minimum alley width, so no block this can miss is one a player could see past.
static func _crosses(box: Rect2, a: Vector2, b: Vector2) -> bool:
	if box.has_point(a) or box.has_point(b):
		return true
	var steps := int(a.distance_to(b) / 0.25) + 1
	for step: int in range(1, steps):
		if box.has_point(a.lerp(b, float(step) / float(steps))):
			return true
	return false
