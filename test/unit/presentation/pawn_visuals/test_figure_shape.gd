## **TEN SHAPES, AND WHAT EACH MAY AND MAY NOT BE.** ART_BIBLE §1 and §5, US-0109.
extends GutTest

## How near a persona's hue a filler's cloth may come before it must be greyer.
const HUE_TOLERANCE := 18.0
const SATURATION_SHARE := 0.75


func _everyone() -> Array[StringName]:
	var out: Array[StringName] = [&""]
	out.append_array(CrowdRoster.PLAYABLE)
	out.append_array(CrowdRoster.ARCHETYPES)
	return out


func _body(id: StringName) -> PersonaBody:
	var body := PersonaBody.new()
	body.persona = id
	add_child_autofree(body)
	return body


func test_a_personas_height_and_width_are_the_data_files_own() -> void:
	for persona: StringName in CrowdRoster.PLAYABLE:
		var data := FigureShape.persona_data(persona)
		assert_not_null(data, "%s has no data to be built from" % persona)
		var shape := FigureShape.of(persona, 1.8)
		assert_eq(shape.height, data.stand_height)
		assert_eq(shape.shoulders, data.width_scale)


func test_every_filler_has_a_shape_of_its_own() -> void:
	for id: StringName in CrowdRoster.ARCHETYPES:
		assert_true(FigureShape.FILLERS.has(id), "%s has no shape" % id)
		assert_eq(FigureShape.of(id, 1.8).id, id)
		assert_null(FigureShape.persona_data(id), "a filler was read as a persona")


func test_anything_else_is_the_undressed_figure_at_the_colliders_height() -> void:
	var shape := FigureShape.of(&"PERSONA-NOBODY", 1.8)
	assert_eq(shape.id, &"")
	assert_eq(shape.height, 1.8)


func test_a_figure_is_as_tall_as_its_shape_says() -> void:
	# Head to foot, before whatever it wears or carries above its head.
	for id: StringName in _everyone():
		var body := _body(id)
		var head := body.box_of(body.part("Head"))
		if body.rig().shape.stoop > 0.0:
			# A stooped figure stands no taller than it measures.
			assert_lt(head.end.y, body.rig().shape.height + 0.02, "%s head" % id)
		else:
			assert_almost_eq(head.end.y, body.rig().shape.height, 0.01, "%s head" % id)
		assert_almost_eq(body.box_of(body.part("Foot")).position.y, 0.0, 0.01, "%s feet" % id)


func test_only_the_lucerna_breaks_the_head_line() -> void:
	# §1.1: the pole is the most readable feature in the cast, because nothing else
	# in the district stands above a head. A filler that did would spend it.
	for id: StringName in _everyone():
		var body := _body(id)
		var over := body.bounds().end.y - body.rig().shape.height
		if id == Ids.PERSONA_LUCERNA:
			assert_gt(over, 0.8, "the pole does not clear the Lucerna's head")
		else:
			assert_lt(over, 0.35, "%s stands %.2f m above its own head" % [id, over])


func test_the_child_is_shorter_than_anything_a_player_can_be() -> void:
	# §1.3: the negative silhouette, so the eye checks size before shape.
	var child := FigureShape.of(Ids.ARCH_CHILD, 1.8).height
	for persona: StringName in CrowdRoster.PLAYABLE:
		assert_lt(child, FigureShape.of(persona, 1.8).height * 0.8)


func test_no_filler_is_dressed_in_a_personas_hue() -> void:
	var palette := Palette.fallback()
	for id: StringName in CrowdRoster.ARCHETYPES:
		var cloth := FigureTrades.cloth_of(id)
		for persona: StringName in CrowdRoster.PLAYABLE:
			var hue := palette.for_persona(persona)
			var apart := absf(angle_difference(cloth.h * TAU, hue.h * TAU)) * 360.0 / TAU
			assert_false(
				apart < HUE_TOLERANCE and cloth.s > hue.s * SATURATION_SHARE,
				"%s wears something a %s could be taken for" % [id, persona]
			)


func test_a_filler_is_a_filler_and_not_a_persona() -> void:
	var body := _body(Ids.ARCH_PORTER)
	assert_true(body.is_filler())
	assert_false(body.is_dressed(), "a porter reads as a persona")
	assert_eq(body.cloth(), FigureTrades.cloth_of(Ids.ARCH_PORTER))
	assert_not_null(body.part("Crate"))


func test_every_figure_is_inside_the_art_bibles_triangle_budget() -> void:
	# §5: a persona is 8 000 triangles, a filler 6 000, ninety on screen at once.
	for id: StringName in _everyone():
		var triangles := 0
		for piece: MeshInstance3D in _body(id).parts():
			triangles += piece.mesh.get_faces().size() / 3
		gut.p("%s: %d triangles" % [id if id != &"" else &"undressed", triangles])
		assert_between(triangles, 500, 6000, "%s" % id)


func test_two_figures_of_one_kind_share_every_mesh_and_every_paint() -> void:
	# Ninety figures are drawn as a few dozen shapes only if they really are the
	# same shapes: one mesh a shape and one material a colour, for all of them.
	var one := _body(Ids.PERSONA_PESATORE).parts()
	var other := _body(Ids.PERSONA_PESATORE).parts()
	assert_eq(one.size(), other.size())
	for i: int in one.size():
		assert_same(one[i].mesh, other[i].mesh, "%s is built twice" % one[i].name)
		assert_same(one[i].material_override, other[i].material_override)


func test_greying_one_figure_leaves_its_twin_alone() -> void:
	# Shared paints, so greying must hand a part another one rather than tint it.
	var blended := _body(Ids.PERSONA_LUCERNA)
	var twin := _body(Ids.PERSONA_LUCERNA)
	var before := twin.colour_of("Body")
	blended.set_greyed(true)
	assert_ne(blended.colour_of("Body"), before)
	assert_eq(twin.colour_of("Body"), before, "greying one Lucerna greyed another")


func test_a_skirt_is_the_cantatrices_and_the_fishwifes() -> void:
	for id: StringName in _everyone():
		var skirted := id == Ids.PERSONA_CANTATRICE or id == Ids.ARCH_FISHWIFE
		assert_eq(_body(id).part("Skirt") != null, skirted, "%s" % id)
