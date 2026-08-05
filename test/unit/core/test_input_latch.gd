## Hold versus toggle, for every holdable action. GDD-02 §9.3.
##
## This is an accessibility provision with **no competitive dimension**: it
## changes how a player asks for a state, never which states exist or what they
## cost. That is why it can live client-side at all — and why the test that
## matters most here is the one asserting a toggle and a hold produce the
## identical active flag.
extends GutTest

var _latch: InputLatch


func before_each() -> void:
	_latch = InputLatch.new()


func _hold(id: StringName, pressed: bool) -> bool:
	return _latch.resolve(id, pressed, InputLatch.Mode.HOLD)


func _toggle(id: StringName, pressed: bool) -> bool:
	return _latch.resolve(id, pressed, InputLatch.Mode.TOGGLE)


func test_hold_mode_is_the_raw_button() -> void:
	assert_false(_hold(Ids.INPUT_SLOW, false))
	assert_true(_hold(Ids.INPUT_SLOW, true))
	assert_true(_hold(Ids.INPUT_SLOW, true), "a held key stopped counting as held")
	assert_false(_hold(Ids.INPUT_SLOW, false))


func test_toggle_flips_on_the_rising_edge_only() -> void:
	assert_true(_toggle(Ids.INPUT_SLOW, true), "the first press did not latch on")
	assert_true(_toggle(Ids.INPUT_SLOW, true), "holding flipped it back off")
	assert_true(_toggle(Ids.INPUT_SLOW, false), "releasing cleared a toggle")
	assert_false(_toggle(Ids.INPUT_SLOW, true), "the second press did not latch off")
	assert_false(_toggle(Ids.INPUT_SLOW, false))


func test_a_toggle_and_a_hold_produce_the_same_active_flag() -> void:
	# The two modes must be indistinguishable downstream. If they were not, the
	# accessibility option would be a balance change, and it is not allowed to be.
	var held := _hold(Ids.INPUT_SLOW, true)
	var latched := _toggle(Ids.INPUT_RUN, true)
	assert_eq(held, latched, "hold and toggle disagree about being active")


func test_actions_do_not_share_a_latch() -> void:
	assert_true(_toggle(Ids.INPUT_SLOW, true))
	assert_true(_toggle(Ids.INPUT_SCAN, true))
	_toggle(Ids.INPUT_SLOW, false)  # Release, so the next press is a rising edge.
	assert_false(_toggle(Ids.INPUT_SLOW, true), "slow did not toggle back off")
	assert_true(_latch.is_latched(Ids.INPUT_SCAN), "toggling slow moved scan")


func test_switching_to_hold_does_not_resurrect_an_old_toggle() -> void:
	# A player who toggles blend-walk on, switches the option to hold, and lets go
	# must stop blend-walking. Otherwise the setting appears to do nothing until a
	# press they have already forgotten about.
	assert_true(_toggle(Ids.INPUT_SLOW, true))
	assert_false(_hold(Ids.INPUT_SLOW, false), "a stale latch survived the mode switch")
	assert_false(_latch.is_latched(Ids.INPUT_SLOW))


func test_release_clears_a_latch_for_a_respawn() -> void:
	assert_true(_toggle(Ids.INPUT_SLOW, true))
	_latch.release(Ids.INPUT_SLOW)
	assert_false(_latch.is_latched(Ids.INPUT_SLOW), "a toggle survived a respawn")
	assert_true(_toggle(Ids.INPUT_SLOW, true), "the next press did not latch on again")


func test_release_all_clears_everything() -> void:
	for id: StringName in [Ids.INPUT_SLOW, Ids.INPUT_RUN, Ids.INPUT_SCAN]:
		assert_true(_toggle(id, true))
	_latch.release_all()
	for id: StringName in [Ids.INPUT_SLOW, Ids.INPUT_RUN, Ids.INPUT_SCAN]:
		assert_false(_latch.is_latched(id), "%s survived release_all" % id)


func test_every_action_the_gdd_calls_holdable_can_toggle() -> void:
	# GDD-02 §9.3 names five by ID. The list is asserted here rather than trusted,
	# because "everything holdable is toggleable" is a §1.1 design principle and a
	# missing one reads as an oversight rather than as a decision.
	var expected := [
		Ids.INPUT_SLOW, Ids.INPUT_RUN, Ids.INPUT_SPRINT, Ids.INPUT_SCAN, Ids.INPUT_SCORE
	]
	var missing: PackedStringArray = []
	for id: StringName in expected:
		if not InputActions.is_toggleable(id):
			missing.append(String(id))
	assert_eq(missing.size(), 0, "GDD-02 §9.3 requires a toggle for: " + ", ".join(missing))
