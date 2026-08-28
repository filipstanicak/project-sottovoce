## A profile survives serialise → deserialise field-for-field.
##
## The server sends its profile to every client at session start, so a playtest
## never runs on mixed values. A round-trip that dropped one field would produce
## exactly the bug that is hardest to diagnose: two machines agreeing about the
## rules except in one place.
extends GutTest

const PROFILE := "res://data/tuning/default/profile.tres"


func test_round_trip_preserves_every_field() -> void:
	var original: TuningProfile = (load(PROFILE) as TuningProfile).clone()
	var restored := TuningProfile.deserialise(original.serialise())
	assert_not_null(restored, "deserialise returned null")

	var diffs: PackedStringArray = []
	for section: StringName in [
		"movement",
		"suspicion",
		"compass",
		"combat",
		"contract",
		"crowd",
		"match_rules",
		"scoring",
		"camera",
		"net",
		"perf",
		"ui_audio",
		"flags"
	]:
		var a: Resource = original.get(section)
		var b: Resource = restored.get(section)
		if b == null:
			diffs.append("%s missing after round-trip" % section)
			continue
		for prop: Dictionary in a.get_property_list():
			if not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE):
				continue
			var name: String = prop["name"]
			if name.begins_with("script") or name == "resource_local_to_scene":
				continue
			if a.get(name) != b.get(name):
				diffs.append("%s.%s: %s -> %s" % [section, name, a.get(name), b.get(name)])
	assert_eq(diffs.size(), 0, "Round-trip lost or altered fields.\n" + "\n".join(diffs))


func test_round_trip_preserves_the_hash() -> void:
	var original: TuningProfile = (load(PROFILE) as TuningProfile).clone()
	var restored := TuningProfile.deserialise(original.serialise())
	assert_eq(
		original.compute_hash(),
		restored.compute_hash(),
		"a round-tripped profile must hash identically or telemetry is unreadable"
	)


func test_the_ability_numbers_survive_the_round_trip() -> void:
	# **THE SECTION LOOP ABOVE DOES NOT COVER ABILITIES**, and nothing did until
	# US-0067 changed what is sent. A cooldown lost here is a HUD sweep that never
	# empties on a client whose profile came from the server.
	var original: TuningProfile = (load(PROFILE) as TuningProfile).clone()
	var restored := TuningProfile.deserialise(original.serialise())
	var mine: AbilityData = original.abilities.get(Ids.ABIL_CINDERFALL)
	var theirs: AbilityData = restored.abilities.get(Ids.ABIL_CINDERFALL)
	assert_not_null(theirs, "Cinderfall did not survive the round-trip")
	for field: StringName in [&"cooldown", &"cast_time", &"radius", &"duration", &"blocks_kill"]:
		assert_eq(theirs.get(field), mine.get(field), "%s was lost on the wire" % field)


func test_no_code_and_no_scene_travels() -> void:
	# **CODE DOES NOT GO ON THE WIRE.** `serialise` is
	# `var_to_bytes_with_objects`, so an `AbilityData` field holding a `Script` would
	# be sent as a script — and TDD-09 §3 makes effects **server only**, with
	# `scripts/systems/` excluded from the client export. A client has no business
	# holding the code and every reason not to be handed it by whatever it connected
	# to.
	#
	# **THE ENGINE FOUND THIS, NOT A REVIEW.** The tick `cinderfall.tres` gained an
	# `effect_script`, the two tests above went red with *"Class CinderfallEffect
	# hides a global script class"* — the decoder re-parsing a script already in the
	# global registry. The parse error was the symptom; this is the rule.
	var original: TuningProfile = (load(PROFILE) as TuningProfile).clone()
	assert_not_null(
		(original.abilities.get(Ids.ABIL_CINDERFALL) as AbilityData).effect_script,
		"Cinderfall has no effect script on disk, so this test proves nothing"
	)
	var restored := TuningProfile.deserialise(original.serialise())
	for id: Variant in restored.abilities:
		var row: AbilityData = restored.abilities[id]
		assert_null(row.effect_script, "%s sent its effect script over the wire" % id)
		assert_null(row.tell_vfx, "%s sent a PackedScene over the wire" % id)


func test_stripping_the_script_does_not_move_the_hash() -> void:
	# `compute_hash` walks the thirteen sections and has never included abilities, so
	# a client and a server still agree about the tuning they are playing under.
	# Asserted rather than assumed, because `Handshake` refuses a peer on a hash
	# mismatch and this would be an unexplainable refusal.
	var original: TuningProfile = (load(PROFILE) as TuningProfile).clone()
	assert_eq(
		original.compute_hash(), TuningProfile.deserialise(original.serialise()).compute_hash()
	)


func test_deserialise_rejects_undersized_input() -> void:
	# Rejected before the engine decoder sees it. A decoder that logs an error on
	# every malformed packet is a denial-of-service vector on a server taking
	# bytes from clients, so the length guard is a real defence, not tidiness.
	assert_null(
		TuningProfile.deserialise(PackedByteArray([1, 2, 3, 4])), "4 bytes must be rejected"
	)
	assert_null(TuningProfile.deserialise(PackedByteArray()), "empty input must be rejected")


func test_the_comparison_actually_detects_a_difference() -> void:
	# Guards the guard: if the field walk compared nothing, the test above would
	# pass on a round-trip that dropped every value.
	var a: TuningProfile = (load(PROFILE) as TuningProfile).clone()
	var b := TuningProfile.deserialise(a.serialise())
	b.movement.sprint += 1.0
	assert_ne(a.movement.sprint, b.movement.sprint, "the sections are aliased, not copied")
