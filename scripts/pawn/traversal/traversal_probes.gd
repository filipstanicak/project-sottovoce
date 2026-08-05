## Casts the traversal probes and fills `ctx.probe_result`. TDD-06 §4, §6.
##
## Refreshed once per physics frame, **before** `step()`. Not inside it: raycasts
## are only valid in the physics step, and a state that cast its own would cast
## again on every reconciliation replay — the same query, against a world that
## has since moved on, producing an answer the original run never saw.
##
## **MASKS `WORLD` ONLY.** Determinism, not performance. Static geometry is
## identical on every peer by construction; NPC and player positions are
## interpolated on clients and authoritative on the server. A probe that could
## hit a moving body would resolve differently on the two machines, and the
## client would predict a vault the server never performed. `TraversalProbes` is
## shared verbatim between `pawn_server.tscn` and `pawn_local.tscn` for the same
## reason (TDD-06 §1.1 rule 1).
##
## The geometry lives in `ProbeLayout`, which is pure. What is left here is the
## engine call and the assembly — the part no unit test can reach anyway.
class_name TraversalProbes
extends Node3D

## Reused across frames. A `PhysicsRayQueryParameters3D` per cast would be six
## allocations per pawn per frame, against a crowd budget measured in NPCs.
var _query := PhysicsRayQueryParameters3D.new()


## Re-cast everything and return the filled result. Also stored on `ctx`, which
## is what `step()` reads; the return value is for callers that want it inline.
##
## Safe with no world — returns a cleared result rather than erroring — so a
## pawn built in a test does not have to fake a physics space.
func refresh(ctx: PawnContext) -> ProbeResult:
	var probe := ctx.probe_result
	probe.clear()
	var space := _space()
	if space == null:
		return probe

	var feet := ctx.position
	var yaw := ctx.yaw
	_cast_forward(space, probe, feet, yaw)
	_cast_obstacle_top(space, probe, feet, yaw)
	_cast_climb_top(space, probe, feet, yaw)
	_cast_gap(space, probe, feet, yaw)
	# LAST. Everything above is a reading; this is the claim that a reading was
	# taken at all, and the resolver refuses to act on a result without it.
	probe.valid = true
	return probe


## The three forward rays. CHEST decides whether a climb is possible, WAIST
## whether a vault or mantle is, and FOOT whether the way ahead is open at all.
func _cast_forward(
	space: PhysicsDirectSpaceState3D, probe: ProbeResult, feet: Vector3, yaw: float
) -> void:
	var chest := _forward_ray(space, feet, yaw, ProbeLayout.Probe.CHEST)
	var waist := _forward_ray(space, feet, yaw, ProbeLayout.Probe.WAIST)
	var foot := _forward_ray(space, feet, yaw, ProbeLayout.Probe.FOOT)

	probe.chest_hit = not chest.is_empty()
	probe.waist_hit = not waist.is_empty()
	probe.foot_clear = foot.is_empty()
	probe.has_hit = probe.chest_hit or probe.waist_hit or not probe.foot_clear

	var nearest: Dictionary = waist if not waist.is_empty() else chest
	if nearest.is_empty():
		nearest = foot
	if not nearest.is_empty():
		var point: Vector3 = nearest["position"]
		probe.distance = Vector2(point.x - feet.x, point.z - feet.z).length()
		probe.height = point.y - feet.y

	if probe.chest_hit:
		probe.normal = chest["normal"]
		probe.surface_is_climbable = ProbeLayout.is_climbable(probe.normal)


## The down-cast beyond a waist hit. **THIS IS THE VAULT/MANTLE DECISION** —
## `obstacle_top` is the number GDD-02 §7.2 compares against 1.1 m and 2.3 m.
##
## The cast starts at mantle height, so an obstacle TALLER than that is a wall
## the ray begins inside. Godot does not report a shape a ray starts within, so
## the ray passes through and hits the floor beyond — and a 4 m façade measures
## an obstacle top of **0.0**, which satisfies `<= 1.1` and turns the tallest
## thing in the district into a vault. The height check below is what rejects it.
func _cast_obstacle_top(
	space: PhysicsDirectSpaceState3D, probe: ProbeResult, feet: Vector3, yaw: float
) -> void:
	if not probe.waist_hit:
		return
	var from := ProbeLayout.obstacle_top_origin(feet, yaw, probe.distance)
	var hit := _ray(space, from, from + Vector3.DOWN * ProbeLayout.gap_depth())
	if not hit.is_empty():
		var top := (hit["position"] as Vector3).y - feet.y
		# A "top" at the pawn's own feet is the FLOOR, seen through a wall the
		# cast started inside. There is no obstacle top here to speak of.
		if top > Tuning.movement.probe_height_foot:
			probe.obstacle_top = top
			probe.height = top
	if probe.obstacle_top == INF:
		return
	_cast_clear_beyond(space, probe, feet, yaw)


## Somewhere to land on the far side. §7.2 case 4 requires it before choosing a
## vault, because a vault with nothing beyond it is a vault into a wall.
##
## Only asked once an obstacle top has been measured: past an unmeasurable wall
## the cast is looking through the wall, and whatever it finds is not a landing.
func _cast_clear_beyond(
	space: PhysicsDirectSpaceState3D, probe: ProbeResult, feet: Vector3, yaw: float
) -> void:
	var beyond := ProbeLayout.clear_beyond_origin(feet, yaw, probe.distance)
	var landing := _ray(space, beyond, beyond + Vector3.DOWN * ProbeLayout.gap_depth())
	if landing.is_empty():
		return
	var drop := feet.y - (landing["position"] as Vector3).y
	probe.clear_beyond = drop <= Tuning.movement.traverse_drop_safe_height


## How tall the climbable façade is, for §7.2 case 6's `<= TUN-TRAVERSE-CLIMB-
## MAX-HEIGHT` test. Cast from that ceiling rather than from mantle height,
## because a façade is by definition taller than anything a mantle can reach.
##
## Only when there is no obstacle top: something with a reachable top is a vault
## or a mantle, and climbing it would be §7.2 choosing its most expensive option
## when a cheaper one applies.
func _cast_climb_top(
	space: PhysicsDirectSpaceState3D, probe: ProbeResult, feet: Vector3, yaw: float
) -> void:
	if not probe.chest_hit or probe.obstacle_top != INF:
		return
	var from := ProbeLayout.climb_top_origin(feet, yaw, probe.distance)
	var hit := _ray(space, from, from + Vector3.DOWN * Tuning.movement.traverse_climb_max_height)
	if hit.is_empty():
		return
	var top := (hit["position"] as Vector3).y - feet.y
	# Same rejection as above: below mantle height it is the floor, not a façade.
	if top > Tuning.movement.traverse_mantle_max_height:
		probe.surface_height = top


## The down-casts marching ahead, which distinguish a **gap** — ground found
## within `TUN-TRAVERSE-GAP-MAX` — from a **drop**, where there is none.
##
## The first offset answers "is there ground immediately ahead"; the rest look
## for the far side. One probe could only ever say "nothing right here", and
## every gap and every drop look identical at 0.6 m.
func _cast_gap(
	space: PhysicsDirectSpaceState3D, probe: ProbeResult, feet: Vector3, yaw: float
) -> void:
	var offsets := ProbeLayout.gap_offsets()
	if offsets.is_empty():
		return
	if _ground_immediately_ahead(space, probe, feet, yaw, offsets[0]):
		return
	# At an edge. Look outward for a far side worth jumping to.
	for i: int in range(1, offsets.size()):
		var drop := _drop_at(space, feet, yaw, offsets[i])
		if drop == INF:
			continue
		if probe.drop_height == INF:
			probe.drop_height = drop
		# A LANDING, not merely ground. Something 6 m down is what you fall to,
		# not what you jump to, and calling it a far side would turn every rooftop
		# edge into a gap jump off the building.
		if absf(drop) <= Tuning.movement.traverse_drop_safe_height:
			probe.gap_distance = offsets[i]
			return


## The edge test. Ground at roughly the pawn's own level immediately ahead means
## there is no edge here at all, and no gap probe further out can change that.
func _ground_immediately_ahead(
	space: PhysicsDirectSpaceState3D, probe: ProbeResult, feet: Vector3, yaw: float, offset: float
) -> bool:
	var drop := _drop_at(space, feet, yaw, offset)
	if drop == INF:
		return false
	if absf(drop) > Tuning.movement.probe_height_foot:
		probe.drop_height = drop
		return false
	probe.ground_ahead = true
	probe.drop_height = 0.0
	return true


## How far below the pawn's feet the ground is at `offset` metres ahead, or `INF`
## when nothing was found within `TUN-TRAVERSE-GAP-PROBE-DEPTH`.
func _drop_at(space: PhysicsDirectSpaceState3D, feet: Vector3, yaw: float, offset: float) -> float:
	var from := ProbeLayout.gap_origin(feet, yaw, offset)
	var hit := _ray(space, from, from + Vector3.DOWN * ProbeLayout.gap_depth())
	return INF if hit.is_empty() else feet.y - (hit["position"] as Vector3).y


func _forward_ray(
	space: PhysicsDirectSpaceState3D, feet: Vector3, yaw: float, probe: ProbeLayout.Probe
) -> Dictionary:
	return _ray(space, ProbeLayout.origin(feet, probe), ProbeLayout.target(feet, yaw, probe))


## One `WORLD`-only ray. The mask is named rather than written as `1`, so
## widening it is a visible edit at `CollisionLayers.TRAVERSAL_MASK`.
func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	_query.from = from
	_query.to = to
	_query.collision_mask = CollisionLayers.TRAVERSAL_MASK
	_query.collide_with_areas = false
	_query.collide_with_bodies = true
	return space.intersect_ray(_query)


func _space() -> PhysicsDirectSpaceState3D:
	var world := get_world_3d()
	return null if world == null else world.direct_space_state
