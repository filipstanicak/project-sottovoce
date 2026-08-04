## The string table loads, resolves, and fails visibly.
extends GutTest


func test_the_table_loaded() -> void:
	assert_gt(Strings.count(), 20, "the string table did not load")


func test_a_known_key_resolves_to_its_text() -> void:
	assert_eq(Strings.get_text(&"ability.cinderfall.name"), "Cinderfall")
	assert_eq(Strings.get_text(&"ui.tier.exposed"), "Exposed")


func test_a_missing_key_returns_the_key_itself() -> void:
	# Loudly, and visibly IN GAME. Returning "" would render as empty space,
	# which is invisible in a screenshot and therefore never reported.
	var key := &"ui.definitely.not.present"
	assert_eq(Strings.get_text(key), String(key), "a miss must return the key")
	assert_push_error_count(1, "a missing key must be logged, not swallowed")


func test_has_does_not_log() -> void:
	# `has` is the way to ask without producing an error, so a caller checking
	# for an optional string does not fill the log with false alarms.
	assert_false(Strings.has(&"ui.definitely.not.present"))
	assert_true(Strings.has(&"menu.quit"))
	assert_push_error_count(0, "has() must be silent")


func test_every_ability_and_passive_display_key_resolves() -> void:
	# These keys are referenced by the .tres resources generated in US-0007. A
	# resource pointing at a key that does not exist would render as the raw key
	# in the ability bar, and nothing else would complain.
	var profile: TuningProfile = load("res://data/tuning/default/profile.tres")
	var missing: PackedStringArray = []
	for id: StringName in profile.abilities:
		var data: AbilityData = profile.abilities[id]
		if not Strings.has(data.display_key):
			missing.append("%s -> %s" % [id, data.display_key])
	for id: StringName in profile.passives:
		var data: PassiveData = profile.passives[id]
		if not Strings.has(data.display_key):
			missing.append("%s -> %s" % [id, data.display_key])
	missing.sort()
	assert_eq(
		missing.size(),
		0,
		"A resource points at a string key that does not exist.\n" + "\n".join(missing)
	)
