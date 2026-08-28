## **THE MULTIPLIER IS RESOLVED FROM THE EVENT'S OWN TICK, AT APPEND.** TDD-10
## §1.2, US-0064.
##
## The story's test note states the case exactly: *"a kill initiated pre-boundary
## and landing post-boundary scores at 1x"*. That is not a rounding decision, it is
## the same rule every bonus in this game already follows — **everything is judged
## at initiation** (TDD-10 §2), because that is the moment the player chose. A kill
## committed at 7:29.5 lands 0.9 s later by `TUN-KILL-CORPSE-SPAWN-DELAY`, and
## paying it double for the clock ticking over during an animation it could not
## cancel would reward waiting at the boundary rather than playing.
##
## Freezing also buys the fold its purity: with the multiplier on the event there
## is no clock to read at fold time.
extends GutTest

const KILLER := 3
const VICTIM := 4

var _m: MatchTuning
var _log: ScoreLog


func before_each() -> void:
	_m = Tuning.match_rules
	_log = ScoreLog.new()


func _opens_at() -> int:
	return int(ceil((_m.duration - _m.finalphase_duration) * _m.tick_rate))


func test_the_final_phase_is_a_real_window_in_this_match() -> void:
	# **THE PREMISE.** At a multiplier of 1.0, or a final phase of zero length,
	# every assertion below passes over a rule that does nothing.
	assert_gt(_m.finalphase_mult, 1.0, "TUN-MATCH-FINALPHASE-MULT does not multiply")
	assert_gt(_m.finalphase_duration, 0.0, "the final phase has no duration")
	assert_lt(_opens_at(), int(_m.duration * _m.tick_rate), "the final phase opens after the end")


func test_a_kill_initiated_before_the_boundary_scores_at_one_times() -> void:
	# The story's case. The press is one tick early; the contact frame is
	# `TUN-KILL-CORPSE-SPAWN-DELAY` later and comfortably inside the phase.
	var pressed := _opens_at() - 1
	var landed := pressed + Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY")
	assert_gt(landed, _opens_at(), "the fixture does not straddle the boundary")
	var event := _log.append(ScoreAward.new(pressed, Ids.SCORE_CONTRACT, KILLER, VICTIM, 100.0), _m)
	assert_eq(event.multiplier, 1.0, "a kill pressed before the boundary was doubled")
	assert_eq(event.points(), 100, "…and it paid double")


func test_a_kill_initiated_on_the_boundary_scores_at_the_multiplier() -> void:
	var event := _log.append(
		ScoreAward.new(_opens_at(), Ids.SCORE_CONTRACT, KILLER, VICTIM, 100.0), _m
	)
	assert_eq(event.multiplier, _m.finalphase_mult, "the first final-phase tick was not multiplied")
	assert_eq(event.points(), int(round(100.0 * _m.finalphase_mult)))


func test_the_boundary_is_derived_from_the_tunables_rather_than_stored() -> void:
	# Retuning either value must move the boundary, or the phase the HUD announces
	# and the phase the points are paid at drift apart.
	assert_eq(ScoreEvent.multiplier_at(_opens_at() - 1, _m), 1.0)
	assert_eq(ScoreEvent.multiplier_at(_opens_at(), _m), _m.finalphase_mult)
	assert_eq(ScoreEvent.multiplier_at(0, _m), 1.0, "the match opened in the final phase")


func test_the_fold_reads_no_clock() -> void:
	# **THE POINT OF FREEZING.** Two events with identical everything but their
	# tick must keep their own multipliers however often the log is folded — a fold
	# that resolved the phase itself would give the same answer to both.
	_log.append(ScoreAward.new(0, Ids.SCORE_CONTRACT, KILLER, VICTIM, 100.0), _m)
	_log.append(ScoreAward.new(_opens_at(), Ids.SCORE_CONTRACT, KILLER, VICTIM, 100.0), _m)
	var wanted := 100 + int(round(100.0 * _m.finalphase_mult))
	for _i: int in 3:
		assert_eq(ScoreFold.total_for(_log.events(), KILLER), wanted, "the fold is not stable")


func test_no_scoring_source_reads_a_clock() -> void:
	# The structural half. `Time`, `get_tree` and `OS` are the three routes to a
	# wall clock, and none of them may appear in a pure fold.
	for path: String in [
		"res://scripts/core/score/score_fold.gd",
		"res://scripts/core/score/score_event.gd",
		"res://scripts/core/score/score_log.gd",
	]:
		for term: String in ["Time.", "get_tree", "OS.", "Engine."]:
			assert_false(
				SourceScanner.code_contains(path, term), "%s reads `%s`" % [path.get_file(), term]
			)
