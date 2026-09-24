## **`CrowdRoster.PLAYABLE`'s ORDER IS A PROTOCOL NOW, AND IT IS APPEND-ONLY.**
## US-0100, ADR-0021.
##
## That array already decided every roster every seed produces — its own docstring
## says reordering it *"would silently invalidate every recorded playtest"*. Since
## `NET-S2C-CONTRACT-ASSIGNED` carries the index, reordering it now also makes
## every live client draw the wrong face. Same hazard as `PawnStateId.ALL`, and
## guarded the same way: the names are pinned in order, so an **insertion** fails
## rather than an append.
extends GutTest

## The wire order as it was frozen. Appending is fine; anything else is a break.
const FROZEN: Array[StringName] = [
	&"PERSONA-CANTATRICE",
	&"PERSONA-LUCERNA",
	&"PERSONA-PESATORE",
	&"PERSONA-VETRAIO",
]


func test_the_playable_order_is_append_only() -> void:
	assert_true(
		CrowdRoster.PLAYABLE.size() >= FROZEN.size(), "a persona was removed from the wire order"
	)
	for index: int in FROZEN.size():
		assert_eq(
			CrowdRoster.PLAYABLE[index],
			FROZEN[index],
			"wire index %d changed meaning: every live client would draw the wrong face" % index
		)


func test_every_playable_persona_round_trips() -> void:
	for persona: StringName in CrowdRoster.PLAYABLE:
		var encoded := PersonaWire.to_u8(persona)
		assert_ne(encoded, PersonaWire.NONE, "%s does not encode" % persona)
		assert_eq(
			PersonaWire.from_u8(encoded), persona, "%s did not survive the round trip" % persona
		)


## **`NONE` IS A READING, NOT AN ERROR.** Nobody has a persona before the
## countdown deals one, and the honest answer is an absence the client draws as
## unknown — the Compass bearing's `NO_CONTRACT` rule, one message over.
func test_no_persona_encodes_and_decodes_as_nothing() -> void:
	assert_eq(PersonaWire.to_u8(&""), PersonaWire.NONE, "an empty persona invented an index")
	assert_eq(PersonaWire.from_u8(PersonaWire.NONE), &"", "NONE decoded to a persona")


## A client one build behind reads an index it does not have. It must draw
## unknown rather than a plausible wrong face.
func test_an_unresolvable_index_is_unknown_rather_than_a_guess() -> void:
	for value: int in [-1, CrowdRoster.PLAYABLE.size(), 200, PersonaWire.NONE]:
		assert_eq(PersonaWire.from_u8(value), &"", "index %d was resolved to a face" % value)


func test_an_unknown_name_does_not_encode_as_a_real_persona() -> void:
	assert_eq(PersonaWire.to_u8(&"PERSONA-NOBODY"), PersonaWire.NONE)


## The sentinel must stay outside the index space, or a future persona would
## silently mean "none" to every client that already shipped.
func test_the_sentinel_cannot_collide_with_an_index() -> void:
	assert_gt(
		PersonaWire.NONE,
		CrowdRoster.PLAYABLE.size() - 1,
		"the playable set has grown into the NONE sentinel"
	)
