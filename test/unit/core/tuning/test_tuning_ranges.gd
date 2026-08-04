## Every shipped value is inside its own documented range, and the 20 cross-field
## invariants from TUNABLES.md §17 hold.
##
## The range half catches a typo. The invariant half catches the subtler thing: a
## value that is perfectly legal on its own and wrong in relation to another.
## Invariant 1 is the clearest case — blend-walk and the NPC stroll are both legal
## anywhere in 1.2–1.6, and the game is broken unless they are the same number.
extends GutTest

const PROFILE := "res://data/tuning/default/profile.tres"


## ALWAYS A DEEP COPY. `load()` returns the cached instance, which is the same
## object the Tuning autoload is holding — a test that mutates it to prove a
## guard fires would silently corrupt every later test and the live profile.
func _profile() -> TuningProfile:
	var p: TuningProfile = load(PROFILE)
	assert_not_null(p, "could not load " + PROFILE)
	return p.clone()


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
	# All 20 now assert for real. Invariants 11 and 12 were pending until
	# AbilityData existed, and reported "cannot check" rather than passing over
	# the gap — if either ever regresses to that, this fails loudly rather than
	# quietly going green on 18 of 20.
	var errors: Array[String] = _profile().validate()
	assert_eq(errors.size(), 0, "Cross-field invariant violated.\n" + "\n".join(errors))
	for e: String in errors:
		assert_false(e.contains("cannot check"), "an invariant became unverifiable again: " + e)


func test_the_ability_invariants_are_live() -> void:
	# 11 and 12 depend on the abilities dictionary being populated. An empty
	# dictionary would make validate() silently skip them.
	var p := _profile()
	assert_true(p.abilities.has(Ids.ABIL_WHISPERBOLT), "invariant 11 has nothing to check")
	assert_true(p.abilities.has(Ids.ABIL_CINDERFALL), "invariant 12 has nothing to check")

	var cinderfall: AbilityData = p.abilities[Ids.ABIL_CINDERFALL]
	var radius := cinderfall.radius
	cinderfall.radius = p.combat.kill_range  # deliberately under 2x
	var hit := false
	for e: String in p.validate():
		if e.begins_with("12."):
			hit = true
	cinderfall.radius = radius
	assert_true(hit, "breaking invariant 12 produced no error — it is inert")


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
