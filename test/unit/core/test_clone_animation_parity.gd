## **LAYER 2 OF FOUR.** ANIMATION_SPEC §7, GDD-03 §6.5, US-0046.
##
## **THE CONSTRAINT THIS GUARDS FAILS SILENTLY, AND THAT IS THE ONLY REASON IT
## NEEDS FOUR LAYERS.** An animator adds a charming idle on the player rig.
## Nothing breaks, no test fails, the crowd count is unchanged — and three weeks
## later skilled testers pick humans out of the crowd reliably and cannot say how.
## Human review misses it every time, because the defect is an *absence* on a rig
## nobody was editing.
##
## **AND THE LIBRARY HALF CANNOT PASS YET, SO IT REPORTS.** There are no animation
## clips in this project — not one, on either rig. A test that asserted "every
## declared clip exists in the clone's library" would be red on every push with
## nothing anybody can do about it until an animator exists, and a red suite
## nobody can turn green stops being read. The *declaration* half is asserted
## properly, because that is the half that can be wrong today.
extends GutTest

const PERSONAS := "res://data/personas/"

var _personas: Array[PersonaData] = []


func before_each() -> void:
	_personas = []
	for slug: String in ["vetraio", "cantatrice", "lucerna", "pesatore"]:
		var data := load(PERSONAS + slug + ".tres") as PersonaData
		if data != null:
			_personas.append(data)


func test_all_four_personas_exist() -> void:
	# Guards every assertion below. `SCOPE_FENCE` IN #3 is four personas, and a
	# parity check over three of them would pass while a whole identity had no
	# clones to hide among.
	assert_eq(_personas.size(), 4, "there are not four PersonaData resources")
	# **`StringName` DOES NOT SORT ALPHABETICALLY.** Godot orders it by internal
	# pointer, so `Array.sort()` on a list of them returns a stable but arbitrary
	# order — the first version of this assertion got the four back reversed and
	# read like a genuine mismatch. Compared as `String`, which does.
	var ids: Array = []
	for data: PersonaData in _personas:
		ids.append(String(data.id))
	ids.sort()
	assert_eq(
		ids,
		["PERSONA-CANTATRICE", "PERSONA-LUCERNA", "PERSONA-PESATORE", "PERSONA-VETRAIO"],
		"the four personas are not the four PERSONA- ids"
	)


func test_the_parity_set_is_the_documented_fourteen() -> void:
	# ANIMATION_SPEC §8 costs the parity set at 14 clips x 4 personas x 2 rigs and
	# says so before anybody proposes a fifth persona. If this number moves, that
	# arithmetic moves with it.
	assert_eq(PersonaData.PARITY_SET.size(), 14, "the parity set is not ANIMATION_SPEC's fourteen")
	var seen: Dictionary = {}
	for clip: StringName in PersonaData.PARITY_SET:
		assert_false(seen.has(clip), "%s appears twice in the parity set" % clip)
		seen[clip] = true


func test_every_parity_clip_is_a_documented_id() -> void:
	# **THE SET MAY NOT INVENT A CLIP.** `Ids` is harvested from `docs/`, so a name
	# that is not in it is a name no document ever declared — and an animator
	# checking §7.1's table against this list would be told to author something
	# that does not exist in the corpus.
	# `Ids` is a flat wall of constants with no collection to ask, so the constant
	# map is read off the script itself. That is also the only way to be sure the
	# check sees *every* declared id rather than a list somebody maintains.
	var declared: Dictionary = {}
	for value: Variant in (
		(load("res://scripts/core/ids.gd") as GDScript).get_script_constant_map().values()
	):
		declared[value] = true
	assert_gt(declared.size(), 100, "the Ids constant map came back nearly empty — the scan broke")
	for clip: StringName in PersonaData.PARITY_SET:
		assert_true(
			declared.has(clip), "%s is in the parity set but is not a documented ANIM- id" % clip
		)


func test_every_persona_declares_the_whole_parity_set() -> void:
	# **LAYER 1, ASSERTED.** A persona missing a row would simply have one fewer
	# thing its clones can do, which is invisible until a player does it.
	for data: PersonaData in _personas:
		var absent := data.missing_from_declaration()
		assert_eq(
			absent.size(), 0, "%s does not declare: %s" % [data.id, String(", ").join(absent)]
		)
		assert_eq(
			data.anonymous_clip_names.size(),
			PersonaData.PARITY_SET.size(),
			"%s declares clips outside the parity set" % data.id
		)


func test_the_four_silhouettes_are_mutually_distinct() -> void:
	# DATA_SCHEMA §4.4. Two personas sharing a silhouette would halve the number of
	# things a hunter has to tell apart at 40 m — and it is the *hunter's* ability
	# to read the crowd that makes hiding in it a skill rather than a coin flip.
	var seen: Dictionary = {}
	for data: PersonaData in _personas:
		assert_false(seen.has(data.silhouette), "%s reuses a silhouette" % data.id)
		seen[data.silhouette] = data.id
	assert_eq(seen.size(), 4, "the four personas do not have four distinct silhouettes")


func test_the_heights_are_art_bibles_own_numbers() -> void:
	# §6.1's table, which is what `PersonaBody` builds from. A height that drifted
	# from the bible would be a silhouette claim nobody had tested.
	var expected := {
		Ids.PERSONA_VETRAIO: 1.68,
		Ids.PERSONA_CANTATRICE: 1.72,
		Ids.PERSONA_LUCERNA: 1.89,
		Ids.PERSONA_PESATORE: 1.75,
	}
	for data: PersonaData in _personas:
		assert_almost_eq(
			data.stand_height, float(expected[data.id]), 0.001, "%s is the wrong height" % data.id
		)


func test_no_two_personas_share_an_identity_hue() -> void:
	# ART_BIBLE §3's colour-language law reserves saturated colour for identity.
	# Two personas sharing one would make the reservation pointless.
	var seen: Dictionary = {}
	for data: PersonaData in _personas:
		var key := (
			"%.2f,%.2f,%.2f" % [data.identity_hue.r, data.identity_hue.g, data.identity_hue.b]
		)
		assert_false(seen.has(key), "%s reuses an identity hue" % data.id)
		seen[key] = true


func test_the_library_half_is_reported_until_an_animator_exists() -> void:
	# **THE HALF THAT CANNOT PASS YET.** It goes green by itself the day the first
	# `AnimationLibrary` lands, and red the day one lands incomplete.
	var without: PackedStringArray = []
	var missing := 0
	for data: PersonaData in _personas:
		if not data.has_rig():
			without.append(String(data.id))
		missing += data.missing_from_library().size()
	if without.size() == 0:
		assert_eq(missing, 0, "a clone rig is missing parity clips: %d absent" % missing)
		return
	assert_eq(missing, 4 * 14, "a persona has a rig but the count says otherwise")
	pending(
		(
			(
				"%d of 4 personas have no AnimationLibrary, so 56 parity clips cannot be checked. "
				+ "There are no animation clips in this project on either rig; ANIMATION_SPEC §8 "
				+ "costs the parity set at 14 x 4 x 2 rigs. This assertion turns real by itself."
			)
			% without.size()
		)
	)
