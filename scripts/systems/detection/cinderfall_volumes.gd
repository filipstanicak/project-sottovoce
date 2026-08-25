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
class_name CinderfallVolumes
extends RefCounted

## `[centre, expiry_tick]` per active cloud. Small by construction — one ability,
## a 45 s cooldown, six players.
var _clouds: Array = []


## Place a cloud at `at`, live until `TUN-CINDERFALL-DURATION` has passed.
func add(at: Vector3, tick: int) -> void:
	_clouds.append([at, tick + maxi(Tuning.ticks(&"TUN-CINDERFALL-DURATION"), 1)])


## Drop everything that has burned out. Called once a tick, before the queries,
## so a cloud cannot block a ray on the tick after it expired.
func expire(tick: int) -> void:
	var living: Array = []
	for cloud: Array in _clouds:
		if int(cloud[1]) > tick:
			living.append(cloud)
	_clouds = living


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
func blocks(from: Vector3, to: Vector3) -> bool:
	if _clouds.is_empty():
		return false
	var radius := _radius()
	if radius <= 0.0:
		return false
	for cloud: Array in _clouds:
		if _distance_squared_to_segment(cloud[0] as Vector3, from, to) <= radius * radius:
			return true
	return false


## `TUN-CINDERFALL-RADIUS`, and zero if the ability is not in the profile at all —
## in which case there is nothing to block with. **`TUN-CINDERFALL-BLOCKS-LOS` is
## honoured here rather than assumed**: TUNABLES gives it as a bool so it can be
## turned off without a code change, and a rule that reads its own switch is one
## an owner can actually experiment with.
func _radius() -> float:
	if Tuning.profile == null:
		return 0.0
	var data := Tuning.profile.abilities.get(Ids.ABIL_CINDERFALL) as AbilityData
	if data == null or not data.blocks_los:
		return 0.0
	return data.radius


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
