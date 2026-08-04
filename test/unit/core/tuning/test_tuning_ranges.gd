## Every shipped value is inside its own documented range, and the 20 cross-field
## invariants from TUNABLES.md §17 hold.
##
## The range half catches a typo. The invariant half catches the subtler thing: a
## value that is perfectly legal on its own and wrong in relation to another.
## Invariant 1 is the clearest case — blend-walk and the NPC stroll are both legal
## anywhere in 1.2–1.6, and the game is broken unless they are the same number.
extends GutTest

const PROFILE := "res://data/tuning/default/profile.tres"


func _profile() -> TuningProfile:
	var p: TuningProfile = load(PROFILE)
	assert_not_null(p, "could not load " + PROFILE)
	return p


func test_every_value_is_inside_its_export_range() -> void:
	var p := _profile()
	var out_of_range: PackedStringArray = []
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
		"ui_audio"
	]:
		var res: Resource = p.get(section)
		for prop: Dictionary in res.get_property_list():
			if int(prop["hint"]) != PROPERTY_HINT_RANGE:
				continue
			var bounds: PackedStringArray = String(prop["hint_string"]).split(",")
			if bounds.size() < 2:
				continue
			var value := float(res.get(prop["name"]))
			var lo := float(bounds[0])
			var hi := float(bounds[1])
			if value < lo or value > hi:
				out_of_range.append(
					"%s.%s = %s, outside %s–%s" % [section, prop["name"], value, lo, hi]
				)
	assert_eq(
		out_of_range.size(),
		0,
		"A shipped value is outside its documented range.\n" + "\n".join(out_of_range)
	)


func test_all_cross_field_invariants_hold() -> void:
	# Invariants 11 and 12 read per-ability values that arrive with AbilityData.
	# Until then they report "cannot check" rather than passing silently, which
	# is the whole point — an unverifiable invariant must never look verified.
	var errors: Array[String] = _profile().validate()
	var real: Array[String] = []
	var pending: Array[String] = []
	for e: String in errors:
		if e.contains("cannot check"):
			pending.append(e)
		else:
			real.append(e)
	assert_eq(real.size(), 0, "Cross-field invariant violated.\n" + "\n".join(real))
	assert_eq(
		pending.size(),
		2,
		(
			"Expected exactly the two ability invariants to be pending. If AbilityData "
			+ "now exists, delete this expectation and let 11 and 12 assert for real.\n"
			+ "\n".join(pending)
		)
	)


func test_the_invariant_checker_actually_fires() -> void:
	# Guards the guard. A validate() that returned an empty array unconditionally
	# would make every assertion above pass over nothing.
	var p := _profile()
	p.movement.blend_walk = p.crowd.npc_speed_stroll + 0.2
	var errors: Array[String] = p.validate()
	var hit := false
	for e: String in errors:
		if e.begins_with("1."):
			hit = true
	assert_true(hit, "breaking invariant 1 produced no error — the checker is inert")
