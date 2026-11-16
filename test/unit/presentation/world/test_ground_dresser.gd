## **THE GROUND IS PAVED BY WHAT IT IS, AND STANDS ON SOMETHING.** ADR-0026.
extends GutTest

var _map: Node3D
var _survey: DressingSurvey
var _batch: MeshBatch
var _host: Node3D


func before_each() -> void:
	_map = (load(MapCatalogue.client_scene("vetraio")) as PackedScene).instantiate()
	add_child_autofree(_map)
	_host = Node3D.new()
	add_child_autofree(_host)
	_survey = DressingSurvey.new(_map)
	_batch = MeshBatch.new()
	var palette := WorldPalette.new()
	GroundDresser.new(_survey, _batch, WorldMaterials.new(palette), palette).dress(_host)


func _floor(name: String) -> DressingSurvey.Part:
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.FLOOR):
		if part.name == name:
			return part
	return null


func test_a_square_is_paved_a_street_is_setts_and_the_balcony_is_boards() -> void:
	assert_eq(GroundDresser.pattern_of(_floor("PiazzaDelVetro")), WorldMaterials.PAVING)
	assert_eq(GroundDresser.pattern_of(_floor("FondacoStreet")), WorldMaterials.SETTS)
	assert_eq(GroundDresser.pattern_of(_floor("LoggiaBalcony")), WorldMaterials.BOARDS)


func test_the_three_narrow_crossings_are_the_bridges() -> void:
	var bridges: Array[String] = []
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.FLOOR):
		if GroundDresser.is_bridge(part):
			bridges.append(part.name)
	bridges.sort()
	assert_eq(bridges, ["MouthEast", "MouthWest", "PonteCorto"])


func test_every_floor_is_laid_in_the_ground_material() -> void:
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.FLOOR):
		var material := part.mesh.material_override as ShaderMaterial
		assert_not_null(material, "%s kept its greybox paint" % part.name)
		assert_eq(
			part.mesh.get_instance_shader_parameter(&"pattern"), GroundDresser.pattern_of(part)
		)


func test_one_sheet_of_water_lies_under_the_district() -> void:
	var water := _host.get_node_or_null("Water") as MeshInstance3D
	assert_not_null(water)
	assert_almost_eq(water.position.y, GroundDresser.WATER_Y, 0.001)
	assert_gt((water.mesh as PlaneMesh).size.x, VetraioLayout.MAP_SIZE * 4.0)
	assert_eq(water.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_the_quays_reach_below_the_water() -> void:
	var lowest := INF
	for vertex: Vector3 in _batch.vertices_of(WorldMaterials.STONE):
		lowest = minf(lowest, vertex.y)
	assert_lt(lowest, GroundDresser.WATER_Y - 0.5, "a gap shows between quay and water")


func test_the_balcony_stands_on_posts_over_the_canal_and_none_in_the_loggia() -> void:
	# A post is drawn only where a pawn cannot reach: outside the Loggia's own
	# north edge, on the parapet line.
	var balcony := _floor("LoggiaBalcony")
	var north_edge := balcony.rect().position.y
	var posts := 0
	for vertex: Vector3 in _batch.vertices_of(WorldMaterials.TIMBER):
		if vertex.y < 1.0:
			posts += 1
			assert_lt(vertex.z, north_edge + GroundDresser.POST + 0.01, "a post in the walkway")
	assert_gt(posts, 0, "the balcony hangs in the air")
