## **WHAT EACH OBSERVER SEES OF EACH SUBJECT, THIS TICK.** GDD-03 §2.1,
## TDD-07 §4, US-0055. PURE.
##
## Thirty ordered pairs at six players. `SYS-DETECTION` fills it at the
## `detection` stage and `SnapshotBuilder` reads it at the `snapshot` stage — the
## two are four positions apart in `SystemOrder`, and the matrix is what carries
## the answer across without either knowing the other exists.
##
## **ABSENT MEANS `PLAIN`, AND THAT IS THE SAFE DIRECTION.** A pair nobody
## computed renders as an ordinary civilian. The opposite default would leak a
## tint every time a pass was skipped, and a leak that only happens on the tick
## something went wrong is a leak nobody reproduces.
class_name RenderMatrix
extends RefCounted

## `observer` -> { `subject` -> `RenderState.State` }. Only non-`PLAIN` entries
## are stored: at six players with most people Anonymous most of the time, the
## matrix is usually empty, and storing thirty zeroes to say nothing is happening
## costs more than it explains.
var _seen: Dictionary = {}


## Forget everything. Called at the top of each pass — the matrix describes one
## tick and a stale entry is a tint drawn from a relationship that has ended.
func clear() -> void:
	_seen.clear()


## Record that `observer` sees `subject` as `state`. `PLAIN` is not stored.
func set_state(observer: int, subject: int, state: int) -> void:
	if state == RenderState.State.PLAIN:
		return
	if not _seen.has(observer):
		_seen[observer] = {}
	(_seen[observer] as Dictionary)[subject] = state


## What `observer` sees of `subject`. `PLAIN` for anything not recorded.
func state_of(observer: int, subject: int) -> int:
	var row: Dictionary = _seen.get(observer, {})
	return int(row.get(subject, RenderState.State.PLAIN))


## How many pairs are anything other than `PLAIN`. **For tests and for a log
## line**: a district in which everybody can see everybody is a district where
## this rule has stopped working, and the number is the cheapest way to notice.
func marked_pairs() -> int:
	var total := 0
	for observer: int in _seen:
		total += (_seen[observer] as Dictionary).size()
	return total
