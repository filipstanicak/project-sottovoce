## **FOUR BONUSES FROM ONE KILL ARRIVE AS FOUR EVENTS, NOT AS ONE.** UI_UX_SPEC
## §5.1, GDD-06 §3.2, US-0074.
##
## The stagger is the cheapest high-value feedback in the project and it is a
## claim about *time*: four lines dropped together is one moment the eye cannot
## decompose, where the same four `TUN-UI-SCOREFEED-STAGGER` 0.12 s apart are four
## moments, each individually readable — and paired with the audio pitching up per
## position (US-0075) a four-bonus kill ascends.
extends GutTest

const STEP := 1.0 / 60.0

var _vm: ScoreFeedVm


func before_each() -> void:
	_vm = ScoreFeedVm.new()


func _report(kind: StringName, points: int, group: int = 1) -> void:
	_vm.report(ScoreReport.new(kind, points, group))


func _run(seconds: float) -> void:
	for _i: int in int(round(seconds / STEP)):
		_vm.update(STEP)


func _kill() -> void:
	_report(Ids.SCORE_CONTRACT, 100)
	_report(Ids.SCORE_SILENT, 200)
	_report(Ids.SCORE_PATIENT, 100)
	_report(Ids.SCORE_BLENDED, 200)


func test_the_first_line_of_a_kill_shows_immediately() -> void:
	# **THE PREMISE.** Every assertion below about a delay is satisfied by a feed
	# that shows nothing at all, which is the commonest way a timing test passes
	# wrongly.
	_kill()
	_vm.update(STEP)
	assert_eq(_vm.lines.size(), 1, "the first bonus of a kill did not arrive at once")


func test_four_bonuses_arrive_one_stagger_apart() -> void:
	var stagger := Tuning.ui_audio.scorefeed_stagger
	_kill()
	_vm.update(STEP)
	for expected: int in [2, 3, 4]:
		_run(stagger)
		assert_eq(_vm.lines.size(), expected, "line %d did not arrive one stagger later" % expected)


func test_they_do_not_all_arrive_at_once() -> void:
	# The counterfactual for the test above: a stagger of zero satisfies "four lines
	# eventually" perfectly.
	_kill()
	_run(Tuning.ui_audio.scorefeed_stagger * 0.5)
	assert_eq(_vm.lines.size(), 1, "the whole kill landed inside half a stagger")


func test_they_arrive_in_the_order_they_were_paid() -> void:
	# `ScoreBonuses.for_kill` returns awards in feed order and the log preserves it.
	# A queue that reordered would teach the wrong sequence — Contract before the
	# tier rung is the reading GDD-06 §3.3 builds its teaching sequence on.
	_kill()
	_run(Tuning.ui_audio.scorefeed_stagger * 4.0)
	var names: Array[StringName] = []
	for line: ScoreFeedVm.Line in _vm.lines:
		names.append(line.key)
	assert_eq(
		names,
		(
			[&"bonus.contract", &"bonus.silent", &"bonus.patient", &"bonus.blended"]
			as Array[StringName]
		)
	)


func test_two_kills_stagger_independently() -> void:
	# **THE GROUP IS THE UNIT, NOT THE FEED.** Counting across groups would push a
	# second kill's first line behind the first kill's stack — so a player who kills
	# twice in six seconds would see the second kill start late, worse the more
	# bonuses the first one paid.
	_report(Ids.SCORE_CONTRACT, 100, 1)
	_report(Ids.SCORE_SILENT, 200, 1)
	_report(Ids.SCORE_STUN, 100, 2)
	_vm.update(STEP)
	assert_eq(_vm.lines.size(), 2, "the second group's first line waited on the first group")


func test_a_penalty_is_marked_and_a_zero_is_not() -> void:
	# §5.2: the one negative event must not read as a smaller positive one. And
	# `SCORE-RECKLESS` pays **zero** since ADR-0013 — a marker, not a fine — so it
	# must not be dressed as a penalty either.
	_report(Ids.SCORE_RECKLESS, 0)
	_report(Ids.SCORE_DEATH, -25, 2)
	_run(Tuning.ui_audio.scorefeed_stagger * 2.0)
	assert_eq(_vm.lines.size(), 2)
	assert_false(_vm.lines[0].penalty, "a zero-point marker was drawn as a penalty")
	assert_true(_vm.lines[1].penalty, "a negative award was not marked as a penalty")


func test_a_kind_with_no_name_is_dropped_rather_than_drawn_as_its_id() -> void:
	# `Strings.get_text` returns the key on a miss so a gap is visible in a
	# screenshot — right everywhere else and wrong here, because this element
	# teaches vocabulary and `bonus.nonesuch` reads as a bonus called that.
	_report(&"SCORE-NONESUCH", 100)
	_vm.update(STEP)
	assert_eq(_vm.lines.size(), 0, "an unnamed kind reached the feed")
	assert_push_error_count(1, "a bonus with no name must be logged, not swallowed")


func test_an_unknown_byte_from_a_newer_server_is_dropped() -> void:
	# `ScoreKinds.from_byte` answers `&""` outside its range rather than guessing.
	_vm.report(ScoreReport.new(ScoreKinds.from_byte(200), 100, 1))
	_vm.update(STEP)
	assert_eq(_vm.lines.size(), 0, "an unknown kind reached the feed")
