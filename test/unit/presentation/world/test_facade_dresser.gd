## **A BOX BECOMES A BUILDING, IN THE GAME'S OWN STRATA.** ADR-0026, ART_BIBLE §4.
extends GutTest

var _map: Node3D
var _survey: DressingSurvey
var _batch: MeshBatch
var _palette: WorldPalette


func before_each() -> void:
	_map = (load(MapCatalogue.client_scene("vetraio")) as PackedScene).instantiate()
	add_child_autofree(_map)
	_survey = DressingSurvey.new(_map)
	_batch = MeshBatch.new()
	_palette = WorldPalette.new()
	FacadeDresser.new(_survey, _batch, WorldMaterials.new(_palette), _palette).dress()


func _block(name: String) -> DressingSurvey.Part:
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.BLOCK):
		if part.name == name:
			return part
	return null


func test_a_climbable_facade_is_coursed_stone_and_every_other_wall_is_plaster() -> void:
	# The climbing language the greybox spoke in blue: stone you can climb,
	# plaster you cannot.
	var materials := {}
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.BLOCK):
		var material := part.mesh.material_override as ShaderMaterial
		var kind: int = material.get_shader_parameter(&"kind")
		var wanted := WorldMaterials.Kind.COURSED if part.climbable else WorldMaterials.Kind.PLASTER
		assert_eq(kind, wanted, part.name)
		materials[kind] = material
	assert_eq(materials.size(), 2, "every wall shares one of two materials")


func test_a_building_keeps_its_own_plaster() -> void:
	var house := _block("LoggiaPier")
	var tint: Color = house.mesh.get_instance_shader_parameter(&"tint")
	assert_true(_palette.plasters.has(tint))
	var again := FacadeDresser.new(_survey, MeshBatch.new(), WorldMaterials.new(_palette), _palette)
	assert_eq(again.plaster_of(house), tint)


func test_the_four_faces_look_outward() -> void:
	var house := _block("LoggiaPier")
	var middle := Vector3(house.centre.x, 0.0, house.centre.z)
	for face: FacadeDresser.Face in FacadeDresser.faces_of(house):
		var on_wall := face.at(face.width * 0.5, 0.0)
		assert_gt(face.normal.dot(on_wall - middle), 0.0, "a face looks into its own block")
		assert_almost_eq(face.along.dot(face.normal), 0.0, 0.001)


func test_windows_start_above_the_balcony_line() -> void:
	var lowest := INF
	for vertex: Vector3 in _batch.vertices_of(WorldMaterials.GLASS):
		lowest = minf(lowest, vertex.y)
	# The lanterns hang at 3 m; every window is above the string course.
	assert_gt(lowest, FacadeDresser.LANTERN_Y - 0.2)


func test_a_garden_wall_gets_a_coping_and_no_windows() -> void:
	var wall := _block("MercatoNorthWall")
	assert_lt(wall.top(), FacadeDresser.WALL_HEIGHT)
	var grown := wall.rect().grow(0.5)
	# The house beside it has windows over the wall; the wall itself has none.
	for vertex: Vector3 in _batch.vertices_of(WorldMaterials.GLASS):
		if grown.has_point(Vector2(vertex.x, vertex.z)):
			assert_gt(vertex.y, wall.top() + 1.0, "a window in a garden wall")
	var capped := false
	for vertex: Vector3 in _batch.vertices_of(WorldMaterials.STONE):
		if grown.has_point(Vector2(vertex.x, vertex.z)) and is_equal_approx(vertex.y, wall.top()):
			capped = true
	assert_true(capped, "the wall has no coping")


func test_only_the_bell_tower_has_a_roof_with_a_shape() -> void:
	var tower := _block("Campanile")
	var peak := 0.0
	for vertex: Vector3 in _batch.vertices_of(WorldMaterials.ROOF):
		if vertex.y > tower.top() + 0.01:
			assert_true(tower.rect().grow(1.0).has_point(Vector2(vertex.x, vertex.z)))
			peak = maxf(peak, vertex.y)
	assert_gt(peak, tower.top() + 2.0, "the bell tower has no roof")


func test_no_facade_is_dressed_where_another_block_stands_against_it() -> void:
	# The bell tower's faces below its block's roof are inside the block.
	var tower := _block("Campanile")
	var inside := tower.rect().grow(0.4)
	for key: StringName in [WorldMaterials.GLASS, WorldMaterials.TIMBER]:
		for vertex: Vector3 in _batch.vertices_of(key):
			if inside.has_point(Vector2(vertex.x, vertex.z)):
				assert_gt(vertex.y, 8.5, "%s built inside the block under the tower" % key)
