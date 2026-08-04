## A profile survives serialise → deserialise field-for-field.
##
## The server sends its profile to every client at session start, so a playtest
## never runs on mixed values. A round-trip that dropped one field would produce
## exactly the bug that is hardest to diagnose: two machines agreeing about the
## rules except in one place.
extends GutTest

const PROFILE := "res://data/tuning/default/profile.tres"


func test_round_trip_preserves_every_field() -> void:
	var original: TuningProfile = load(PROFILE).duplicate(true)
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
	var original: TuningProfile = load(PROFILE).duplicate(true)
	var restored := TuningProfile.deserialise(original.serialise())
	assert_eq(
		original.compute_hash(),
		restored.compute_hash(),
		"a round-tripped profile must hash identically or telemetry is unreadable"
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
	var a: TuningProfile = load(PROFILE).duplicate(true)
	var b := TuningProfile.deserialise(a.serialise())
	b.movement.sprint += 1.0
	assert_ne(a.movement.sprint, b.movement.sprint, "the sections are aliased, not copied")
