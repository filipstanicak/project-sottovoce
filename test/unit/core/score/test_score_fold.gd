## **GDD-07 §3.2's SEVEN REFERENCE KILLS, REPRODUCED FROM THE FOLD ALONE.**
## US-0064, TDD-10 §1.3.
##
## The story's own test note: *"reproduces every reference value in GDD-07 §3.2
## exactly"*. Those seven rows are the published statement of what this game pays
## for what, and 750 is the reference title's own worked example arrived at
## independently — so a fold that disagrees with the table is either a broken fold
## or a stale table, and both are worth a red run.
##
## **NOTHING STANDS UP.** No server, no autoload but `Tuning`, no clock. That is
## the whole argument for event sourcing in TDD-10 §1.3: the most bug-prone part of
## the design becomes the part a test can hold in its hand.
extends GutTest

const KILLER := 11
const VICTIM := 22

var _s: ScoringTuning
var _m: MatchTuning
var _log: ScoreLog


func before_each() -> void:
	_s = Tuning.scoring
	_m = Tuning.match_rules
	_log = ScoreLog.new()


## One kill's worth of bonuses, at a tick well inside the ordinary phase.
func _kill(kinds: Array) -> void:
	var group := _log.open_group()
	for row: Array in kinds:
		_log.append(
			ScoreAward.new(100, row[0] as StringName, KILLER, VICTIM, float(row[1])), _m, group
		)


func _total() -> int:
	return ScoreFold.total_for(_log.events(), KILLER)


# ---------------------------------------------- GDD-07 §3.2, row by row ---


func test_a_sprinting_tackle_while_exposed_pays_one_base_kill() -> void:
	# **THE ROW THAT MOVED MOST IN ADR-0013.** `SCORE-RECKLESS` is 0 now, not −50:
	# the reference under-pays carelessness rather than charging for it, and
	# converging on it made this game *less* punishing of aggression, not more.
	_kill([[Ids.SCORE_CONTRACT, _s.contract], [Ids.SCORE_RECKLESS, _s.reckless]])
	assert_eq(_total(), 100, "sprinting tackle while Exposed")


func test_careless_but_not_exposed_pays_one_base_kill() -> void:
	_kill([[Ids.SCORE_CONTRACT, _s.contract]])
	assert_eq(_total(), 100, "careless but not Exposed")


func test_a_clean_walk_up_pays_four_hundred() -> void:
	# Silent 200 + Patient 100 is the pair that sums to the reference's top stealth
	# rung, split across an instantaneous half and a sustained one.
	_kill(
		[
			[Ids.SCORE_CONTRACT, _s.contract],
			[Ids.SCORE_SILENT, _s.silent],
			[Ids.SCORE_PATIENT, _s.patient],
		]
	)
	assert_eq(_total(), 400, "clean walk-up")


func test_watched_waited_struck_pays_five_hundred_and_fifty() -> void:
	_kill(
		[
			[Ids.SCORE_CONTRACT, _s.contract],
			[Ids.SCORE_SILENT, _s.silent],
			[Ids.SCORE_PATIENT, _s.patient],
			[Ids.SCORE_FOCUS, _s.focus],
		]
	)
	assert_eq(_total(), 550, "watched, waited, struck")


func test_the_full_patient_blend_kill_pays_seven_hundred_and_fifty() -> void:
	# **THE REFERENCE'S OWN PUBLISHED EXAMPLE, REACHED BY A DIFFERENT SPLIT.** Its
	# combination is 100 + 300 + 200 + 150; ours is 100 + (200 + 100) + 200 + 150.
	_kill(_the_perfect_kill())
	assert_eq(_total(), 750, "the full patient blend kill")


func test_variety_on_five_new_types_takes_it_to_a_thousand() -> void:
	var kinds := _the_perfect_kill()
	for _i: int in 5:
		kinds.append([Ids.SCORE_VARIETY, _s.variety])
	_kill(kinds)
	assert_eq(_total(), 1000, "…with Variety on five new types")


func test_the_final_phase_doubles_the_whole_kill() -> void:
	# **FROZEN AT APPEND, SO THE FOLD NEVER SEES A CLOCK.** Every event of this kill
	# was stamped inside the final phase, so every one carries the multiplier.
	var kinds := _the_perfect_kill()
	for _i: int in 5:
		kinds.append([Ids.SCORE_VARIETY, _s.variety])
	var group := _log.open_group()
	for row: Array in kinds:
		_log.append(
			ScoreAward.new(
				_first_final_tick(), row[0] as StringName, KILLER, VICTIM, float(row[1])
			),
			_m,
			group
		)
	assert_eq(_total(), 2000, "…in the Final Contract phase")


# ------------------------------------------------------------ the fold ---


func test_the_scoreboard_separates_actors() -> void:
	# The premise: a fold that summed everything into one bucket would satisfy
	# every row above, because every row above has one actor.
	_kill([[Ids.SCORE_CONTRACT, _s.contract]])
	_log.append(ScoreAward.new(100, Ids.SCORE_STUN, VICTIM, KILLER, _s.stun), _m)
	var totals := ScoreFold.fold(_log.events())
	assert_eq(int(totals[KILLER]), int(_s.contract), "the killer's total absorbed other points")
	assert_eq(int(totals[VICTIM]), int(_s.stun), "the stunner scored nothing")


func test_the_breakdown_sums_to_the_total() -> void:
	# **THE DEFECT TDD-10 §1.1 NAMES BY NAME**: a results screen that adds up to a
	# different number from the scoreboard. Here they are two folds over one log,
	# so this can only fail if one of them stops folding.
	var kinds := _the_perfect_kill()
	kinds.append([Ids.SCORE_VARIETY, _s.variety])
	_kill(kinds)
	var parts := ScoreFold.breakdown(_log.events(), KILLER)
	var summed := 0
	for kind: StringName in parts:
		summed += int(parts[kind])
	assert_eq(summed, _total(), "the breakdown does not add up to the scoreboard")
	assert_eq(parts.size(), 6, "the breakdown lost or invented a kind")


func test_two_rungs_of_one_kind_are_summed_rather_than_counted() -> void:
	# `SCORE-LONGHUNT` pays two different amounts under one id, and Variety pays
	# once per new type. A breakdown that counted occurrences would show a player a
	# number that is not in their total.
	_kill([[Ids.SCORE_VARIETY, _s.variety], [Ids.SCORE_VARIETY, _s.variety]])
	var parts := ScoreFold.breakdown(_log.events(), KILLER)
	assert_eq(int(parts[Ids.SCORE_VARIETY]), int(round(_s.variety)) * 2, "two rungs were counted")


func test_a_group_is_one_kill() -> void:
	_kill([[Ids.SCORE_CONTRACT, _s.contract]])
	_kill([[Ids.SCORE_CONTRACT, _s.contract], [Ids.SCORE_SILENT, _s.silent]])
	assert_eq(ScoreFold.group(_log.events(), 1).size(), 1, "the first kill's group is wrong")
	assert_eq(ScoreFold.group(_log.events(), 2).size(), 2, "the second kill's group is wrong")


func test_an_empty_log_scores_nobody_anything() -> void:
	assert_eq(ScoreFold.fold([] as Array[ScoreEvent]).size(), 0)
	assert_eq(ScoreFold.total_for([] as Array[ScoreEvent], KILLER), 0)


## GDD-07 §3.2's "full patient blend kill": 100 + 200 + 100 + 200 + 150.
func _the_perfect_kill() -> Array:
	return [
		[Ids.SCORE_CONTRACT, _s.contract],
		[Ids.SCORE_SILENT, _s.silent],
		[Ids.SCORE_PATIENT, _s.patient],
		[Ids.SCORE_BLENDED, _s.blended],
		[Ids.SCORE_FOCUS, _s.focus],
	]


## The first tick at which `TUN-MATCH-FINALPHASE-MULT` applies, derived rather
## than written down, so retuning the phase moves the test with the game.
func _first_final_tick() -> int:
	return int(ceil((_m.duration - _m.finalphase_duration) * _m.tick_rate))
