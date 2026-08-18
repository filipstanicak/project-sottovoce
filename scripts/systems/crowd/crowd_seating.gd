## **WHICH NPC STANDS AT WHICH STARTING POSITION.** US-0096, TDD-08 §5.1,
## GDD-03 §6.3 rule 3. SERVER ONLY, and PURE — positions, a roster and some spawn
## points in, a permutation out. No pool, no bodies, no navigation server.
##
## **THE MISSING JOIN, NOT A NEW PLACEMENT.** `CrowdPlacement.positions()` answers
## "where does slot *n* stand" and `CrowdRoster.derive()` answers "who is index
## *n*". Both are derived from `match_seed` and both are correct. Nobody ever
## matched them — so a match could begin with every Lucerna in the north plaza and
## a Lucerna player spawning in the south market, which is exactly the silent
## failure TDD-08 §5.1 calls the one that actually matters, arriving before the
## director that fixes it has had a single pass.
##
## **IT IS A PERMUTATION, AND THAT IS WHAT MAKES IT SAFE.** The multiset of
## positions is unchanged, so the navmesh snapping, the anchor round-robin and the
## scatter bound cannot regress: they are properties of that multiset, and this
## only reassigns who occupies it. No clone is put anywhere a clone was not
## already going to stand.
##
## **FILLER IS THE CURRENCY, AND THAT IS WHY THE PASS TERMINATES.** About thirty
## of the seventy-eight are archetypes, and GDD-03 §6.3 puts no local requirement
## on them at all. A spawn point short of Lucerna therefore trades a nearby filler
## for a distant Lucerna: the filler was not needed anywhere in particular and the
## Lucerna was surplus where it stood, so no other spawn point's minimum can break.
## A loop that fixed each constraint by taking from another would oscillate, which
## is the same trap `CloneBalance._nearest_spare` had to be designed against.
class_name CrowdSeating
extends RefCounted

## Nothing suitable was found. `-1` rather than 0, which is a real index.
const NOBODY := -1


## `positions` reassigned so every spawn point holds `TUN-CROWD-CLONE-LOCAL-MIN`
## clones of each in-use persona within `TUN-CROWD-CLONE-LOCAL-RADIUS`.
##
## Returns the input untouched when there is nothing to satisfy — an empty spawn
## list is a map nobody plays, not an error.
static func seat(
	positions: PackedVector3Array, roster: Array, spawns: Array, match_seed: int
) -> PackedVector3Array:
	var seating := positions.duplicate()
	if spawns.is_empty() or roster.is_empty():
		return seating
	var radius: float = Tuning.crowd.clone_local_radius
	var least: int = int(Tuning.crowd.clone_local_min)
	# **MIXED, NOT USED RAW.** US-0039's lesson: adjacent seeds share most of their
	# draws, so every match in a session would resolve its ties the same way.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(match_seed) ^ 0x5BF03635

	for centre: Vector3 in spawns:
		for persona: StringName in CrowdRoster.PLAYABLE:
			_fill(seating, roster, centre, persona, radius, least, spawns, rng)
	return seating


## Bring one spawn point up to the minimum for one persona.
static func _fill(
	seating: PackedVector3Array,
	roster: Array,
	centre: Vector3,
	persona: StringName,
	radius: float,
	least: int,
	spawns: Array,
	rng: RandomNumberGenerator
) -> void:
	var short := least - _count(seating, roster, centre, persona, radius)
	while short > 0:
		var give := _spare_seat_near(seating, roster, centre, persona, radius, least, spawns)
		if give == NOBODY:
			return
		var take := _clone_away_from(seating, roster, centre, persona, radius, least, spawns, rng)
		if take == NOBODY:
			return
		var swap := seating[give]
		seating[give] = seating[take]
		seating[take] = swap
		short -= 1


## Clones of `persona` seated within `radius` of `centre`.
static func _count(
	seating: PackedVector3Array, roster: Array, centre: Vector3, persona: StringName, radius: float
) -> int:
	var reach := radius * radius
	var found := 0
	for index: int in mini(roster.size(), seating.size()):
		if roster[index] == persona and _flat_squared(seating[index], centre) <= reach:
			found += 1
	return found


## **A SEAT NEAR `centre` WHOSE OCCUPANT IS NOT NEEDED THERE.** Filler first,
## because an archetype has no local requirement anywhere and trading one can
## break nothing. Only then a clone of a persona that is over the minimum here —
## and never one at exactly the minimum, which would fix this hole by digging
## another and let the pass run forever.
static func _spare_seat_near(
	seating: PackedVector3Array,
	roster: Array,
	centre: Vector3,
	persona: StringName,
	radius: float,
	least: int,
	spawns: Array
) -> int:
	var reach := radius * radius
	var surplus := NOBODY
	for index: int in mini(roster.size(), seating.size()):
		var who: StringName = roster[index]
		if who == persona or _flat_squared(seating[index], centre) > reach:
			continue
		if not CrowdRoster.PLAYABLE.has(who):
			return index
		if (
			surplus == NOBODY
			and _spare_everywhere(seating, roster, index, who, radius, least, spawns)
		):
			surplus = index
	return surplus


## Would moving `index` out leave every spawn point that can see it still at or
## above the minimum for its persona?
static func _spare_everywhere(
	seating: PackedVector3Array,
	roster: Array,
	index: int,
	who: StringName,
	radius: float,
	least: int,
	spawns: Array
) -> bool:
	var reach := radius * radius
	for centre: Vector3 in spawns:
		if _flat_squared(seating[index], centre) > reach:
			continue
		if _count(seating, roster, centre, who, radius) <= least:
			return false
	return true


## A clone of `persona` seated **outside** this region.
##
## **THE TAKE SIDE NEEDS THE SAME GUARD AS THE GIVE SIDE, AND DID NOT HAVE IT.**
## A clone outside *this* spawn point's radius can still be inside another's, and
## conscripting it fixes one spawn point by emptying a second — which is how a
## greedy pass over six spawn points hands the last two nothing. Measured: two
## spawn points with room were still short before this filter existed.
##
## Ties are broken from the seeded generator rather than by index, or the first
## clone in roster order would be conscripted every match.
static func _clone_away_from(
	seating: PackedVector3Array,
	roster: Array,
	centre: Vector3,
	persona: StringName,
	radius: float,
	least: int,
	spawns: Array,
	rng: RandomNumberGenerator
) -> int:
	var reach := radius * radius
	var free := PackedInt32Array()
	var any := PackedInt32Array()
	for index: int in mini(roster.size(), seating.size()):
		if roster[index] != persona or _flat_squared(seating[index], centre) <= reach:
			continue
		any.append(index)
		if _spare_everywhere(seating, roster, index, persona, radius, least, spawns):
			free.append(index)
	# Nobody's minimum first; anybody at all only if there is no such clone, since
	# a district that cannot satisfy every spawn point should still satisfy as many
	# as it can rather than refusing on the first conflict.
	var pool := free if not free.is_empty() else any
	if pool.is_empty():
		return NOBODY
	return pool[rng.randi_range(0, pool.size() - 1)]


## Horizontal and squared, like every other radius in the crowd: a clone on a
## balcony is not further from the spawn below in any sense anonymity cares about,
## and nothing here wants a distance — only an ordering against a radius.
static func _flat_squared(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz
