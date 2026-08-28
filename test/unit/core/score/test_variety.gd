## **`SCORE-VARIETY` COUNTS WHAT YOU HAVE NOT DONE THIS LIFE.** TDD-10 §1.4,
## GDD-07 §3.1, US-0065.
##
## The one bonus the fold cannot do, because it counts against the events **already
## in the log** — so it is computed at append time and `ScoreLog` is where it lives.
##
## **AND GDD-07 §3.1's OPEN FINDING IS ASSERTED HERE RATHER THAN QUIETLY FIXED.**
## At the modelled ~1.0 kills per life every bonus on a kill is necessarily "first
## time this life", so Variety currently behaves as a flat +50 per bonus type
## rather than as a reward for varying your approach. The recommended fix — reset
## on **contract** instead of on death — is one call away and is gated on
## `TEL-KILLS-PER-LIFE`, which does not exist. `test_the_finding_is_still_true`
## goes red the day somebody changes it, which is the point.
extends GutTest

const ACTOR := 21
const VICTIM := 22

var _log: ScoreLog
var _m: MatchTuning
var _s: ScoringTuning


func before_each() -> void:
	_log = ScoreLog.new()
	_m = Tuning.match_rules
	_s = Tuning.scoring


func _kill(kinds: Array) -> void:
	var awards: Array[ScoreAward] = []
	for kind: StringName in kinds:
		awards.append(ScoreAward.new(100, kind, ACTOR, VICTIM, 100.0))
	_log.append_kill(awards, _m, _s)


func _variety_paid() -> int:
	return int(ScoreFold.breakdown(_log.events(), ACTOR).get(Ids.SCORE_VARIETY, 0))


func test_a_first_kill_pays_for_every_countable_type() -> void:
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT, Ids.SCORE_PATIENT])
	assert_eq(_variety_paid(), int(round(_s.variety)) * 2, "Silent and Patient are two new types")


func test_repeating_the_same_approach_pays_nothing() -> void:
	# **THE BONUS'S ENTIRE REASON TO EXIST.** Two identical kills in one life is one
	# approach performed twice.
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT, Ids.SCORE_PATIENT])
	var after_one := _variety_paid()
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT, Ids.SCORE_PATIENT])
	assert_eq(_variety_paid(), after_one, "the same approach was paid for twice")


func test_a_different_approach_pays_for_the_difference_only() -> void:
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT])
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT, Ids.SCORE_BLENDED, Ids.SCORE_FOCUS])
	assert_eq(_variety_paid(), int(round(_s.variety)) * 3, "1 new + 2 new is three, not four")


func test_itself_contract_and_reckless_are_excluded() -> void:
	# ASM-0017. Contract is on every kill, so counting it would pay a flat 50 for
	# existing; Reckless is a marker worth nothing, so counting it would pay for
	# carelessness; itself would compound.
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_RECKLESS])
	assert_eq(_variety_paid(), 0, "an excluded kind was counted as variety")


func test_a_death_starts_the_count_again() -> void:
	# The life boundary is a `SCORE-DEATH` marker (TDD-10 §1.4) — a real event with
	# real semantics, and this is what reads it.
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT, Ids.SCORE_PATIENT])
	var after_one := _variety_paid()
	_log.mark_death(300, ACTOR, VICTIM, _m)
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT, Ids.SCORE_PATIENT])
	assert_eq(_variety_paid(), after_one * 2, "a death did not reset the count")


func test_somebody_elses_death_does_not_reset_your_count() -> void:
	# The counterfactual. Keyed on the actor — otherwise every kill in the match
	# would reset every player's count and Variety would be a flat bonus forever.
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT])
	var after_one := _variety_paid()
	_log.mark_death(300, VICTIM, ACTOR, _m)
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT])
	assert_eq(_variety_paid(), after_one, "another player's death reset this player's count")


func test_it_is_paid_as_one_event_rather_than_n() -> void:
	# The feed draws a kill as one line with a breakdown, and `n` identical lines
	# saying +50 would be the breakdown lying about what happened.
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT, Ids.SCORE_PATIENT, Ids.SCORE_FOCUS])
	var events := 0
	for event: ScoreEvent in _log.events():
		if event.kind == Ids.SCORE_VARIETY:
			events += 1
	assert_eq(events, 1, "Variety was paid as %d events" % events)
	assert_eq(_variety_paid(), int(round(_s.variety)) * 3)


func test_the_whole_kill_shares_one_group() -> void:
	var group := _log.append_kill(
		(
			[
				ScoreAward.new(100, Ids.SCORE_CONTRACT, ACTOR, VICTIM, 100.0),
				ScoreAward.new(100, Ids.SCORE_SILENT, ACTOR, VICTIM, 200.0)
			]
			as Array[ScoreAward]
		),
		_m,
		_s
	)
	assert_eq(ScoreFold.group(_log.events(), group).size(), 3, "Variety left the kill's group")


func test_an_empty_kill_appends_nothing() -> void:
	assert_eq(_log.append_kill([] as Array[ScoreAward], _m, _s), 0)
	assert_eq(_log.size(), 0, "a kill with no awards still wrote to the log")


func test_the_finding_is_still_true() -> void:
	# **GDD-07 §3.1's OPEN FINDING, ASSERTED SO IT CANNOT BE FIXED BY ACCIDENT.**
	# At one kill per life every bonus is "first time this life", so Variety is a
	# flat uplift. This is what the recommended change — counting since the last
	# *contract* rather than the last *death* — would turn red, which is exactly
	# what should happen: it is a design decision gated on telemetry that does not
	# exist, not a bug to be tidied.
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT, Ids.SCORE_PATIENT])
	_log.mark_death(300, ACTOR, VICTIM, _m)
	_kill([Ids.SCORE_CONTRACT, Ids.SCORE_SILENT, Ids.SCORE_PATIENT])
	assert_eq(
		_variety_paid(),
		int(round(_s.variety)) * 4,
		"Variety no longer resets on death — see GDD-07 §3.1 before making this pass"
	)
