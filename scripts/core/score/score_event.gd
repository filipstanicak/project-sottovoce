## **ONE SCOREABLE ACTION, RECORDED AND NEVER CHANGED AGAIN.** ADR-0004, TDD-10
## §1, US-0064. PURE.
##
## Scoring is event sourcing: every scoreable action appends one of these to a
## server-owned append-only log, and the scoreboard, the score feed and the
## results screen are all folds over it. TDD-10 §1.1 gives the reason a running
## integer fails — no per-bonus breakdown, no telemetry, a total that depends on
## which system happened to run first, and almost nothing a test can hold.
##
## **IT IS IMMUTABLE IN THE ENGINE, NOT ONLY IN A COMMENT.** Every field is a
## getter-only property over a private backing value, so `event.tick = 9` does not
## compile and `event.set("tick", 9)` is silently refused. The story asks for "no
## setter, no mutating method"; a plain `var` with a docstring saying *never mutate
## this* is exactly the shape that gets mutated two milestones later.
##
## **AND THE MULTIPLIER IS FROZEN HERE, WHICH IS WHY THERE IS ONE CONSTRUCTOR AND
## IT TAKES A TICK RATHER THAN A MULTIPLIER.** TDD-10 §1.2 requires it resolved
## from the event's own tick at append time rather than at fold time. Passing the
## multiplier in would permit an event whose multiplier disagrees with its tick;
## deriving it means no such event can be built.
class_name ScoreEvent
extends RefCounted

## Monotonic, assigned by `ScoreLog`. Never reused within a match.
var event_id: int:
	get:
		return _event_id

## The server tick the action was judged at — **initiation**, never resolution.
var tick: int:
	get:
		return _tick

## A `SCORE-` id from `Ids`.
var kind: StringName:
	get:
		return _kind

## The peer who earned it.
var actor_id: int:
	get:
		return _actor_id

## The peer it was earned against, or 0 for nobody.
var subject_id: int:
	get:
		return _subject_id

## Pre-multiplier, rounded from `ScoringTuning` once, by `ScoreLog.append`.
var base_points: int:
	get:
		return _base_points

## 1.0, or `TUN-MATCH-FINALPHASE-MULT`. Frozen from `tick` at construction.
var multiplier: float:
	get:
		return _multiplier

## Events from one kill share this, so the feed can group them.
var group_id: int:
	get:
		return _group_id

var _event_id: int = 0
var _tick: int = 0
var _kind: StringName = &""
var _actor_id: int = 0
var _subject_id: int = 0
var _base_points: int = 0
var _multiplier: float = 1.0
var _group_id: int = 0


func _init(id: int, award: ScoreAward, rules: MatchTuning, group: int = 0) -> void:
	_event_id = id
	_tick = award.tick
	_kind = award.kind
	_actor_id = award.actor
	_subject_id = award.subject
	_base_points = int(round(award.points))
	_multiplier = multiplier_at(award.tick, rules)
	_group_id = group


## What this event is worth. The fold sums exactly this and nothing else.
func points() -> int:
	return int(round(float(_base_points) * _multiplier))


## **THE FINAL PHASE IS A PROPERTY OF THE CLOCK, NOT OF A STATE MACHINE**, which
## is why scoring is not blocked on `SYS-MATCH` (US-0079). It opens
## `TUN-MATCH-FINALPHASE-DURATION` before the end of `TUN-MATCH-DURATION`, and both
## are tunables, so the answer follows from a tick and nothing else.
##
## **WHEN `SYS-MATCH` ARRIVES IT MUST READ THIS RATHER THAN DECIDE IT AGAIN.** Two
## answers to *is it the final phase* would disagree at the boundary, and the
## visible symptom is a HUD announcing the phase on a different tick from the one
## the points were paid at.
##
## **THE TICK IS THE MATCH TICK.** Until US-0079 owns a match clock the server's
## own tick is all there is, so on a long-lived dev server the multiplier arrives
## 450 s after boot rather than 450 s into a match. Nothing reads a score yet, so
## nothing is wrong today; it is the first thing US-0079 makes true.
static func multiplier_at(tick: int, rules: MatchTuning) -> float:
	var rate := maxf(rules.tick_rate, 1.0)
	var opens := (rules.duration - rules.finalphase_duration) * rate
	return rules.finalphase_mult if float(tick) >= opens else 1.0
