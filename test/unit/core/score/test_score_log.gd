## **APPEND-ONLY, AND IMMUTABLE ONCE APPENDED.** ADR-0004, TDD-10 §1, US-0064.
##
## Two of this story's criteria are properties of the engine rather than of a
## comment — *"ScoreEvent is immutable, no setter, no mutating method"* and
## *"`ScoreLog.append` is the only entry point"* — so they are asserted by trying
## to break them rather than by scanning for the word `const`.
extends GutTest

const ACTOR := 5
const OTHER := 6

var _m: MatchTuning
var _log: ScoreLog


func before_each() -> void:
	_m = Tuning.match_rules
	_log = ScoreLog.new()


func _add(kind: StringName, actor: int, points: float, at: int = 100) -> ScoreEvent:
	return _log.append(ScoreAward.new(at, kind, actor, 0, points), _m)


# ---------------------------------------------------------- immutability ---


func test_an_event_refuses_to_be_rewritten() -> void:
	# Every field is a getter-only property, so `event.tick = 9` does not compile
	# and `set()` is silently refused. **Asserted through `set()` because that is
	# the only route the engine leaves open** — the direct assignment a careless
	# commit would write is a parse error, which no test can reach.
	var event := _add(Ids.SCORE_CONTRACT, ACTOR, 100.0)
	for field: String in ["event_id", "tick", "kind", "actor_id", "base_points", "multiplier"]:
		var before: Variant = event.get(field)
		event.set(field, 999)
		assert_eq(
			event.get(field), before, "ScoreEvent.%s was rewritten after construction" % field
		)


func test_the_event_exposes_no_setter_and_no_mutator() -> void:
	# The source half, aimed at the shape rather than at a word: a `set(` block on
	# a property, or any method whose name says it changes something.
	var source := "res://scripts/core/score/score_event.gd"
	assert_gt(SourceScanner.read(source).length(), 500, "score_event.gd did not load")
	for term: String in ["set(", "func set_", "func clear", "func reset"]:
		assert_false(SourceScanner.code_contains(source, term), "ScoreEvent gained `%s`" % term)


func test_the_log_hands_out_a_copy_rather_than_itself() -> void:
	# **OTHERWISE "APPEND-ONLY" IS A DOCSTRING.** A caller holding the real array
	# could `clear()` it, and the symptom would be a scoreboard that empties
	# halfway through a match with nothing anywhere reporting it.
	_add(Ids.SCORE_CONTRACT, ACTOR, 100.0)
	var taken := _log.events()
	taken.clear()
	assert_eq(_log.size(), 1, "clearing the returned array emptied the log")
	assert_eq(ScoreFold.total_for(_log.events(), ACTOR), 100)


# ----------------------------------------------------------- the append ---


func test_ids_are_monotonic_and_never_reused() -> void:
	var seen: Dictionary = {}
	for i: int in 20:
		var event := _add(Ids.SCORE_CONTRACT, ACTOR, 100.0)
		assert_false(seen.has(event.event_id), "event id %d was reused" % event.event_id)
		seen[event.event_id] = true
		assert_eq(event.event_id, i + 1, "ids are not monotonic")


func test_points_are_rounded_once_in_the_log() -> void:
	# Every `TUN-SCORE-` value is a float and every event carries an int. A second
	# call site rounding its own way is a scoreboard one point from a breakdown.
	var event := _add(Ids.SCORE_CONTRACT, ACTOR, 100.6)
	assert_eq(event.base_points, 101, "the log did not round")
	assert_eq(event.points(), 101)


func test_groups_are_handed_out_once_each() -> void:
	assert_ne(_log.open_group(), _log.open_group(), "two kills got the same group")


# ------------------------------------------------------- lives and death ---


func test_a_death_marker_is_a_real_event_worth_nothing() -> void:
	_log.mark_death(100, ACTOR, OTHER, _m)
	assert_eq(_log.size(), 1, "the death marker was not recorded")
	assert_eq(ScoreFold.total_for(_log.events(), ACTOR), 0, "dying cost or paid points")
	assert_eq(ScoreFold.deaths_of(_log.events(), ACTOR), 1)
	assert_eq(ScoreFold.deaths_of(_log.events(), OTHER), 0, "the killer was counted as dead")


func test_death_markers_delimit_lives() -> void:
	# **WHAT `SCORE-VARIETY` COUNTS OVER** (TDD-10 §1.4). The query is this story's;
	# the bonus is US-0065's.
	_add(Ids.SCORE_CONTRACT, ACTOR, 100.0)
	_add(Ids.SCORE_SILENT, ACTOR, 200.0)
	_log.mark_death(200, ACTOR, OTHER, _m)
	_add(Ids.SCORE_CONTRACT, ACTOR, 100.0)
	var life := ScoreFold.since_last_death(_log.events(), ACTOR)
	assert_eq(life.size(), 1, "the current life carried events from the previous one")
	assert_eq(life[0].kind, Ids.SCORE_CONTRACT)


func test_another_players_death_does_not_end_your_life() -> void:
	# The counterfactual. Keyed on the actor, so a marker for somebody else must
	# leave your life untouched — otherwise Variety would reset on every kill in
	# the match and pay a flat bonus forever.
	_add(Ids.SCORE_SILENT, ACTOR, 200.0)
	_log.mark_death(200, OTHER, ACTOR, _m)
	assert_eq(ScoreFold.since_last_death(_log.events(), ACTOR).size(), 1, "somebody else's death")


func test_a_death_is_recorded_against_the_victim_not_the_killer() -> void:
	var event := _log.mark_death(150, ACTOR, OTHER, _m)
	assert_eq(event.actor_id, ACTOR, "the death was filed under the killer")
	assert_eq(event.subject_id, OTHER, "the death does not record who did it")
