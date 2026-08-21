## **THE OPENING ARRANGEMENT CONTAINS EVERY PLAYER'S CLONES.** US-0096, US-0047,
## GDD-03 §6.3 rule 3.
##
## US-0047's director closes a local hole in about eighteen seconds, because that
## is how long a clone takes to walk 25 m. A match that *begins* with a hole is
## therefore a match whose first twenty seconds the rule cannot cover — which is
## why rule 3 no longer binds there, and why `CrowdSeating` is what makes the
## opening honest rather than merely forgiven. This is the other end of it.
##
## **THE COUNTERFACTUAL RUNS FIRST.** Every assertion here is that a spawn point is
## not short of a persona. If the round-robin arrangement were never short of one,
## all of them would pass with `CrowdSeating` deleted, and this file has to prove
## it is testing something before it tests it.
extends GutTest

const SEED := 20260818
const MAP_DATA := "res://data/maps/map_vetraio.tres"
const CROWD := 78
const PLAYERS := 6

var _map: MapData
var _roster: Array[StringName]
var _raw: PackedVector3Array


func before_each() -> void:
	_map = load(MAP_DATA) as MapData
	_roster = CrowdRoster.derive(CROWD, SEED, CrowdRoster.PLAYABLE, PLAYERS)
	# No navigation map: `CrowdPlacement` keeps the scatter and skips the snap,
	# which is the arrangement's *shape* without needing a live navmesh. The snap
	# is `CrowdPlacement`'s own test's business, and seating never touches it.
	_raw = CrowdPlacement.positions(CROWD, SEED, _map.idle_anchors, RID())


## How many clones of `persona` stand within the local radius of `centre`, given
## a seating — an array where entry *i* is the position NPC *i* was given.
func _near(centre: Vector3, persona: StringName, seating: PackedVector3Array) -> int:
	var radius: float = Tuning.crowd.clone_local_radius
	var found := 0
	for index: int in mini(_roster.size(), seating.size()):
		if _roster[index] != persona:
			continue
		var at := seating[index]
		if Vector2(at.x - centre.x, at.z - centre.z).length() <= radius:
			found += 1
	return found


## How many NPC seats — of any identity — this spawn point can see at all.
## **A PERMUTATION CANNOT CONJURE A SEAT THAT IS NOT THERE**, so this is what
## separates the code's failure from the map's.
func _seats(centre: Vector3) -> int:
	var radius: float = Tuning.crowd.clone_local_radius
	var seats := 0
	for at: Vector3 in _raw:
		if Vector2(at.x - centre.x, at.z - centre.z).length() <= radius:
			seats += 1
	return seats


## Can this spawn point hold the minimum for all four personas at any arrangement?
func _feasible(centre: Vector3) -> bool:
	return _seats(centre) >= CloneParity.seats_required()


## `[worst, short_pairs, short_pairs_at_spawn_points_that_had_room]`. The third is
## the only number this story's code is answerable for.
func _audit(seating: PackedVector3Array) -> Array:
	var least: int = int(Tuning.crowd.clone_local_min)
	var worst := 99
	var short := 0
	var short_feasible := 0
	for centre: Vector3 in _map.spawn_points:
		var room := _feasible(centre)
		for persona: StringName in CrowdRoster.PLAYABLE:
			var seen := _near(centre, persona, seating)
			worst = mini(worst, seen)
			if seen < least:
				short += 1
				if room:
					short_feasible += 1
	return [worst, short, short_feasible]


func test_how_many_seats_each_spawn_point_can_even_see() -> void:
	# **THE FEASIBILITY QUESTION, ASKED BEFORE THE ALGORITHM IS BLAMED.** Satisfying
	# the minimum for four personas needs 4 x TUN-CROWD-CLONE-LOCAL-MIN clone seats
	# inside the radius. No permutation can conjure a seat that is not there, so if
	# a spawn point cannot see that many NPCs at all, the constraint is the map's
	# and not the code's.
	var radius: float = Tuning.crowd.clone_local_radius
	var needed := CloneParity.seats_required()
	var starved := 0
	for centre: Vector3 in _map.spawn_points:
		var seats := 0
		for at: Vector3 in _raw:
			if Vector2(at.x - centre.x, at.z - centre.z).length() <= radius:
				seats += 1
		if seats < needed:
			starved += 1
		gut.p("spawn %v: %d seats within %.0f m, %d needed" % [centre, seats, radius, needed])
	gut.p(
		(
			"%d of %d spawn points cannot hold the minimum at any permutation"
			% [starved, _map.spawn_points.size()]
		)
	)
	# **REPORTED, NOT FAILED — IT IS THE LEVEL'S, LIKE US-0043's CIRCUITS.** Three of
	# `MAP-VETRAIO`'s six spawn points cannot see 8 NPCs within 25 m and the thinnest
	# sees **one**, so no arrangement satisfies the floor there at match start. That
	# is **GDD-05 §2.7 rule 8** as of 2026-08-21 and no longer GDD-03 §6.3 rule 3,
	# which is scoped past the placement instant by `CloneParity.grace_seconds()` —
	# `test_spawn_points.gd` grades it. This assertion only refuses a district where
	# *nothing* is testable.
	assert_lt(
		starved,
		_map.spawn_points.size(),
		"no spawn point on this map can hold the local minimum — seating cannot be tested at all"
	)

	# **AND IT IS GEOMETRY, NOT THIS SEED.** A census that moved with the seed would
	# be a scatter artefact and this whole finding would be one unlucky match. The
	# positions are anchors plus at most `SCATTER` metres, so a spawn point with no
	# anchor near it has no seats at any seed — asserted rather than assumed.
	for other: int in [SEED + 1, SEED * 7 + 13]:
		var elsewhere := CrowdPlacement.positions(CROWD, other, _map.idle_anchors, RID())
		var also := 0
		for centre: Vector3 in _map.spawn_points:
			var seats := 0
			for at: Vector3 in elsewhere:
				if Vector2(at.x - centre.x, at.z - centre.z).length() <= radius:
					seats += 1
			if seats < needed:
				also += 1
		# **WITHIN ONE, NOT EQUAL, AND THE TOLERANCE HAS A REASON.** One spawn point
		# sits at *exactly* the eight seats it needs, so the 3 m placement scatter
		# tips it either way from seed to seed. Demanding equality made this
		# assertion fail the moment the anchor grid was fixed — a test asserting a
		# number it had no right to. What is seed-independent is the *finding*: a
		# district whose shortfall came and went with the seed would be one unlucky
		# match rather than a level-design problem.
		assert_true(
			absi(also - starved) <= 1,
			(
				(
					"seed %d starves %d spawn points against seed %d's %d — more than a "
					+ "boundary case, so the census follows the scatter and this is not the "
					+ "level-design finding it is recorded as"
				)
				% [other, also, SEED, starved]
			)
		)
		assert_gt(also, 0, "seed %d starves nobody — the finding is a one-seed artefact" % other)


func test_the_round_robin_arrangement_really_is_short_somewhere() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** If the raw deal already satisfied the local
	# minimum everywhere, this whole story would be fixing nothing and every
	# assertion below would pass with the code deleted.
	var before := _audit(_raw)
	gut.p(
		(
			"round-robin: worst %d of %d required, %d of %d (spawn x persona) pairs short"
			% [
				before[0],
				int(Tuning.crowd.clone_local_min),
				before[1],
				_map.spawn_points.size() * CrowdRoster.PLAYABLE.size()
			]
		)
	)
	assert_gt(
		int(before[1]),
		0,
		(
			"the unseated crowd already satisfies TUN-CROWD-CLONE-LOCAL-MIN at every spawn "
			+ "point, so US-0096 fixes nothing and every test in this file is vacuous"
		)
	)


func test_seating_satisfies_the_local_minimum_at_every_spawn_point() -> void:
	# The story's first criterion, and the one that makes US-0047's "always" true
	# from the first tick rather than from the twentieth second.
	var before := _audit(_raw)
	var seated := CrowdSeating.seat(_raw, _roster, _map.spawn_points, SEED)
	var after := _audit(seated)
	gut.p(
		(
			"pairs short: %d -> %d overall, %d -> %d where the spawn point had room"
			% [before[1], after[1], before[2], after[2]]
		)
	)
	# **THE CODE IS ANSWERABLE FOR THE SPAWN POINTS THAT HAVE ROOM, AND ONLY
	# THOSE.** Three of `MAP-VETRAIO`'s six cannot hold four personas' minimum at
	# any permutation — one of them can see **no NPC at all** within 25 m. That is
	# the map's, it is recorded in US-0096, and this assertion goes green by itself
	# the day the idle anchors are re-authored.
	assert_eq(
		int(after[2]),
		0,
		(
			(
				"a spawn point WITH ROOM begins the match short of an in-use persona; "
				+ "the worst count anywhere was %d against TUN-CROWD-CLONE-LOCAL-MIN %d"
			)
			% [after[0], Tuning.crowd.clone_local_min]
		)
	)
	assert_lt(int(after[1]), int(before[1]), "seating did not reduce the shortfall at all")


func test_it_is_a_permutation_and_moves_nobody_anywhere_new() -> void:
	# **THE PROPERTY THAT MAKES EVERY `CrowdPlacement` TEST STILL VALID.** Seating
	# reassigns which NPC stands where; it must not invent a position, drop one, or
	# duplicate one. If the multiset of positions is unchanged then the navmesh
	# snapping, the anchor round-robin and the scatter bound cannot have regressed,
	# because they are properties of that multiset.
	var seated := CrowdSeating.seat(_raw, _roster, _map.spawn_points, SEED)
	assert_eq(seated.size(), _raw.size(), "seating changed how many NPCs there are")
	var before: Dictionary = {}
	var after: Dictionary = {}
	for at: Vector3 in _raw:
		before[at] = int(before.get(at, 0)) + 1
	for at: Vector3 in seated:
		after[at] = int(after.get(at, 0)) + 1
	assert_eq(after, before, "seating invented, dropped or duplicated a position")


func test_it_is_deterministic_from_the_seed() -> void:
	# GDD-03 §6.3 rule 4's neighbourhood: two servers given one seed must produce
	# one district. Seating is derived like the roster and the positions are, so a
	# replay is a replay.
	var once := CrowdSeating.seat(_raw, _roster, _map.spawn_points, SEED)
	var twice := CrowdSeating.seat(_raw, _roster, _map.spawn_points, SEED)
	assert_eq(once, twice, "the same seed seated the crowd two different ways")


func test_it_changes_something_at_all() -> void:
	# Paired with the permutation test above: "unchanged multiset" is satisfied
	# perfectly by returning the input, and that would pass every structural check
	# in this file while fixing nothing.
	var seated := CrowdSeating.seat(_raw, _roster, _map.spawn_points, SEED)
	var moved := 0
	for index: int in seated.size():
		if seated[index] != _raw[index]:
			moved += 1
	gut.p("seating moved %d of %d NPCs" % [moved, CROWD])
	assert_gt(moved, 0, "seating returned its input unchanged")


func test_a_crowd_with_nobody_to_seat_for_is_returned_as_it_was() -> void:
	# No spawn points means no local minimum to satisfy. Returning the input is
	# correct; crashing or reshuffling for no reason is not.
	var seated := CrowdSeating.seat(_raw, _roster, PackedVector3Array(), SEED)
	assert_eq(seated, _raw, "an unspawnable map still had its crowd reshuffled")


func test_the_server_actually_seats_its_crowd() -> void:
	# **A CRITERION CAN BE TRUE OF A CLASS AND FALSE OF THE GAME.** Everything above
	# proves `CrowdSeating` works; none of it would notice `server_root` never
	# calling it, which is exactly what happened to US-0039's pool — ninety bodies
	# allocated in tests and none in a scene, with the criterion ticked.
	var source := SourceScanner.read("res://scripts/server/server_root.gd")
	assert_gt(source.length(), 500, "server_root.gd is missing or tiny — the scan is vacuous")
	assert_true(
		source.contains("CrowdSeating.seat("),
		"server_root places the crowd but never seats it, so the shipped opening is unsorted"
	)


func test_filler_is_what_gets_moved_first() -> void:
	# **THE REASON THE GREEDY PASS TERMINATES.** GDD-03 §6.3 puts no local
	# requirement on archetypes, so trading one away cannot break another spawn
	# point's minimum. Trading clones at exactly the minimum could, and that is the
	# oscillation US-0047's `_nearest_spare` had to be designed against too.
	var seated := CrowdSeating.seat(_raw, _roster, _map.spawn_points, SEED)
	var clones_moved := 0
	var filler_moved := 0
	for index: int in seated.size():
		if seated[index] == _raw[index]:
			continue
		if CrowdRoster.PLAYABLE.has(_roster[index]):
			clones_moved += 1
		else:
			filler_moved += 1
	gut.p("moved: %d filler, %d clones" % [filler_moved, clones_moved])
	assert_gt(filler_moved, 0, "no filler was moved — the cheap currency went unspent")
