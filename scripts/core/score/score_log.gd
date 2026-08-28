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


## **ONE KILL, ONE GROUP, AND `SCORE-VARIETY` COMPUTED HERE.** TDD-10 §1.4.
##
## Variety is the one bonus the fold cannot do, because it counts against **the
## events already in the log**: `n` is how many of this kill's bonus types the
## actor has not earned since their last death. Making the fold stateful to
## accommodate one bonus would cost more than this exception does.
##
## **ITSELF, `SCORE-CONTRACT` AND `SCORE-RECKLESS` ARE EXCLUDED** (ASM-0017).
## Contract is on every kill, so counting it would pay a flat 50 for existing;
## Reckless is a marker worth nothing, so counting it would pay for carelessness.
## **`SCORE-HALFSEEN` IS NOT EXCLUDED, AND ASM-0017 PREDATES IT** — the middle rung
## was added on 2026-08-27 and nobody has said whether a tier rung should count as
## variety. Reported rather than decided: it is one entry in this list.
##
## **PAID AS ONE EVENT OF `variety × n`, NOT `n` EVENTS.** The feed draws a kill as
## one line with a breakdown, and `n` identical lines saying +50 would be the
## breakdown lying about what happened.
func append_kill(awards: Array[ScoreAward], rules: MatchTuning, s: ScoringTuning) -> int:
	if awards.is_empty():
		return 0
	var group := open_group()
	var head := awards[0]
	var fresh := variety_count(head.actor, awards)
	for award: ScoreAward in awards:
		append(award, rules, group)
	if fresh > 0:
		append(
			ScoreAward.new(
				head.tick, Ids.SCORE_VARIETY, head.actor, head.subject, s.variety * float(fresh)
			),
			rules,
			group
		)
	return group


## How many of these kinds the actor has not earned since their last death.
func variety_count(actor: int, awards: Array[ScoreAward]) -> int:
	var already: Dictionary = {}
	for event: ScoreEvent in ScoreFold.since_last_death(_events, actor):
		already[event.kind] = true
	var fresh := 0
	for award: ScoreAward in awards:
		if award.kind in [Ids.SCORE_VARIETY, Ids.SCORE_CONTRACT, Ids.SCORE_RECKLESS]:
			continue
		if not already.has(award.kind):
			already[award.kind] = true
			fresh += 1
	return fresh


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


## Everything appended at or after `index`. **A cursor over an append-only log is
## how the wire stays honest without a call site knowing it exists** — US-0065
## added two append points and US-0097 will add more, and a courier that hooked
## each one is a list somebody forgets to extend. `MatchAnnouncer` holds the index
## and this hands back only what it has not seen.
func tail(index: int) -> Array[ScoreEvent]:
	if index >= _events.size():
		return [] as Array[ScoreEvent]
	return _events.slice(maxi(index, 0))


## The scoreboard. Every reader goes through the fold; there is no running total
## anywhere to disagree with it.
func totals() -> Dictionary:
	return ScoreFold.fold(_events)
