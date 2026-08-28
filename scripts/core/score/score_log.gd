## **THE APPEND-ONLY LOG. THE ONLY WAY POINTS ENTER THE GAME.** ADR-0004,
## TDD-10 §1, US-0064.
##
## Server-owned: it lives on `MatchContext` beside `CombatLockouts` and
## `SuspicionImpulses`, and is adopted by reference rather than mirrored, so no
## second copy can drift. **Nothing client-side may hold one** —
## `test_score_no_direct_mutation.gd` refuses any mention under `presentation/`,
## `mirrors/` or `pawn/`.
##
## **`append` IS THE ONLY ENTRY POINT, AND IT IS THE ONLY PLACE POINTS ARE
## ROUNDED.** Every `TUN-SCORE-` value is a float and every event carries an int,
## so a second call site rounding its own way is a scoreboard that disagrees with
## a breakdown by one point — the exact class of defect TDD-10 §1.1 is about.
##
## ~40 bytes an event and about 600 events a match, so there is no pruning and no
## budget to think about.
class_name ScoreLog
extends RefCounted

var _events: Array[ScoreEvent] = []
var _next_id: int = 1
var _next_group: int = 1


## Record one claimed award and return the event it became. **The one place a
## `TUN-SCORE-` float becomes an integer**, so a scoreboard and a breakdown cannot
## round apart by a point.
##
## **THE TICK IS THE INITIATION TICK, NEVER THE RESOLUTION TICK.** Every bonus in
## the game is judged at initiation (TDD-10 §2), and the multiplier is frozen from
## whatever tick is passed here — so a kill pressed before the final phase and
## landing inside it pays 1x, which `test_multiplier_frozen.gd` asserts.
func append(award: ScoreAward, rules: MatchTuning, group: int = 0) -> ScoreEvent:
	var event := ScoreEvent.new(_next_id, award, rules, group)
	_next_id += 1
	_events.append(event)
	return event


## A life boundary. **A real event with real semantics, not a sentinel** (TDD-10
## §1.4): the results screen reads deaths from it and `SCORE-VARIETY` counts over
## the events after it. Worth zero, which US-0065 asserts as a rule rather than
## leaving to this default.
func mark_death(
	at: int, victim: int, killer: int, rules: MatchTuning, group: int = 0
) -> ScoreEvent:
	return append(ScoreAward.new(at, Ids.SCORE_DEATH, victim, killer, 0.0), rules, group)


## A fresh id tying one kill's bonuses together for the feed.
func open_group() -> int:
	var id := _next_group
	_next_group += 1
	return id


## **A COPY, DELIBERATELY.** Handing out the array itself would let any caller
## `clear()` it, and then "append-only" would be a docstring rather than a
## property. The events inside are immutable, so the copy is shallow and cheap —
## a few hundred pointers against a fold that already walks them all.
func events() -> Array[ScoreEvent]:
	return _events.duplicate()


func size() -> int:
	return _events.size()


## The scoreboard. Every reader goes through the fold; there is no running total
## anywhere to disagree with it.
func totals() -> Dictionary:
	return ScoreFold.fold(_events)
