## **THE SCOREBOARD IS A FOLD OVER THE LOG, AND IT IS PURE.** ADR-0004, TDD-10
## §1.3, US-0064. PURE — no autoload, no scene, no clock.
##
## That purity is the whole point of event sourcing here: the most bug-prone part
## of the design becomes the most testable part. `test_score_fold.gd` reproduces
## every reference value in GDD-07 §3.2 from these functions alone, with no server
## standing up.
##
## **THE SKETCH IN TDD-10 §1.3 TAKES A `ScoringTuning` AND THIS DOES NOT, WHICH IS
## AN AMENDMENT RATHER THAN AN OVERSIGHT.** §1.2 freezes the multiplier at append
## and the event carries `base_points` already rounded, so a fold that re-read the
## tuning could produce a **different total from the one the score feed already
## showed the player** the moment a value was retuned mid-session. Two sources of
## truth is exactly what §1.1 exists to prevent, and the argument it makes against
## a parallel stats dictionary applies unchanged to a parallel points table.
class_name ScoreFold
extends RefCounted


## Peer id -> total points. The one function that produces a score.
static func fold(events: Array[ScoreEvent]) -> Dictionary:
	var totals: Dictionary = {}
	for event: ScoreEvent in events:
		var actor := event.actor_id
		totals[actor] = int(totals.get(actor, 0)) + event.points()
	return totals


## One actor's total. **Folds rather than looking up**, so it can never disagree
## with `fold()` — a second accumulation path is the divergence TDD-10 §1.1 names.
static func total_for(events: Array[ScoreEvent], actor: int) -> int:
	return int(fold(events).get(actor, 0))


## Kind -> points, for the results screen's breakdown. **Sums rather than counts**,
## because two Long Hunt rungs pay different amounts under one id and a count would
## show a player a number that is not in their total.
static func breakdown(events: Array[ScoreEvent], actor: int) -> Dictionary:
	var by_kind: Dictionary = {}
	for event: ScoreEvent in events:
		if event.actor_id != actor:
			continue
		by_kind[event.kind] = int(by_kind.get(event.kind, 0)) + event.points()
	return by_kind


## How many times this actor died. **`SCORE-DEATH` is a real event with real
## semantics** (TDD-10 §1.4), not a sentinel: the results screen reads deaths from
## the same log everything else is read from, so a death cannot be counted twice
## or missed.
static func deaths_of(events: Array[ScoreEvent], actor: int) -> int:
	var deaths := 0
	for event: ScoreEvent in events:
		if event.actor_id == actor and event.kind == Ids.SCORE_DEATH:
			deaths += 1
	return deaths


## This actor's events since their last death, which is what `SCORE-VARIETY` counts
## over (TDD-10 §1.4). **The query lives here and the bonus does not** — Variety is
## US-0065's, and is the one bonus computed at append time.
static func since_last_death(events: Array[ScoreEvent], actor: int) -> Array[ScoreEvent]:
	var mine: Array[ScoreEvent] = []
	for event: ScoreEvent in events:
		if event.actor_id != actor:
			continue
		if event.kind == Ids.SCORE_DEATH:
			mine.clear()
			continue
		mine.append(event)
	return mine


## Every event sharing a `group_id`, which is one kill's worth of bonuses. The
## score feed groups by this so a 750-point kill reads as one line with a
## breakdown rather than as five unrelated numbers.
static func group(events: Array[ScoreEvent], group_id: int) -> Array[ScoreEvent]:
	var found: Array[ScoreEvent] = []
	for event: ScoreEvent in events:
		if event.group_id == group_id:
			found.append(event)
	return found
