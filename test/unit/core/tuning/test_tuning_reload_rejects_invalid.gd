## An invalid profile is REJECTED and the previous one retained.
##
## A half-applied tuning change is worse than none. It produces a game that
## matches no document, so the playtest that follows measures something nobody
## can reconstruct afterwards — and the numbers in the notes are wrong rather
## than merely unhelpful.
extends GutTest

const PROFILE := "res://data/tuning/default/profile.tres"


func _invalid_profile() -> TuningProfile:
	# Breaks invariant 6: the prey's reach must exceed the hunter's. Chosen
	# because it is the one the design laws call non-negotiable.
	var p: TuningProfile = (load(PROFILE) as TuningProfile).clone()
	p.combat.stun_range = p.combat.kill_range - 0.5
	return p


func test_the_fixture_really_is_invalid() -> void:
	# Guards the guard: if this profile validated, every assertion below would be
	# testing that a VALID profile is accepted, and would pass for the wrong reason.
	var errors: Array[String] = _invalid_profile().validate()
	assert_gt(errors.size(), 0, "the fixture was supposed to violate invariant 6")


func test_adopting_an_invalid_profile_is_refused() -> void:
	var accepted := Tuning.adopt(_invalid_profile())
	assert_false(accepted, "an invalid profile must not be adopted")
	# A rejection must be LOUD: one header plus one line per violation. A silent
	# refusal looks identical to a successful reload from the playtest console.
	assert_push_error_count(2, "the rejection should have named the invariant it failed")


func test_the_previous_profile_survives_a_refused_adopt() -> void:
	var before := Tuning.profile.compute_hash()
	var stun_before := Tuning.combat.stun_range
	Tuning.adopt(_invalid_profile())
	assert_push_error_count(2)
	assert_eq(Tuning.profile.compute_hash(), before, "the live profile was replaced anyway")
	assert_eq(Tuning.combat.stun_range, stun_before, "a section was left half-applied")


func test_ticks_are_not_recomputed_from_a_refused_profile() -> void:
	# The subtler half. Even if `profile` is restored, ticks derived from the
	# rejected values would leave the game running on numbers from a profile it
	# claims not to have.
	var before := Tuning.ticks(&"TUN-KILL-ANIM-DURATION")
	var bad := _invalid_profile()
	bad.combat.kill_anim_duration = 0.1
	Tuning.adopt(bad)
	assert_push_error_count(2)
	assert_eq(Tuning.ticks(&"TUN-KILL-ANIM-DURATION"), before, "ticks came from a rejected profile")


func test_a_valid_profile_is_accepted_and_announced() -> void:
	var valid: TuningProfile = (load(PROFILE) as TuningProfile).clone()
	watch_signals(Tuning)
	assert_true(Tuning.adopt(valid), "a valid profile must be adopted")
	assert_signal_emitted(Tuning, "reloaded", "anything holding a derived value was never told")


func test_null_is_refused_without_crashing() -> void:
	var before := Tuning.profile.compute_hash()
	assert_false(Tuning.adopt(null), "null must be refused")
	assert_push_error_count(1, "a null profile should log exactly one error")
	assert_eq(Tuning.profile.compute_hash(), before, "the live profile survived")
