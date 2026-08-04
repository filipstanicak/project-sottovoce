## Every duration tunable has a precomputed integer tick count.
##
## SYSTEMS COMPARE INTEGERS, NEVER ACCUMULATED FLOATS. A cooldown counted by
## adding `delta` drifts differently on every machine, and a server-authoritative
## outcome resting on accumulated float error is a desync waiting for one slow
## frame. Converting once, at load, is the whole point.
extends GutTest


func test_every_duration_tunable_has_ticks() -> void:
	var missing: PackedStringArray = []
	for id: StringName in TuningIndex.FIELD:
		var unit: String = TuningIndex.FIELD[id][2]
		if TuningIndex.DURATION_UNITS.has(unit) and not Tuning.has_ticks(id):
			missing.append("%s (%s)" % [id, unit])
	missing.sort()
	assert_eq(
		missing.size(),
		0,
		"A duration tunable has no precomputed tick count.\n" + "\n".join(missing)
	)


func test_ticks_match_the_server_rate() -> void:
	var rate := Tuning.net.server_tick
	# TUN-KILL-ANIM-DURATION is 1.4 s, the commit ceiling — a value the whole
	# feel budget is built around, so it is worth checking by hand.
	var expected := int(round(Tuning.combat.kill_anim_duration * rate))
	assert_eq(
		Tuning.ticks(&"TUN-KILL-ANIM-DURATION"),
		expected,
		"kill animation should be %d ticks at %.0f Hz" % [expected, rate]
	)
	assert_gt(expected, 0, "the conversion produced zero ticks")


func test_millisecond_durations_are_converted() -> void:
	# TUN-FEEL-INPUT-TO-ANIM-MAX is 80 ms. Treating it as 80 SECONDS would give
	# 2400 ticks and look like a plausible number in a log.
	var ms_ticks := Tuning.ticks(&"TUN-FEEL-INPUT-TO-ANIM-MAX")
	assert_gt(ms_ticks, 0, "80 ms must convert to a positive tick count")
	assert_lt(ms_ticks, 10, "80 ms became %d ticks — a ms/s unit confusion" % ms_ticks)


func test_a_non_duration_has_no_ticks() -> void:
	assert_false(Tuning.has_ticks(&"TUN-SPEED-SPRINT"), "a m/s value is not a duration")
	assert_eq(Tuning.ticks(&"TUN-SPEED-SPRINT"), 0, "a non-duration must return 0")
	assert_eq(Tuning.ticks(&"TUN-NOT-A-REAL-ID"), 0, "an unknown ID must return 0, not crash")


func test_per_ability_durations_are_included() -> void:
	# Ability durations live in AbilityData rather than a *Tuning section, so they
	# resolve through a different path and would be easy to omit silently.
	for id: StringName in [&"TUN-CINDERFALL-COOLDOWN", &"TUN-WHISPERBOLT-WINDUP"]:
		assert_true(Tuning.has_ticks(id), "%s should have ticks" % id)
		assert_gt(Tuning.ticks(id), 0, "%s converted to zero ticks" % id)
