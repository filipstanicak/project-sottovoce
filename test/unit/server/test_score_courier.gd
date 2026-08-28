## **EVERY APPENDED EVENT REACHES ITS ACTOR, EXACTLY ONCE, AND THE DEATH MARKER
## REACHES NOBODY.** `NET-S2C-SCORE-EVENT`, never-do #12, US-0074.
##
## The courier is a **cursor over an append-only log** rather than a hook on each
## call site, and that choice is what this file is really about: two systems append
## today and ADR-0014's escape will be a third, so a wired-up list of call sites is
## a list that goes stale in silence. What can go wrong with a cursor instead is
## re-sending or skipping, and both are here.
extends GutTest

const A := 11
const B := 12

var _ctx: MatchContext
var _announcer: MatchAnnouncer

## **RESET IN `before_each`, WHICH IT WAS NOT AT FIRST.** GUT builds one instance
## per script, so a cursor left standing between tests starts the next one past
## everything it appends — and it reads exactly like a courier that skips.
var _cursor: int = 0


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.tick = 100
	_ctx.slots.assign(A)
	_ctx.slots.assign(B)
	_announcer = MatchAnnouncer.new(_ctx)
	_cursor = 0


func _append(kind: StringName, actor: int, subject: int, points: float = 100.0) -> ScoreEvent:
	return _ctx.score.append(
		ScoreAward.new(_ctx.tick, kind, actor, subject, points), Tuning.match_rules, 1
	)


## Who the courier would tell, over everything appended since the last drain.
func _drain() -> Array[int]:
	var told: Array[int] = []
	for event: ScoreEvent in _ctx.score.tail(_cursor):
		_cursor += 1
		var peer := _announcer.score_recipient(event)
		if peer != 0:
			told.append(peer)
	return told


func test_a_bonus_reaches_the_player_who_earned_it() -> void:
	# **THE PREMISE.** A courier that told nobody satisfies every "and nobody else"
	# assertion below perfectly.
	_append(Ids.SCORE_SILENT, A, B)
	assert_eq(_drain(), [A] as Array[int], "the bonus did not reach its actor")


func test_it_reaches_nobody_else() -> void:
	_append(Ids.SCORE_SILENT, A, B)
	assert_does_not_have(_drain(), B, "the victim was told what their killer scored")


func test_the_death_marker_is_withheld() -> void:
	# `ScoreLog.mark_death` records the victim as actor and the **killer** as
	# subject, so this is the only score event whose subject names somebody the
	# recipient has not earned. `NET-S2C-KILL-RESULT` is the message designed to
	# tell a victim who killed them.
	_ctx.score.mark_death(_ctx.tick, B, A, Tuning.match_rules, 1)
	assert_eq(_drain(), [] as Array[int], "the death marker went out")


func test_a_whole_kill_reaches_its_killer_and_the_death_reaches_nobody() -> void:
	var facts := KillScoreFacts.new()
	facts.tick = _ctx.tick
	facts.killer = A
	facts.victim = B
	facts.patient = true
	var group := _ctx.score.append_kill(
		ScoreBonuses.for_kill(facts, Tuning.scoring), Tuning.match_rules, Tuning.scoring
	)
	_ctx.score.mark_death(_ctx.tick, B, A, Tuning.match_rules, group)
	var told := _drain()
	assert_gt(told.size(), 2, "a patient kill produced fewer than three feed lines")
	for peer: int in told:
		assert_eq(peer, A, "somebody other than the killer was told")


func test_nothing_is_sent_twice() -> void:
	_append(Ids.SCORE_SILENT, A, B)
	assert_eq(_drain().size(), 1)
	assert_eq(_drain().size(), 0, "the cursor did not advance, so every event repeats forever")


func test_nothing_is_skipped_when_two_ticks_append() -> void:
	# The other half: a cursor that over-advanced would drop a bonus silently, and
	# the only symptom is a feed line that never appeared.
	_append(Ids.SCORE_SILENT, A, B)
	assert_eq(_drain().size(), 1)
	_ctx.tick += 1
	_append(Ids.SCORE_PATIENT, A, B)
	_append(Ids.SCORE_STUN, B, A)
	assert_eq(_drain(), [A, B] as Array[int], "a later tick's events were skipped")


func test_a_departed_actor_is_not_addressed() -> void:
	# A peer that left between the append and the drain has no wire slot, and
	# `SlotTable` hands slots out again — so addressing them would name whoever
	# inherited the slot. US-0037's lesson, one tick wide.
	_append(Ids.SCORE_SILENT, A, B)
	_ctx.slots.release(A)
	assert_eq(_drain(), [] as Array[int], "a departed player was still addressed")


func test_the_flush_takes_the_tick_signal_s_own_arguments() -> void:
	# **THE WIRING, NOT THE DECISION, AND THIS FILE ONCE TESTED ONLY THE SECOND.**
	# `MatchDirector.tick_completed(ctx, dt)` carries two arguments; a zero-argument
	# handler connects happily and fails at every emission. It cost a full
	# integration run to find, because every test here called `score_recipient`
	# directly and never the loop that the server actually connects.
	_append(Ids.SCORE_SILENT, A, B)
	_announcer.flush_score(_ctx, MatchContext.net_dt())
	assert_eq(_ctx.score.tail(0).size(), 1, "the fixture appended nothing")


func test_the_tail_is_a_cursor_rather_than_the_whole_log() -> void:
	for i: int in 5:
		_append(Ids.SCORE_SILENT, A, B, float(i))
	assert_eq(_ctx.score.tail(0).size(), 5)
	assert_eq(_ctx.score.tail(3).size(), 2)
	assert_eq(_ctx.score.tail(9).size(), 0, "a cursor past the end must not wrap")
