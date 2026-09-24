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
	var mesh := body.get_node(part) as MeshInstance3D
	return (mesh.mesh.material as StandardMaterial3D).albedo_color


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
		seen[PersonaBody.hue_of(persona)] = persona
	assert_eq(seen.size(), 4, "two personas share a colour, so colour tells them apart less")


func test_an_undressed_body_is_neutral_all_over() -> void:
	var body := _body(&"")
	assert_false(body.is_dressed(), "an empty persona reads as dressed")
	for child: Node in body.get_children():
		var colour := ((child as MeshInstance3D).mesh.material as StandardMaterial3D).albedo_color
		assert_true(
			colour == PersonaBody.BODY_COLOUR or colour == PersonaBody.MARKER_COLOUR,
			"undressed part %s carries a colour" % child.name
		)


func test_dressing_rebuilds_in_place() -> void:
	var body := _body(&"")
	assert_null(body.get_node_or_null("Pole"), "an undressed figure carries the pole")
	assert_true(body.dress(Ids.PERSONA_LUCERNA), "dressing reported nothing changed")
	await wait_physics_frames(1)
	assert_not_null(body.get_node_or_null("Pole"), "the Lucerna has no pole after dressing")
	assert_eq(_albedo(body, "Body"), PersonaBody.hue_of(Ids.PERSONA_LUCERNA), "wrong colour")


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
	assert_eq(player.get_child_count(), clone.get_child_count(), "different part counts")
	for i: int in player.get_child_count():
		assert_eq(
			_albedo(player, player.get_child(i).name),
			_albedo(clone, clone.get_child(i).name),
			"part %s differs between two bodies of one persona" % player.get_child(i).name
		)
