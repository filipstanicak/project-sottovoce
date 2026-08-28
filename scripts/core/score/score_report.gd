## **WHAT A CLIENT IS TOLD ABOUT ONE AWARD.** `NET-S2C-SCORE-EVENT`, US-0074.
## PURE.
##
## The third record in the scoring chain, and each one exists because the seam
## either side of it is real. `ScoreAward` is the **claim** a system makes;
## `ScoreEvent` is what the log made of it, server-side and immutable;
## `ScoreReport` is what survived the wire. They are not the same object because
## they do not carry the same facts: a report has no `event_id` to fold by and no
## `actor` to attribute to, because a score event reaches its actor and nobody
## else, so the recipient is the actor by construction.
##
## **THE CLIENT IS TOLD WHAT IT WAS PAID, NEVER HOW TO WORK IT OUT.** The
## multiplier arrives resolved rather than as a phase the client re-derives — a
## client deriving what a kill was worth is a client deciding gameplay state
## (never-do #3), and it would disagree with the server at the one boundary that
## matters, the tick the final phase opens.
class_name ScoreReport
extends RefCounted

## A `SCORE-` id, or `&""` if this client does not know the byte it arrived as.
var kind: StringName:
	get:
		return _kind

## Already multiplied, already rounded — `ScoreEvent.points_of`'s arithmetic, run
## once on each side from the same two numbers.
var points: int:
	get:
		return _points

## Awards from one kill share this, which is the whole reason the feed can stagger
## them instead of dropping four lines at once.
var group: int:
	get:
		return _group

var _kind: StringName = &""
var _points: int = 0
var _group: int = 0


func _init(kind_id: StringName, value: int, group_id: int = 0) -> void:
	_kind = kind_id
	_points = value
	_group = group_id


## **A PENALTY IS A NEGATIVE, NOT A SMALL POSITIVE.** UI_UX_SPEC §5.2 requires a
## distinct treatment for it, and asking the question here rather than in the
## widget means the feed and any later consumer answer it the same way.
##
## **`SCORE-RECKLESS` PAYS ZERO AND IS THEREFORE NOT A PENALTY**, which is correct
## and worth stating: ADR-0013 neutralised the charge and kept the line, so what
## it says is *you were seen* rather than *you were fined*.
func is_penalty() -> bool:
	return _points < 0
