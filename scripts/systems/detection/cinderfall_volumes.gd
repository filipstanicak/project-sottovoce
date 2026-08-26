## **THE ONE THING THAT BLOCKS LINE OF SIGHT AND IS NOT GEOMETRY.** GDD-04 §8.1,
## TUNABLES §8.1, US-0056. SERVER ONLY, and pure — spheres in, a yes or no out,
## with no physics server involved.
##
## `TUN-CINDERFALL-BLOCKS-LOS` is `true`: an active cinder cloud blocks detection,
## Compass lock and `SCORE-FOCUS` accumulation alike. It has to be checked
## *alongside* the world raycast rather than instead of it, because it is not on
## the navigation mesh, not in the collision world, and exists for
## `TUN-CINDERFALL-DURATION` 4.0 s and then does not.
##
## **A SPHERE RATHER THAN A BODY, DELIBERATELY.** Putting a `StaticBody3D` on the
## `WORLD` layer for four seconds would also block the traversal probes — so a
## player could vault a cloud — and would put a gameplay volume where
## `test_probes_mask_world_only.gd` promises only level geometry is.
##
## **NOTHING PLACES ONE YET.** `ABIL-CINDERFALL` is `SYS-ABILITY`'s, later in M4;
## `add()` is the entry point and has no caller, the same shape as
## `CrowdAlarm.startle_at` through all of M3.
##
## **A CLOUD REMEMBERS WHEN IT LIT AS WELL AS WHEN IT GOES OUT** (US-0060), which
## is what makes ADR-0010's rewind rule implementable: *"a cloud that had not yet
## appeared must not retroactively block, and one that has expired must still have
## blocked."* Both halves need a lifetime, not a liveness flag.
class_name CinderfallVolumes
extends RefCounted

## `[centre, lit_tick, expiry_tick]` per cloud. Small by construction — one
## ability, a 45 s cooldown, six players.
var _clouds: Array = []


## Place a cloud at `at`, live until `TUN-CINDERFALL-DURATION` has passed.
func add(at: Vector3, tick: int) -> void:
	_clouds.append([at, tick, tick + maxi(Tuning.ticks(&"TUN-CINDERFALL-DURATION"), 1)])


## Drop everything a rewind can no longer reach.
##
## **IT LAGS THE REWIND CEILING RATHER THAN THE EXPIRY**, and that is not tidiness.
## A kill is validated `RewindClamp` ticks in the past; dropping a cloud on the
## tick it burned out would mean a cloud that was up when the attacker acted, and
## went out 100 ms later, does not block the validation — which is exactly the
## half of ADR-0010's rule that says it must. The extra clouds held are at most
## `TUN-NET-LAGCOMP-MAX` of one ability's worth.
func expire(tick: int) -> void:
	var grace := RewindClamp.max_ticks()
	var living: Array = []
	for cloud: Array in _clouds:
		if int(cloud[2]) + grace > tick:
			living.append(cloud)
	_clouds = living


## Was this cloud alight at `tick`? Lit inclusive, expiry exclusive.
static func _alive_at(cloud: Array, tick: int) -> bool:
	return tick >= int(cloud[1]) and tick < int(cloud[2])


## How many clouds were alight at `tick`. `count()` answers about the array;
## this answers about the world, and after the retention change above the two
## differ for up to `TUN-NET-LAGCOMP-MAX`.
func count_at(tick: int) -> int:
	var n := 0
	for cloud: Array in _clouds:
		if _alive_at(cloud, tick):
			n += 1
	return n


## **IS `point` INSIDE A CLOUD THAT WAS ALIGHT AT `tick`?** TDD-10 §3's first
## gate: kill initiation is refused inside any cinder volume, **including the
## caster's own** — an ability that denied the area to everybody but the person
## who threw it would be a free kill setup rather than area denial.
func contains_at(point: Vector3, tick: int) -> bool:
	# **`TUN-CINDERFALL-BLOCKS-KILL` IS READ RATHER THAN ASSUMED**, the same way
	# `_radius()` reads `TUN-CINDERFALL-BLOCKS-LOS`. TUNABLES gives both as bools so
	# an owner can turn either off without a code change, and a rule that ignores
	# its own switch is one nobody can experiment with.
	if not _blocks_kill():
		return false
	var radius := _radius()
	if radius <= 0.0:
		return false
	for cloud: Array in _clouds:
		if (
			_alive_at(cloud, tick)
			and point.distance_squared_to(cloud[0] as Vector3) <= radius * radius
		):
			return true
	return false


func count() -> int:
	return _clouds.size()


func clear() -> void:
	_clouds.clear()


## Does any live cloud sit across the segment `from` -> `to`?
##
## **THE TEST IS AGAINST THE SEGMENT, NOT THE ENDPOINTS.** A cloud between two
## players touches neither of them, which is the whole point of area denial: it
## is placed in the gap. Testing "is either end inside a cloud" would let a hunter
## see straight through one they had thrown down the alley ahead.
## **AND IT TAKES THE TICK IT IS ASKED ABOUT** (US-0060), because since the
## retention change above the array holds clouds that have already gone out. A
## liveness question with no tick in it would have answered "blocked" for
## `TUN-NET-LAGCOMP-MAX` after every cloud burned out, in the one query line of
## sight, the Compass lock and `SCORE-FOCUS` all run through.
func blocks(from: Vector3, to: Vector3, tick: int) -> bool:
	if _clouds.is_empty() or not _blocks_los():
		return false
	var radius := _radius()
	if radius <= 0.0:
		return false
	for cloud: Array in _clouds:
		if not _alive_at(cloud, tick):
			continue
		if _distance_squared_to_segment(cloud[0] as Vector3, from, to) <= radius * radius:
			return true
	return false


## `ABIL-CINDERFALL`'s tuning row, or null if the ability is not in the profile at
## all — in which case there are no clouds and nothing to block with.
func _data() -> AbilityData:
	if Tuning.profile == null:
		return null
	return Tuning.profile.abilities.get(Ids.ABIL_CINDERFALL) as AbilityData


## `TUN-CINDERFALL-RADIUS`.
##
## **THE RADIUS IS NOT GATED ON EITHER SWITCH.** It used to return zero when
## `TUN-CINDERFALL-BLOCKS-LOS` was false, which folded "how big is a cloud" into
## "does a cloud stop sight" — harmless while sight was the only reader, and wrong
## the moment `SYS-KILL` asked the second question (US-0060). The two switches are
## now honoured by the two queries that answer to them.
func _radius() -> float:
	var data := _data()
	return 0.0 if data == null else data.radius


## `TUN-CINDERFALL-BLOCKS-LOS`. TUNABLES gives it as a bool so it can be turned off
## without a code change, and a rule that reads its own switch is one an owner can
## actually experiment with.
func _blocks_los() -> bool:
	var data := _data()
	return data != null and data.blocks_los


## `TUN-CINDERFALL-BLOCKS-KILL`. No kill may be *initiated* inside the radius, by
## anyone, including the caster.
func _blocks_kill() -> bool:
	var data := _data()
	return data != null and data.blocks_kill


## Squared distance from `point` to the segment `a` -> `b`. **Squared, like every
## other radius test in this project**: nothing here wants a distance, only an
## ordering against one.
static func _distance_squared_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var span := b - a
	var length_squared := span.length_squared()
	if length_squared <= 0.0001:
		return point.distance_squared_to(a)
	var along := clampf((point - a).dot(span) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(a + span * along)
