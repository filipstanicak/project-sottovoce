## **THE `MapData` HALF OF THE MAP GENERATOR.** GDD-05, US-0054. BUILD-TIME ONLY;
## nothing in a running game loads this file.
##
## **SPLIT OUT OF `generate_map_vetraio.gd` BECAUSE THAT FILE WAS AT 399 OF ITS
## 400 LINES**, and had been for several stories. The seam is the honest one: the
## generator writes **two artefacts** — a pair of scenes with a baked navmesh, and
## a resource the systems read — and only the second is what any rule is written
## against. Everything here is pure data derivation from `VetraioLayout`, with no
## node, no scene and no bake.
##
## **TRAP 1 STILL APPLIES.** `map_vetraio.tres` is generated; hand-edits are
## silently reverted on the next run. Change the layout table, not the resource.
class_name MapDataBuilder
extends RefCounted


static func build() -> MapData:
	var data := MapData.new()
	data.id = &"MAP-VETRAIO"
	data.display_key = &"ui.map.vetraio"
	data.bounds = AABB(Vector3.ZERO, Vector3(VetraioLayout.MAP_SIZE, 24.0, VetraioLayout.MAP_SIZE))

	for s: Array in VetraioLayout.SPAWNS:
		data.spawn_points.append(Vector3(s[1], 0.0, s[2]))

	for c: Array in VetraioLayout.CIRCUITS:
		var points := PackedVector3Array()
		for p: Vector2 in c[2]:
			points.append(Vector3(p.x, 0.0, p.y))
		data.circuits.append(points)
		data.circuit_periods.append(c[1])

	_fill_places(data)
	data.idle_anchors = _place_anchors(data.zones)
	data.navmesh_exclusions = _navmesh_exclusions()
	return data


## Zones, hiding spots, lean spots and theatres — everything that is a *place*
## rather than a route or a boundary.
static func _fill_places(data: MapData) -> void:
	for z: Array in VetraioLayout.ZONES:
		var zone := MapZone.new()
		zone.zone_name = StringName(z[0])
		zone.bounds = AABB(Vector3(z[1], 0.0, z[2]), Vector3(z[3], 4.0, z[4]))
		zone.density = z[5]
		zone.is_theatre = z[6]
		data.zones.append(zone)
	for p: Array in VetraioLayout.BLEND_PROPS:
		data.blend_props.append(Vector3(p[1], 0.0, p[2]))
	# **DERIVED, NOT LISTED** (US-0054): two lean spots per market stall.
	for p: Array in VetraioGround.stall_lean_points():
		data.static_props.append(Vector3(p[1], VetraioLayout.STREET_Y, p[2]))
	for t: Array in VetraioLayout.THEATRES:
		data.theatre_spaces.append(AABB(Vector3(t[1], 0.0, t[2]), Vector3(t[3], 6.0, t[4])))


## Idle anchors per zone at GDD-05 §4.4's density; a theatre gets none.
## **A ZONE THINNER THAN ITS CELL GOT NOTHING, SILENTLY** — `Fondaco`, 120 x 3 m at
## 8.49 spacing began its row past its own end, so the district's northern street
## had no crowd (US-0096). One row down the middle now, at the declared count; the
## square pitch, which makes a DENSE zone a blend pocket, is kept where a cell fits.
static func _place_anchors(zones: Array[MapZone]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for zone: MapZone in zones:
		if zone.is_theatre:
			continue
		var wanted := zone.expected_anchors()
		if wanted <= 0:
			continue
		var span := Vector2(zone.bounds.size.x, zone.bounds.size.z)
		var spacing := sqrt((span.x * span.y) / float(wanted))
		var thin := span.y < spacing
		var step := Vector2(span.x / float(wanted), span.y) if thin else Vector2(spacing, spacing)
		var x := zone.bounds.position.x + minf(step.x, span.x) * 0.5
		while x < zone.bounds.end.x:
			var z := zone.bounds.position.z + minf(step.y, span.y) * 0.5
			while z < zone.bounds.end.z:
				out.append(VetraioGround.clear_of_obstacles(Vector2(x, z)))
				z += step.y
			x += step.x
	return out


## Roofs, balconies and the canal. NPCs must never reach them — that is exactly
## why standing there costs suspicion (GDD-05 §4.4).
static func _navmesh_exclusions() -> Array[AABB]:
	var out: Array[AABB] = []
	out.append(
		AABB(
			Vector3(VetraioLayout.CANAL.position.x, -2.0, VetraioLayout.CANAL.position.y),
			Vector3(VetraioLayout.CANAL.size.x, 4.0, VetraioLayout.CANAL.size.y)
		)
	)
	out.append(
		AABB(
			Vector3(0.0, VetraioLayout.BALCONY_Y - 0.5, 0.0),
			Vector3(VetraioLayout.MAP_SIZE, 24.0, VetraioLayout.MAP_SIZE)
		)
	)
	return out
