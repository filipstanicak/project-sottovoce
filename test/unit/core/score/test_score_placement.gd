## **WHAT PLACE, AND WHAT A TIE MEANS.** US-0077.
##
## The rule is standard competition ranking — 1, 1, 3 — and the argument for it is in
## `ScorePlacement`'s own docstring: a tie-break is a scoring rule invented at the
## results screen, and this game is decided by score. What this file asserts is that
## the arithmetic actually does that, including the two cases a hand-written ranking
## loop gets wrong: the place **after** a tie, and a player the log never mentions.
extends GutTest

var _rules: MatchTuning
var _next_id: int = 1


func before_each() -> void:
	_rules = MatchTuning.new()
	_rules.tick_rate = 30.0
	_rules.duration = 480.0
	_rules.finalphase_duration = 30.0
	_rules.finalphase_mult = 2.0
	_next_id = 1


## One award of `points` to `slot`, at tick 0 so no multiplier is in play — this file
## is about ordering, and `test_match_end_wire.gd` owns the multiplier.
func _award(slot: int, points: int) -> ScoreEvent:
	var event := ScoreEvent.new(
		_next_id, ScoreAward.new(0, Ids.SCORE_CONTRACT, slot, 0, float(points)), _rules
	)
	_next_id += 1
	return event


func _log(pairs: Array) -> Array[ScoreEvent]:
	var out: Array[ScoreEvent] = []
	for pair: Array in pairs:
		out.append(_award(int(pair[0]), int(pair[1])))
	return out


func _places(rows: Array) -> Array:
	var out: Array = []
	for row: Dictionary in rows:
		out.append(int(row["place"]))
	return out


func _slots(rows: Array) -> Array:
	var out: Array = []
	for row: Dictionary in rows:
		out.append(int(row["slot"]))
	return out


func test_the_fixture_actually_scores() -> void:
	# **THE PREMISE.** Every assertion below ranks this log; an all-zero one would
	# make the whole file agree with any ordering at all.
	var rows := ScorePlacement.standings(_log([[1, 300], [2, 100]]), [1, 2])
	assert_eq(int((rows[0] as Dictionary)["points"]), 300, "the fixture scored nothing")


func test_the_highest_total_is_first() -> void:
	var rows := ScorePlacement.standings(_log([[1, 100], [2, 700], [3, 400]]), [1, 2, 3])
	assert_eq(_slots(rows), [2, 3, 1], "the standings are not in score order")
	assert_eq(_places(rows), [1, 2, 3], "three distinct totals did not produce three places")


## **THE RULE CODEX ASKED FOR, ASSERTED.** Two players on the same total share first,
## and the next player is **third** — not second.
func test_a_tie_shares_the_place_and_the_next_one_skips() -> void:
	var rows := ScorePlacement.standings(_log([[1, 500], [2, 500], [3, 200]]), [1, 2, 3])
	assert_eq(_places(rows), [1, 1, 3], "the tie did not produce 1, 1, 3")


## The same rule one rung down, which is where an incrementing counter breaks: the
## place after a *middle* tie must skip as well.
func test_a_tie_in_the_middle_skips_too() -> void:
	var rows := ScorePlacement.standings(
		_log([[1, 900], [2, 500], [3, 500], [4, 100]]), [1, 2, 3, 4]
	)
	assert_eq(_places(rows), [1, 2, 2, 4], "a mid-table tie did not skip the place after it")


func test_a_whole_lobby_on_the_same_total_all_share_first() -> void:
	var rows := ScorePlacement.standings(_log([[1, 300], [2, 300], [3, 300]]), [1, 2, 3])
	assert_eq(_places(rows), [1, 1, 1], "three equal totals did not all share first")


## **A PLAYER THE LOG NEVER MENTIONS IS STILL IN THE MATCH.** `ScoreFold` only knows
## about actors who earned something; somebody who died six times and scored nothing
## has no event at all, and a standings table built from the events alone would drop
## them off the screen entirely.
func test_a_player_who_scored_nothing_still_places_last() -> void:
	var rows := ScorePlacement.standings(_log([[1, 400], [2, 200]]), [1, 2, 3])
	assert_eq(rows.size(), 3, "the player who scored nothing is not on the screen")
	assert_eq(int((rows[2] as Dictionary)["slot"]), 3, "the scoreless player is not last")
	assert_eq(int((rows[2] as Dictionary)["points"]), 0, "the scoreless player was given points")
	assert_eq(int((rows[2] as Dictionary)["place"]), 3, "the scoreless player has no place")


func test_an_empty_match_ranks_nobody() -> void:
	assert_eq(
		ScorePlacement.standings([] as Array[ScoreEvent], []).size(), 0, "ranked nobody as somebody"
	)


## **THE ORDER WITHIN A TIE IS STABLE, WHICH IS WHAT LETS BOTH SIDES DRAW THE SAME
## LIST.** The place is what is equal; the rows still have to be drawn in some order,
## and if the two peers chose differently the same screen would list two orders.
func test_tied_rows_come_back_in_slot_order() -> void:
	var rows := ScorePlacement.standings(_log([[5, 100], [2, 100], [9, 100]]), [9, 5, 2])
	assert_eq(_slots(rows), [2, 5, 9], "a tie group is not ordered by slot")


## The client folds the same events out of `MatchEndWire`, so this is the property
## that matters more than any single ordering: **the same inputs give the same list.**
func test_the_same_log_ranks_identically_however_the_roster_is_ordered() -> void:
	var events := _log([[1, 400], [2, 400], [3, 900]])
	var forwards := ScorePlacement.standings(events, [1, 2, 3])
	var backwards := ScorePlacement.standings(events, [3, 2, 1])
	assert_eq(_slots(forwards), _slots(backwards), "the roster's order changed the standings")
	assert_eq(_places(forwards), _places(backwards), "the roster's order changed the places")


func test_place_for_answers_zero_for_a_stranger() -> void:
	var events := _log([[1, 400]])
	assert_eq(ScorePlacement.place_for(events, [1, 2], 2), 2, "a real player has no place")
	assert_eq(
		ScorePlacement.place_for(events, [1, 2], 77),
		0,
		"a slot that was not in the match was given a place — 1, if a lookup defaulted"
	)


## **THE SCREEN HAS TO KNOW WHETHER ANYBODY WON.** A winner's treatment applied to two
## players reads as a bug; applied to neither, as a screen that forgot to say who won.
func test_a_shared_win_is_reported_as_one() -> void:
	assert_true(
		ScorePlacement.is_shared_win(_log([[1, 500], [2, 500]]), [1, 2]),
		"two players on the top score were not reported as a shared win"
	)
	assert_false(
		ScorePlacement.is_shared_win(_log([[1, 500], [2, 400]]), [1, 2]),
		"a clear winner was reported as a shared one"
	)
	assert_false(
		ScorePlacement.is_shared_win(_log([[1, 500]]), [1]),
		"a lobby of one shares its win with nobody"
	)
