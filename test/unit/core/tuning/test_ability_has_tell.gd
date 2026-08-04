## DESIGN LAW 3, ENFORCED BY THE SCHEMA RATHER THAN BY REVIEW.
##
## "No ability resolves without the victim having had a perceivable chance to
## read it. Two tell channels minimum, at least one environmental or audio, so it
## survives the victim not looking at the caster."
##
## DATA_SCHEMA §4.1 states the assertion: at least two tell channels filled, with
## at least one of `tell_audio_radius > 0` or `startle_radius > 0`. A purely
## visual tell fails, because it assumes the victim happened to be looking.
extends GutTest

const PROFILE := "res://data/tuning/default/profile.tres"


func _abilities() -> Dictionary:
	var p: TuningProfile = load(PROFILE)
	assert_not_null(p, "could not load " + PROFILE)
	return p.abilities


func test_every_ability_has_at_least_two_tell_channels() -> void:
	var failures: PackedStringArray = []
	for id: StringName in _abilities():
		var a: AbilityData = _abilities()[id]
		var channels := 0
		if a.tell_sfx != &"":
			channels += 1
		if a.tell_audio_radius > 0.0:
			channels += 1
		if a.startle_radius > 0.0:
			channels += 1
		if a.tell_vfx != null:
			channels += 1
		if channels < 2:
			failures.append("%s has %d tell channel(s), needs 2" % [id, channels])
	assert_eq(
		failures.size(), 0, "An ability can resolve without being readable.\n" + "\n".join(failures)
	)


func test_every_ability_has_a_non_visual_channel() -> void:
	# The one that actually matters. A visual-only tell assumes the victim was
	# looking at the caster, which is exactly the assumption the law forbids.
	var failures: PackedStringArray = []
	for id: StringName in _abilities():
		var a: AbilityData = _abilities()[id]
		if a.tell_audio_radius <= 0.0 and a.startle_radius <= 0.0:
			failures.append("%s has no audio or environmental tell" % id)
	assert_eq(
		failures.size(),
		0,
		(
			"An ability is readable only by looking at the caster.\n"
			+ "Give it an audio radius or a startle radius — see design law 3.\n"
			+ "\n".join(failures)
		)
	)


func test_every_ability_is_present_and_identified() -> void:
	var expected: Array[StringName] = [
		Ids.ABIL_CINDERFALL, Ids.ABIL_LUNGE, Ids.ABIL_SECONDFACE, Ids.ABIL_WHISPERBOLT
	]
	for id: StringName in expected:
		assert_true(_abilities().has(id), "missing ability %s" % id)
	for id: StringName in _abilities():
		var a: AbilityData = _abilities()[id]
		assert_eq(a.id, id, "ability keyed as %s declares id %s" % [id, a.id])
		assert_ne(a.display_key, &"", "%s has no string-table key" % id)


func test_the_tell_check_actually_fires() -> void:
	# Guards the guard. If the channel count never reached zero the assertions
	# above would pass over an ability with no tell at all.
	var bare := AbilityData.new()
	assert_eq(bare.tell_sfx, &"", "a fresh AbilityData must start with no tell")
	assert_eq(bare.tell_audio_radius, 0.0, "a fresh AbilityData must start with no tell")
	assert_eq(bare.startle_radius, 0.0, "a fresh AbilityData must start with no tell")
