## Every shipped value is inside its own documented range, and the 31 cross-field
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
	# All 26 now assert for real. Invariants 11 and 12 were pending until
	# AbilityData existed, and reported "cannot check" rather than passing over
	# the gap — if either ever regresses to that, this fails loudly rather than
	# quietly going green on 24 of 26.
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


func test_the_anchor_pocket_invariant_is_live() -> void:
	# 28, falsified. This is the invariant whose violation has no symptom: widen
	# the arrival radius and idle anchors quietly stop forming blend pockets —
	# nothing errors, no NPC misbehaves, and the game simply has fewer places to
	# hide. An inert check here would be worse than no check, because it is the
	# reason nobody would go looking.
	var p := _profile()
	p.crowd.anchor_arrive_radius = p.suspicion.blend_pocket_radius
	var caught := false
	for e: String in p.validate():
		if e.begins_with("28."):
			caught = true
	assert_true(caught, "an anchor too wide to form a pocket produced no error — 28 is inert")


func test_the_fov_invariants_are_live() -> void:
	# 21 and 22, falsified rather than trusted. An inverted FOV ladder is the one
	# tuning error in this file that a playtester would feel and never be able to
	# name — the lens would tell a sprinting player they were calm — so the check
	# has to be proven to fire, not merely to exist.
	var p := _profile()
	p.camera.fov_run = p.camera.fov_stroll - 1.0
	var inverted := false
	for e: String in p.validate():
		if e.begins_with("21."):
			inverted = true
	assert_true(inverted, "inverting the FOV ladder produced no error — invariant 21 is inert")

	p = _profile()
	p.camera.fov_motion_reduced = p.camera.fov_sprint + 5.0
	var outside := false
	for e: String in p.validate():
		if e.begins_with("22."):
			outside = true
	assert_true(outside, "a locked FOV outside the ladder produced no error — 22 is inert")


func test_the_lagcomp_invariant_is_live() -> void:
	# **INVARIANT 16 — US-0035's fifth criterion.** `LagCompHistory` sizes its ring
	# from `lagcomp_history`, so this is what keeps the buffer from becoming the
	# binding constraint on how far §8.1 may rewind.
	#
	# Falsified rather than trusted, because the shipped values satisfy it and
	# `test_all_cross_field_invariants_hold` would pass identically if the check
	# had never been written. A rewind ceiling raised past the ring would not
	# error — it would silently return the oldest frame held, which is a *shorter*
	# rewind than asked for, and nobody would notice until a kill felt wrong.
	var p := _profile()
	p.net.lagcomp_max = p.net.lagcomp_history / 2.0 + 1.0
	var hit := false
	for e: String in p.validate():
		if e.begins_with("16."):
			hit = true
	assert_true(hit, "a rewind ceiling past half the ring produced no error — 16 is inert")


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


func test_the_rate_lod_invariants_are_live() -> void:
	# 30 and 31, falsified. Both fail the same way: SILENTLY, and in the direction
	# of sending more than the tunables claim. A rate-LOD radius past the cull
	# radius describes a band that cannot exist, so the branch is simply never
	# reached; a far rate above the snapshot rate computes a stride of one, so
	# every NPC is sent every tick while `TUN-NET-NPC-RATE-LOD-HZ` says 10. In both
	# cases the bandwidth budget is missed by a mechanism reporting itself as
	# working, which is the failure this whole story exists downstream of.
	var p := _profile()
	p.net.npc_rate_lod_radius = p.net.npc_cull_radius + 10.0
	var past := false
	for e: String in p.validate():
		if e.begins_with("30."):
			past = true
	assert_true(past, "a rate-LOD radius beyond the cull radius produced no error — 30 is inert")

	p = _profile()
	p.net.npc_rate_lod_hz = p.net.snapshot_rate + 5.0
	var faster := false
	for e: String in p.validate():
		if e.begins_with("31."):
			faster = true
	assert_true(faster, "a 'reduced' rate above the snapshot rate produced no error — 31 is inert")
