## **WHAT A SYSTEM CLAIMS HAPPENED, BEFORE THE LOG RECORDS IT.** TDD-10 §1,
## US-0064. PURE.
##
## An award is a *claim*: `SYS-KILL` says "this player earned Silent at tick 4102".
## A `ScoreEvent` is what `ScoreLog` made of that claim — stamped with an id, a
## group and a frozen multiplier. **The seam is the append**, and having a type on
## each side of it is what lets the log be the only thing that assigns any of the
## three.
##
## **IT EXISTS BECAUSE EIGHT POSITIONAL ARGUMENTS IS A DESIGN SIGNAL.** `.gdlintrc`
## caps a signature at six and says so in as many words: *"if a limit is genuinely
## wrong for a case, that is an ADR, not a `gdlint:ignore`"*. It was not wrong here
## — `ScoreEvent.new(id, tick, kind, actor, subject, points, rules, group)` is a
## call site where transposing the actor and the subject is invisible, and it
## appears twelve times per kill in US-0065.
##
## Points are the **raw tunable**, unrounded. `ScoreLog.append` is the one place
## they become an integer, so a scoreboard and a breakdown cannot round apart.
class_name ScoreAward
extends RefCounted

## The **initiation** tick, never the resolution tick. Every bonus in the game is
## judged at initiation (TDD-10 §2) and the multiplier is frozen from this.
var tick: int = 0

## A `SCORE-` id from `Ids`.
var kind: StringName = &""

## The peer who earned it.
var actor: int = 0

## The peer it was earned against, or 0 for nobody.
var subject: int = 0

## Straight from `ScoringTuning`, unrounded.
var points: float = 0.0


func _init(at: int, of_kind: StringName, by: int, against: int, worth: float) -> void:
	tick = at
	kind = of_kind
	actor = by
	subject = against
	points = worth
