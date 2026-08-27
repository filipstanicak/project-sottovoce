## **WHERE A RESPAWNING PLAYER IS PUT.** GDD-05 §2.7 rules 2, 3 and 7, TDD-10 §6,
## US-0062. PURE Core.
##
## **A SPAWN SYSTEM THAT CAN FAIL IS A CRASH WAITING FOR A PLAYTEST** (ASM-0014),
## so `choose()` has no failing branch at all: the constraints filter, and when
## they filter everything away the fallback picks the point that is furthest from
## whoever the player most needs to be away from. The only way to get nothing back
## is to hand it no spawn points, which is a broken map rather than a full lobby.
##
## **THE TWO CONSTRAINTS ARE IN PRIORITY ORDER AND THEY ARE NOT THE SAME KIND.**
## Rule 2 is about *one* player — the killer, at 40 m, a third of the map diagonal
## — and rule 3 is about *every* living player at 12 m, which is
## `TUN-KILL-RANGE` with room to see it coming. Applying them in the other order
## would let a lobby that happens to be spread out veto the anti-revenge rule.
##
## **AND THE CHOICE IS MADE AT THE MOMENT OF RESPAWN, NEVER AT THE MOMENT OF
## DEATH.** Five seconds is long enough for the whole lobby to move; a point
## chosen at the contact frame would satisfy rule 3 against a world that no longer
## exists. `SpawnSystem` calls this when the timer expires and not before.
class_name SpawnRules
extends RefCounted

## No killer to stay away from — a join, or a death nobody is credited with.
## **`Vector3.INF` rather than `Vector3.ZERO`**, because the origin is a real
## place on this map and a player would be pushed away from it for no reason.
const NO_KILLER := Vector3.INF


## The spawn indices satisfying **both** constraints. May be empty, which is the
## case rule 7's fallback exists for.
static func candidates(
	points: Array[Vector3], killer_at: Vector3, others: PackedVector3Array, t: ContractTuning
) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in points.size():
		if not clear_of_killer(points[i], killer_at, t):
			continue
		if not clear_of_everyone(points[i], others, t):
			continue
		out.append(i)
	return out


## Rule 2. `TUN-RESPAWN-MIN-DIST-FROM-KILLER`, and vacuously true with no killer.
static func clear_of_killer(at: Vector3, killer_at: Vector3, t: ContractTuning) -> bool:
	if killer_at == NO_KILLER:
		return true
	return at.distance_to(killer_at) >= t.respawn_min_dist_from_killer


## Rule 3. `TUN-RESPAWN-MIN-DIST-FROM-ANY-PLAYER` against everybody still alive.
##
## **The respawning player is not in `others`**, and it is the caller's job to
## leave them out: a corpse standing at its own death position would otherwise
## veto every spawn near it, including the one it is about to be moved to.
static func clear_of_everyone(at: Vector3, others: PackedVector3Array, t: ContractTuning) -> bool:
	for other: Vector3 in others:
		if at.distance_to(other) < t.min_dist_from_any_player:
			return false
	return true


## **THE ONE ENTRY POINT, AND IT CANNOT FAIL.** Returns an index into `points`, or
## `-1` only when there are no points at all.
##
## **THE PICK IS AGAINST THE SEEDED GENERATOR, NEVER `Array.pick_random()`.** That
## one draws from the global RNG, which is both never-do #8 and non-deterministic
## — two servers replaying one seed would place the same death differently and
## describe different matches.
static func choose(
	points: Array[Vector3],
	killer_at: Vector3,
	others: PackedVector3Array,
	t: ContractTuning,
	rng: RandomNumberGenerator
) -> int:
	if points.is_empty():
		return -1
	var legal := candidates(points, killer_at, others, t)
	if legal.is_empty():
		return _fallback(points, killer_at, others)
	if rng == null:
		return legal[0]
	return legal[rng.randi_range(0, legal.size() - 1)]


## Rule 7. **Furthest from the killer**, or — when there is no killer — furthest
## from the nearest living player, which is the same question asked of a lobby
## rather than of one person.
##
## **DETERMINISTIC, WITH NO RANDOMNESS AT ALL.** The fallback runs when the lobby
## is packed tightly enough to veto every point, and the least bad answer is a
## property of the world rather than a draw. A random pick here would make the
## worst case in the game the one place a seed could not reproduce.
static func _fallback(
	points: Array[Vector3], killer_at: Vector3, others: PackedVector3Array
) -> int:
	var best := 0
	var best_clearance := -INF
	for i: int in points.size():
		var clearance := (
			points[i].distance_to(killer_at)
			if killer_at != NO_KILLER
			else _nearest_distance(points[i], others)
		)
		if clearance > best_clearance:
			best_clearance = clearance
			best = i
	return best


## Distance to the closest of `others`, or `INF` when nobody is alive.
static func _nearest_distance(at: Vector3, others: PackedVector3Array) -> float:
	var nearest := INF
	for other: Vector3 in others:
		nearest = minf(nearest, at.distance_to(other))
	return nearest
