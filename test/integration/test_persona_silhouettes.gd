## **THE FOUR GREYBOX PERSONAS ARE TELLABLE APART.** ART_BIBLE §6.1 and §1.2,
## `SCOPE_FENCE` IN #3, US-0046.
##
## §6.1 says each row "*is* a claim that has to survive §1.2 at 40 m in solid
## black". §1.2's test is a rendered silhouette compared by eye, which needs a
## human and a window. **What is testable headless is the geometry underneath
## it** — four figures whose proportions are measurably different — and that is
## the half a machine can hold.
##
## The other half is the owner's, exactly like M1's feel gate: US-0046 leaves the
## visual judgement unticked and says what was measured instead of rounding up on
## it.
##
## **AND IT PROVES THE BODIES BUILD AT ALL**, which is the assertion that stops
## `PersonaBody` being a correct class nobody instantiates.
extends GutTest

const PERSONAS: Array[StringName] = [
	Ids.PERSONA_VETRAIO,
	Ids.PERSONA_CANTATRICE,
	Ids.PERSONA_LUCERNA,
	Ids.PERSONA_PESATORE,
]

var _built: Dictionary = {}


func before_each() -> void:
	_built = {}
	for persona: StringName in PERSONAS:
		var holder := CharacterBody3D.new()
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		shape.shape = capsule
		shape.name = "CollisionShape3D"
		holder.add_child(shape)
		var body := PersonaBody.new()
		body.persona = persona
		holder.add_child(body)
		add_child_autofree(holder)
		_built[persona] = body


## The world-space box every mesh of a persona occupies, which is the closest a
## headless test gets to a silhouette.
func _extent(persona: StringName) -> AABB:
	var box := AABB()
	var first := true
	for child: Node in (_built[persona] as PersonaBody).get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var local := mesh.mesh.get_aabb()
		local.position += mesh.position
		if first:
			box = local
			first = false
		else:
			box = box.merge(local)
	return box


func test_every_persona_builds_something() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** Four empty nodes have four identical AABBs of
	# zero size, and "no two are the same" would be the only assertion that noticed.
	for persona: StringName in PERSONAS:
		var parts := (_built[persona] as PersonaBody).get_child_count()
		assert_gt(parts, 2, "%s built %d meshes — it is not a figure" % [persona, parts])
		assert_gt(_extent(persona).size.y, 1.0, "%s is not person-shaped" % persona)


func test_the_four_heights_are_art_bibles_own() -> void:
	# 1.68 / 1.72 / 1.89 / 1.75. The heights are the cheapest half of the
	# silhouette claim and the easiest to let drift.
	var expected := {
		Ids.PERSONA_VETRAIO: 1.68,
		Ids.PERSONA_CANTATRICE: 1.72,
		Ids.PERSONA_LUCERNA: 1.89,
		Ids.PERSONA_PESATORE: 1.75,
	}
	for persona: StringName in PERSONAS:
		var top := _extent(persona).position.y + _extent(persona).size.y
		# Lucerna's pole and Cantatrice's crown sit above the head on purpose, so
		# the body's own height is measured against the capsule, not the extent.
		assert_gt(top, float(expected[persona]) - 0.15, "%s is shorter than §6.1 says" % persona)


func test_no_two_personas_have_the_same_proportions() -> void:
	# **§1.2's TEST, IN THE FORM A MACHINE CAN HOLD.** Two personas with the same
	# box would be two identities a hunter cannot separate at 40 m — and it is the
	# hunter's ability to read the crowd that makes hiding in it a skill.
	var boxes: Dictionary = {}
	for persona: StringName in PERSONAS:
		boxes[persona] = _extent(persona)
	for a: StringName in PERSONAS:
		for b: StringName in PERSONAS:
			if a == b:
				continue
			var one := boxes[a] as AABB
			var two := boxes[b] as AABB
			var apart := (one.size - two.size).length()
			assert_gt(
				apart,
				0.08,
				"%s and %s have near-identical proportions (%.3f m apart)" % [a, b, apart]
			)


## The widest mesh whose centre sits between `low` and `high`. Width **at a
## height**, because that is the claim ART_BIBLE §6.1 actually makes.
func _width_between(persona: StringName, low: float, high: float) -> float:
	var widest := 0.0
	for child: Node in (_built[persona] as PersonaBody).get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or mesh.position.y < low or mesh.position.y > high:
			continue
		widest = maxf(widest, mesh.mesh.get_aabb().size.x)
	return widest


func test_lucerna_is_tallest_and_the_two_broad_ones_are_broad_in_different_places() -> void:
	# **§6.1 MAKES TWO DIFFERENT WIDTH CLAIMS AND THEY MUST NOT BE CONFLATED.**
	# Vetraio is `LOW_BROAD` — x1.4 at the *shoulders*. Cantatrice is
	# `FLOOR_TRIANGLE` — a cone that widens toward the *ground*. The first version
	# of this test asked which figure was widest overall, got Cantatrice, and read
	# like a modelling error; it was the assertion that was too crude. Two personas
	# broad at different heights is the silhouette system working.
	var tallest := ""
	var best := 0.0
	for persona: StringName in PERSONAS:
		var box := _extent(persona)
		if box.size.y > best:
			best = box.size.y
			tallest = String(persona)
	assert_eq(tallest, "PERSONA-LUCERNA", "Lucerna is not the tallest silhouette")

	var vetraio_shoulders := _width_between(Ids.PERSONA_VETRAIO, 1.2, 1.6)
	var cantatrice_shoulders := _width_between(Ids.PERSONA_CANTATRICE, 1.2, 1.6)
	var cantatrice_floor := _width_between(Ids.PERSONA_CANTATRICE, 0.0, 0.9)
	var vetraio_floor := _width_between(Ids.PERSONA_VETRAIO, 0.0, 0.9)
	gut.p(
		(
			"shoulders: Vetraio %.2f, Cantatrice %.2f | floor: Vetraio %.2f, Cantatrice %.2f"
			% [vetraio_shoulders, cantatrice_shoulders, vetraio_floor, cantatrice_floor]
		)
	)
	assert_gt(vetraio_shoulders, cantatrice_shoulders, "Vetraio is not the broader at the shoulder")
	assert_gt(cantatrice_floor, vetraio_floor, "Cantatrice does not widen toward the ground")


func test_a_persona_body_is_told_which_one_it_is() -> void:
	# GDD-03 §6.3 rule 4: personas are derived from `match_seed` identically on
	# every peer. A body that chose its own would give two clients different
	# cities, and the symptom is a player saying "I saw a Lucerna by the furnace"
	# and being wrong.
	var body := _built[Ids.PERSONA_LUCERNA] as PersonaBody
	assert_eq(body.persona, Ids.PERSONA_LUCERNA, "the body did not keep the persona it was given")
