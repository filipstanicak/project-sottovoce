## Which device may drive the gamepad bindings. GDD-02 §1.3.
##
## **THE CASE THAT MATTERS IS `pedals_only`.** A set of Thrustmaster sim pedals
## enumerates as joypad 0 with its axes resting at −1.0, and with the shipped
## `device: -1` bindings that reads as full stick on three actions forever: the
## pawn walked at stroll and the camera turned without stopping. Every other test
## here exists to keep that one honest.
extends GutTest


func _pad(id: int, known: bool, name: String) -> Dictionary:
	return {"id": id, "known": known, "name": name}


func _pedals() -> Array[Dictionary]:
	return [_pad(0, false, "Thrustmaster Sim Pedals")]


func test_nothing_connected_selects_no_device() -> void:
	var none: Array[Dictionary] = []
	assert_eq(PadSelection.chosen(none), PadSelection.NO_DEVICE)


func test_an_unmapped_device_is_never_chosen() -> void:
	# Not "is scored lower". Never chosen, at any id, alone or in company.
	assert_eq(PadSelection.chosen(_pedals()), PadSelection.NO_DEVICE)


func test_a_mapped_pad_is_chosen_over_an_unmapped_device_at_a_lower_id() -> void:
	# The pedals are device 0 and the pad is device 1, which is the real ordering
	# on the machine this was found on. Choosing "the first joypad" would pick the
	# pedals, so the test asserts the pad by id, not by position in the list.
	var pads: Array[Dictionary] = [
		_pad(0, false, "Thrustmaster Sim Pedals"), _pad(1, true, "Xbox Controller")
	]
	assert_eq(PadSelection.chosen(pads), 1)


func test_the_lowest_mapped_pad_wins() -> void:
	var pads: Array[Dictionary] = [_pad(3, true, "Pad C"), _pad(1, true, "Pad A")]
	assert_eq(PadSelection.chosen(pads), 1)


func test_a_negative_id_is_refused() -> void:
	# −1 is `InputMap`'s "every device" wildcard. If it ever reached `chosen` as a
	# device id it would restore exactly the bug this class exists to prevent.
	var pads: Array[Dictionary] = [_pad(-1, true, "impossible")]
	assert_eq(PadSelection.chosen(pads), PadSelection.NO_DEVICE)


func test_the_sentinel_can_never_match_a_real_device() -> void:
	assert_lt(PadSelection.NO_DEVICE, -1, "the sentinel must be below the wildcard")


func test_everything_not_chosen_is_reported_as_ignored() -> void:
	var pads: Array[Dictionary] = [
		_pad(0, false, "Thrustmaster Sim Pedals"), _pad(1, true, "Xbox Controller")
	]
	var refused := PadSelection.ignored(pads)
	assert_eq(refused.size(), 1)
	assert_eq(String(refused[0]["name"]), "Thrustmaster Sim Pedals")


func test_the_description_names_what_it_ignored() -> void:
	# The whole cost of this bug was that nothing said a device was steering.
	var text := PadSelection.describe(_pedals())
	assert_string_contains(text, "Thrustmaster Sim Pedals")
	assert_string_contains(text, "IGNORING")


func test_the_description_names_the_chosen_pad() -> void:
	var pads: Array[Dictionary] = [_pad(2, true, "Xbox Controller")]
	var text := PadSelection.describe(pads)
	assert_string_contains(text, "Xbox Controller")
	assert_string_contains(text, "2")
