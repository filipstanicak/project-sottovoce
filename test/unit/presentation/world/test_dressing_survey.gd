## **THE SURVEY READS BACK EXACTLY WHAT THE GENERATOR BUILT.** ADR-0026.
##
## The art pass dresses whatever the survey says is there. A stall read as a
## parapet gets no awning; a floor read as a block gets windows.
extends GutTest

var _survey: DressingSurvey


func before_all() -> void:
	var map: Node3D = (load(MapCatalogue.client_scene("vetraio")) as PackedScene).instantiate()
	add_child(map)
	_survey = DressingSurvey.new(map)
	map.queue_free()


func test_every_solid_of_the_layout_is_found_in_its_role() -> void:
	assert_eq(_survey.of(DressingSurvey.Role.FLOOR).size(), VetraioLayout.FLOORS.size())
	assert_eq(_survey.of(DressingSurvey.Role.BLOCK).size(), VetraioLayout.BLOCKS.size())
	assert_eq(_survey.of(DressingSurvey.Role.STALL).size(), VetraioLayout.STALLS.size())
	assert_eq(_survey.of(DressingSurvey.Role.PROP).size(), VetraioLayout.BLEND_PROPS.size())
	assert_eq(_survey.of(DressingSurvey.Role.BENCH).size(), VetraioLayout.BENCHES.size())
	assert_eq(_survey.of(DressingSurvey.Role.PARAPET).size(), VetraioGround.parapets().size())


func test_a_block_is_where_the_layout_put_it() -> void:
	for row: Array in VetraioLayout.BLOCKS:
		var part := _named(str(row[0]))
		assert_not_null(part, "%s was not surveyed" % row[0])
		assert_eq(part.rect(), Rect2(row[1], row[2], row[3], row[4]), str(row[0]))
		assert_almost_eq(part.top(), float(row[5]), 0.001)
		assert_eq(part.climbable, row[6] == "MAT-CLIMB", "%s climbability" % row[0])


func _named(name: String) -> DressingSurvey.Part:
	for part: DressingSurvey.Part in _survey.parts:
		if part.name == name:
			return part
	return null


func test_ground_is_the_street_and_not_the_balcony_or_the_canal() -> void:
	assert_true(_survey.ground_at(Vector2(60, 15)), "the piazza")
	assert_false(_survey.ground_at(Vector2(60, 33)), "the canal between piazza and Loggia")
	assert_false(_survey.ground_at(Vector2(60, 94)), "the Fondaco canal")
	assert_false(_survey.ground_at(Vector2(-5, 50)), "the lagoon")


func test_a_block_standing_on_another_is_seen_over_it() -> void:
	# The bell tower rises out of its block: its faces are hidden up to 8.5 m.
	var tower := _named("Campanile")
	assert_almost_eq(_survey.block_top_at(Vector2(104, 7.7), tower), 8.5, 0.001)
	assert_almost_eq(_survey.block_top_at(Vector2(60, 15), null), 0.0, 0.001)


func test_the_bounds_are_the_district() -> void:
	var bounds := _survey.bounds()
	assert_almost_eq(bounds.get_center(), Vector2(60, 60), Vector2.ONE * 1.0)
	assert_gt(bounds.size.x, VetraioLayout.MAP_SIZE - 0.1)


func test_a_map_with_no_geometry_surveys_as_empty() -> void:
	var bare := Node3D.new()
	add_child_autofree(bare)
	assert_eq(DressingSurvey.new(bare).parts.size(), 0)
	assert_eq(DressingSurvey.new(null).parts.size(), 0)
