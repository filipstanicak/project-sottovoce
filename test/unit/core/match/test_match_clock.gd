## `MatchClock` — the phase durations, the Final Contract boundary and the warning.
##
## **THE ASSERTION THAT MATTERS IS THE LAST ONE**: the boundary this class owns and
## the one `ScoreEvent` pays at are the same instant. They were two independent
## derivations until 2026-09-08, and two derivations of one instant disagree the day
## either moves — in a way no test of scoring or of the clock alone can see.
extends GutTest

const RATE := 30.0


func _rules() -> MatchTuning:
	# The shipped values, built by hand rather than adopted: this class takes its
	# tuning as an argument precisely so a test need not touch the live profile.
	var r := MatchTuning.new()
	r.tick_rate = RATE
	r.lobby_countdown = 5.0
	r.duration = 480.0
	r.finalphase_duration = 30.0
	r.finalphase_warning = 5.0
	r.results_duration = 25.0
	return r


func test_the_lobby_does_not_end_on_a_clock() -> void:
	# It ends when enough peers have joined, which is not a fact about time. A
	# duration here would be a timeout nobody documented.
	assert_eq(MatchClock.duration_ticks(MatchPhase.Phase.LOBBY, _rules()), MatchClock.NO_CLOCK)


func test_active_is_the_match_minus_the_final_contract() -> void:
	# **480 s IS THE PAIR, NOT THE LENGTH OF `ACTIVE`.** Read the other way this
	# runs a 510 s match and puts the multiplier 30 s past where scoring pays it.
	var r := _rules()
	assert_eq(MatchClock.duration_ticks(MatchPhase.Phase.ACTIVE, r), 13500)
	assert_eq(MatchClock.duration_ticks(MatchPhase.Phase.FINAL, r), 900)
	assert_eq(
		(
			MatchClock.duration_ticks(MatchPhase.Phase.ACTIVE, r)
			+ MatchClock.duration_ticks(MatchPhase.Phase.FINAL, r)
		),
		int(r.duration * RATE),
		"ACTIVE and FINAL together must be exactly TUN-MATCH-DURATION"
	)


func test_the_phases_run_in_the_documented_order() -> void:
	assert_eq(MatchClock.next_phase(MatchPhase.Phase.WARMUP), MatchPhase.Phase.ACTIVE)
	assert_eq(MatchClock.next_phase(MatchPhase.Phase.ACTIVE), MatchPhase.Phase.FINAL)
	assert_eq(MatchClock.next_phase(MatchPhase.Phase.FINAL), MatchPhase.Phase.RESULTS)


func test_results_does_not_fall_through_to_a_new_match() -> void:
	# Returning LOBBY would restart the match on a timer. Whether a server re-opens
	# is US-0078's, and it is a decision rather than a fall-through.
	assert_eq(MatchClock.next_phase(MatchPhase.Phase.RESULTS), MatchPhase.Phase.RESULTS)


func test_the_warning_lands_before_the_boundary_by_its_own_tunable() -> void:
	var r := _rules()
	var gap := MatchClock.final_opens_at(r) - MatchClock.warning_at(r)
	assert_eq(
		gap, int(r.finalphase_warning * RATE), "the warning is TUN-MATCH-FINALPHASE-WARNING early"
	)
	assert_gt(MatchClock.warning_at(r), 0, "the warning must fall inside ACTIVE, not before it")


func test_a_crossing_cannot_be_skipped_where_an_equality_can() -> void:
	# TDD-10 §6's sketch compares `ticks_remaining ==`. A clock that ever advances
	# by more than one — a catch-up after a hitch, a rejoin, a test stepping in
	# tens — steps straight over that and the warning never fires.
	assert_true(MatchClock.crossed(99, 100, 100), "landing exactly on it counts")
	assert_true(MatchClock.crossed(95, 105, 100), "stepping over it still counts")
	assert_false(MatchClock.crossed(100, 110, 100), "it fires once, not again")
	assert_false(MatchClock.crossed(80, 90, 100), "and not before")


func test_the_boundary_is_the_one_scoring_pays_at() -> void:
	# THE POINT OF THIS FILE. Swept across the whole @export_range band rather than
	# at the shipped value, because agreeing on one profile is what two independent
	# derivations already did.
	var r := _rules()
	var checked := 0
	for duration: float in [420.0, 450.0, 480.0, 540.0, 600.0]:
		for final_len: float in [20.0, 30.0, 45.0, 60.0]:
			r.duration = duration
			r.finalphase_duration = final_len
			var opens := MatchClock.final_opens_at(r)
			assert_eq(
				ScoreEvent.multiplier_at(opens, r),
				r.finalphase_mult,
				(
					"scoring must pay double from the tick the clock opens FINAL (%.0f/%.0f)"
					% [duration, final_len]
				)
			)
			assert_eq(
				ScoreEvent.multiplier_at(opens - 1, r),
				1.0,
				"and single on the tick before it (%.0f/%.0f)" % [duration, final_len]
			)
			checked += 1
	assert_eq(checked, 20, "the sweep must have run — an empty loop agrees with everything")


## **THE LOBBY HAS NO CLOCK AND `remaining` SAYS SO RATHER THAN ANSWERING ZERO.**
## Zero is a real reading everywhere else - it is the tick a phase runs out on - so a
## lobby that returned it would be indistinguishable from a match about to end.
func test_the_lobby_has_nothing_to_count_down() -> void:
	var rules := Tuning.match_rules
	assert_eq(
		MatchClock.remaining(MatchPhase.Phase.LOBBY, 0, rules),
		MatchClock.NO_CLOCK,
		"the lobby was given a countdown"
	)


## **`ACTIVE` AND `FINAL` ARE ONE COUNTDOWN, ASSERTED AT THE SEAM.** The last tick of
## `ACTIVE` and the first tick of `FINAL` are adjacent moments of one match, so the
## reading must fall by one across them - not jump back up to the Final Contract's
## own length, which is what a per-phase clock does and what a player reads as the
## timer gaining thirty seconds.
func test_the_two_halves_of_play_share_one_countdown() -> void:
	var rules := Tuning.match_rules
	var active := MatchClock.duration_ticks(MatchPhase.Phase.ACTIVE, rules)
	var last_of_active := MatchClock.remaining(MatchPhase.Phase.ACTIVE, active - 1, rules)
	var first_of_final := MatchClock.remaining(MatchPhase.Phase.FINAL, 0, rules)
	assert_eq(last_of_active - first_of_final, 1, "the match timer jumped at the boundary")
	assert_eq(
		MatchClock.remaining(MatchPhase.Phase.ACTIVE, 0, rules),
		MatchClock.ticks_of(rules.duration, rules),
		"the first tick of play did not read the whole match"
	)
