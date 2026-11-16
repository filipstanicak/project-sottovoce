## **A PERSONA IS A SHAPE AND A COLOUR, AND A CLONE WEARS BOTH EXACTLY.** US-0101.
##
## ART_BIBLE §3 reserves four identity hues and `data/personas/*.tres` has held them
## since US-0046, read by nothing. The clothing wears them now; the props keep the
## neutral values, so the pole, the crown and the ledger still read as objects.
extends GutTest


func _body(persona: StringName) -> PersonaBody:
	var body := PersonaBody.new()
	body.persona = persona
	add_child_autofree(body)
	return body


func _albedo(body: PersonaBody, part: String) -> Color:
	return body.colour_of(part)


## `[name, colour]` of every part, in the order the body was built.
func _paint(body: PersonaBody) -> Array:
	var out: Array = []
	for piece: MeshInstance3D in body.parts():
		out.append([String(piece.name), body.colour_of(String(piece.name))])
	return out


func test_the_clothing_wears_the_identity_hue_from_the_resource() -> void:
	for persona: StringName in CrowdRoster.PLAYABLE:
		var slug := String(persona).trim_prefix("PERSONA-").to_lower()
		var data := load("res://data/personas/%s.tres" % slug) as PersonaData
		assert_not_null(data, "%s has no resource to read a hue from" % persona)
		assert_eq(
			_albedo(_body(persona), "Body"),
			data.identity_hue,
			"%s is not wearing its own identity hue" % persona
		)


func test_the_four_hues_are_four() -> void:
	var seen: Dictionary = {}
	for persona: StringName in CrowdRoster.PLAYABLE:
		seen[Palette.authored_hue(persona)] = persona
	assert_eq(seen.size(), 4, "two personas share a colour, so colour tells them apart less")


func test_an_undressed_body_is_neutral_all_over() -> void:
	var body := _body(&"")
	assert_false(body.is_dressed(), "an empty persona reads as dressed")
	assert_gt(body.parts().size(), 10, "the undressed figure is not a figure")
	for piece: MeshInstance3D in body.parts():
		var colour := (piece.material_override as StandardMaterial3D).albedo_color
		assert_true(
			colour == PersonaBody.BODY_COLOUR or colour == PersonaBody.MARKER_COLOUR,
			"undressed part %s carries a colour" % piece.name
		)


func test_dressing_rebuilds_in_place() -> void:
	var body := _body(&"")
	assert_null(body.part("Pole"), "an undressed figure carries the pole")
	assert_true(body.dress(Ids.PERSONA_LUCERNA), "dressing reported nothing changed")
	await wait_physics_frames(1)
	assert_not_null(body.part("Pole"), "the Lucerna has no pole after dressing")
	assert_eq(_albedo(body, "Body"), Palette.authored_hue(Ids.PERSONA_LUCERNA), "wrong colour")


func test_dressing_as_the_same_persona_changes_nothing() -> void:
	var body := _body(Ids.PERSONA_PESATORE)
	var before := body.get_child(0)
	assert_false(body.dress(Ids.PERSONA_PESATORE), "an unchanged persona rebuilt the body")
	assert_eq(body.get_child(0), before, "the body was rebuilt anyway")


## **THE CLONE AND THE PLAYER ARE ONE CLASS.** A player's body and an NPC's are
## built by the same code from the same persona, so any colour one has, the other
## has — which is rule 6 kept by construction rather than by a comparison.
func test_a_clone_and_a_player_of_one_persona_are_identical() -> void:
	var player := _body(Ids.PERSONA_VETRAIO)
	var clone := _body(Ids.PERSONA_VETRAIO)
	assert_gt(_paint(player).size(), 12, "a Vetraio of a dozen parts or fewer is not one")
	assert_eq(_paint(player), _paint(clone), "two bodies of one persona differ in a part")
	for i: int in player.parts().size():
		assert_same(
			player.parts()[i].mesh,
			clone.parts()[i].mesh,
			"two bodies of one persona differ in shape"
		)


## **GREYED FOR THE BLENDER, AND EVERY PART GIVEN BACK ITS OWN COLOUR** (US-0107).
func test_a_greyed_body_is_grey_and_returns_to_its_colours() -> void:
	var body := _body(Ids.PERSONA_LUCERNA)
	var before: Dictionary = {}
	for piece: MeshInstance3D in body.parts():
		before[String(piece.name)] = _albedo(body, String(piece.name))
	body.set_greyed(true)
	var hue: Color = before["Body"]
	var greyed := _albedo(body, "Body")
	assert_ne(greyed, hue, "nothing was greyed")
	assert_lt(greyed.s, hue.s, "greyed means less colour, not another colour")
	body.set_greyed(false)
	for part: String in before:
		assert_eq(_albedo(body, part), before[part], "%s did not get its colour back" % part)


func test_a_body_redressed_while_greyed_stays_greyed() -> void:
	var body := _body(&"")
	body.set_greyed(true)
	body.dress(Ids.PERSONA_VETRAIO)
	assert_true(body.is_greyed())
	assert_ne(_albedo(body, "Body"), body.cloth(), "the new clothes came out in full colour")
