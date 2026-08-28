## **NEVER MORE THAN `TUN-UI-SCOREFEED-MAX-LINES`, AND EACH LINE LIVES EXACTLY
## `TUN-UI-SCOREFEED-DURATION`.** UI_UX_SPEC §5, GDD-01 §5, US-0074.
##
## GDD-01 §5 names the failure this cap exists for — *"the subtle break"*: a player
## receiving a prey warning, a Compass acceleration and three score-feed lines
## simultaneously is receiving nothing. The cap and the audio ducking rules are the
## two things enforcing a priority order on attention.
extends GutTest

const STEP := 1.0 / 60.0

var _vm: ScoreFeedVm


func before_each() -> void:
	_vm = ScoreFeedVm.new()


func _run(seconds: float) -> void:
	for _i: int in int(round(seconds / STEP)):
		_vm.update(STEP)


## `n` awards in their own groups, so every one is shown the instant it is told
## and the cap is tested rather than the stagger.
func _flood(n: int) -> void:
	for i: int in n:
		_vm.report(ScoreReport.new(Ids.SCORE_CONTRACT, 100 + i, i + 1))
	_vm.update(STEP)


func test_the_feed_fills_to_the_cap() -> void:
	# **THE PREMISE**, and it is the one a cap test most needs: a feed that showed
	# nothing would satisfy every "never more than four" assertion below.
	_flood(Tuning.ui_audio.scorefeed_max_lines)
	assert_eq(_vm.lines.size(), Tuning.ui_audio.scorefeed_max_lines, "the feed did not fill")


func test_it_never_exceeds_the_cap() -> void:
	_flood(Tuning.ui_audio.scorefeed_max_lines + 6)
	assert_eq(_vm.lines.size(), Tuning.ui_audio.scorefeed_max_lines, "the cap was exceeded")


func test_the_oldest_is_dropped_and_never_the_newest() -> void:
	# **DROPPING THE NEWEST WOULD BE CHEAPER AND WOULD DELETE THE BONUS THE PLAYER
	# IS LOOKING FOR.** They just earned it; the one four lines back they have read.
	var most := Tuning.ui_audio.scorefeed_max_lines
	_flood(most + 1)
	assert_eq(_vm.lines.size(), most)
	assert_eq(_vm.lines.back().points, 100 + most, "the newest line was the one dropped")
	assert_eq(_vm.lines[0].points, 101, "the oldest line survived the cap")


func test_a_line_persists_for_the_full_duration() -> void:
	_flood(1)
	_run(Tuning.ui_audio.scorefeed_duration * 0.9)
	assert_eq(_vm.lines.size(), 1, "a line expired inside its own duration")


func test_a_line_expires_after_it() -> void:
	_flood(1)
	_run(Tuning.ui_audio.scorefeed_duration + 0.1)
	assert_eq(_vm.lines.size(), 0, "a line outlived TUN-UI-SCOREFEED-DURATION")


func test_the_lifetime_starts_when_the_line_is_shown_not_when_it_was_told() -> void:
	# **THE HALF A STAGGERED FEED GETS WRONG.** The fourth bonus of a kill is told
	# at the same instant as the first and shown 0.36 s later; measured from telling,
	# it would be readable for 3.64 s rather than 4.0 — and the later a line, the
	# less time to read it, which is backwards for a stack that ascends.
	var stagger := Tuning.ui_audio.scorefeed_stagger
	for i: int in 4:
		_vm.report(ScoreReport.new(Ids.SCORE_CONTRACT, 100 + i, 1))
	_run(stagger * 3.0 + Tuning.ui_audio.scorefeed_duration - 0.05)
	assert_eq(_vm.lines.size(), 1, "the last line of the kill did not get its full duration")
	assert_eq(_vm.lines[0].points, 103, "the wrong line survived")
	_run(0.1)
	assert_eq(_vm.lines.size(), 0, "the last line outlived its own duration")


func test_a_promoted_line_pushes_rather_than_being_dropped() -> void:
	# The ordering inside `update`: promote, expire, cap. Capping before promoting
	# would drop a line that had waited out its stagger and never draw it at all.
	var most := Tuning.ui_audio.scorefeed_max_lines
	_flood(most)
	_vm.report(ScoreReport.new(Ids.SCORE_SILENT, 999, 99))
	_vm.update(STEP)
	assert_eq(_vm.lines.size(), most)
	assert_eq(_vm.lines.back().points, 999, "the promoted line was capped away before it drew")


func test_nothing_arrives_without_a_report() -> void:
	_run(2.0)
	assert_eq(_vm.lines.size(), 0, "the feed invented a line")
