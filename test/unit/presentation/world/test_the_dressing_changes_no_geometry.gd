## **THE ART PASS CHANGES HOW THE DISTRICT LOOKS AND NOTHING ELSE.** ADR-0026.
##
## ART_BIBLE §7.1 lists what art may not change: every traversable height, every
## navmesh boundary, every sightline and width. The dressing keeps all of them the
## only way that cannot go wrong — it adds no collider and moves no box — and this
## holds it to that on both maps.
extends GutTest

const MAPS: Array[String] = ["vetraio", "sandbox"]

var _map: Node3D
var _dressing: DistrictDressing


func _dress(map: String) -> void:
	_map = (load(MapCatalogue.client_scene(map)) as PackedScene).instantiate()
	add_child_autofree(_map)
	_dressing = DistrictDressing.new()
	add_child_autofree(_dressing)


## `{path: [position, shape size]}` of every solid in the map.
func _solids() -> Dictionary:
	var out := {}
	for body: Node in _map.get_node("Geometry").get_children():
		var shape := body.get_node_or_null("Collision") as CollisionShape3D
		if shape != null:
			out[str(body.name)] = [(body as Node3D).position, (shape.shape as BoxShape3D).size]
	return out


func _count(root: Node, type: Variant) -> int:
	var total := 1 if is_instance_of(root, type) else 0
	for child: Node in root.get_children():
		total += _count(child, type)
	return total


func test_no_solid_is_moved_resized_added_or_removed() -> void:
	for map: String in MAPS:
		_dress(map)
		var before := _solids()
		var bodies := _count(_map, CollisionObject3D)
		var obstacles := _count(_map, NavigationObstacle3D)
		_dressing.dress(_map)
		assert_eq(_solids(), before, "%s: the dressing moved or resized a solid" % map)
		assert_eq(_count(_map, CollisionObject3D), bodies, "%s: a collider was added" % map)
		assert_eq(_count(_map, NavigationObstacle3D), obstacles)


func test_the_dressing_itself_holds_nothing_solid() -> void:
	for map: String in MAPS:
		_dress(map)
		_dressing.dress(_map)
		assert_gt(_dressing.triangles, 1000, "%s was not dressed at all" % map)
		assert_eq(_count(_dressing, CollisionObject3D), 0)
		assert_eq(_count(_dressing, CollisionShape3D), 0)
		assert_eq(_count(_dressing, NavigationRegion3D), 0)
		assert_eq(_count(_dressing, NavigationObstacle3D), 0)


func test_every_greybox_material_is_replaced() -> void:
	# A solid left in its greybox paint is a blue or yellow box in a plaster town.
	_dress("vetraio")
	_dressing.dress(_map)
	var left: PackedStringArray = []
	for body: Node in _map.get_node("Geometry").get_children():
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh != null and not mesh.material_override is ShaderMaterial:
			left.append(str(body.name))
	assert_eq(left.size(), 0, "still in greybox paint: %s" % ", ".join(left))


func test_the_same_district_is_built_every_time() -> void:
	# Two players describing a building to each other describe the same one.
	var seen: Array = []
	for _i: int in 2:
		_dress("vetraio")
		var palette := WorldPalette.new()
		var batch := DistrictDressing.detail_of(
			DressingSurvey.new(_map), WorldMaterials.new(palette), palette, _dressing
		)
		var keys := batch.keys()
		keys.sort()
		var sizes := []
		for key: StringName in keys:
			sizes.append([key, hash(batch.vertices_of(key))])
		seen.append(sizes)
	assert_eq(seen[0], seen[1])


func test_it_stays_inside_the_triangle_budget() -> void:
	# ART_BIBLE §5: a building module is 3 000 triangles, a prop 800.
	_dress("vetraio")
	_dressing.dress(_map)
	var survey := DressingSurvey.new(_map)
	var blocks := survey.of(DressingSurvey.Role.BLOCK).size()
	var props := survey.parts.size() - blocks
	assert_lt(_dressing.triangles, blocks * 3000 + props * 800)
