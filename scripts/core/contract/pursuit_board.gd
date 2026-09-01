## **EVERY LIVE CHASE, AND THE ONE RULE THAT ENDS ONE.** ADR-0014, US-0097. PURE.
##
## A hunter who alerts their prey enters a **pursuit**: sight of the prey refreshes
## a timer, absence of sight drains it, and when it empties the hunter **loses the
## contract**. It is the second tooth design law 5 asks for, and the one that fits
## the thesis better than the stun — it is won by restraint rather than by a button.
##
## **REFRESH, NOT INCREMENT, AND THAT IS THE WHOLE RULE.** An incrementing bar lets
## a hunter who glimpses their prey every few seconds hold a chase open forever
## without ever closing; a refreshing one means the question is only ever *"have
## you seen them inside the last `TUN-PURSUIT-DURATION`?"*. The reference refreshes.
##
## **KEYED ON THE HUNTER, NOT ON THE PAIR.** A Hamiltonian cycle gives every player
## exactly one outgoing edge, so a hunter has at most one chase — and keying on the
## pair would let a repair leave a stale chase against a prey they no longer hold.
class_name PursuitBoard
extends RefCounted

## Row layout for `_chases`. Named rather than indexed by literal, because a
## three-slot array whose third slot is a boolean is exactly the shape somebody
## reads wrong at a glance.
const _PREY := 0
const _TICKS := 1
const _WATCHED_BLEND := 2

## How many chases have emptied. Published rather than counted by a caller, so
## `TEL-ESCAPE-RATE` has one source.
var escapes: int = 0

## Hunter peer -> `[prey, ticks_left, seen_the_blend]`.
var _chases: Dictionary = {}


## Open a chase, or refresh one already open. **The same call for both**, because
## the trigger and the refresh are the same event seen twice: a hunter who is
## visible to their prey is a hunter whose contract is at risk, and one who can
## see their prey is one who is still hunting.
func refresh(hunter: int, prey: int, ticks: int) -> void:
	if not _chases.has(hunter) or int(_row(hunter)[_PREY]) != prey:
		_chases[hunter] = [prey, ticks, false]
		return
	_row(hunter)[_TICKS] = ticks


## One net tick of no sight. Returns the hunters whose bar just emptied.
##
## **THE DRAIN IS IN NET TICKS** (trap 9): a chase is judged at the `detection`
## stage, 30 times a second, and counting it in step ticks would halve
## `TUN-PURSUIT-DURATION` silently — 10.72 s of documented chase resolving in 5.36.
func drain(hunters: PackedInt32Array) -> PackedInt32Array:
	var emptied := PackedInt32Array()
	for hunter: int in hunters:
		if not _chases.has(hunter):
			continue
		var row := _row(hunter)
		row[_TICKS] = int(row[_TICKS]) - 1
		if int(row[_TICKS]) <= 0:
			emptied.append(hunter)
	return emptied


## **A CHASE DOES NOT END BECAUSE THE HUNTER CALMS DOWN.** Once you have been seen
## you must close or lose them; a hunter who could cancel by standing still would
## have alerted their prey for free. So this is called for a kill, a death or a
## disconnect, and by nothing else.
func close(hunter: int) -> void:
	_chases.erase(hunter)


## The chase ended by its own timer. Separate from `close` so the counter cannot
## be moved by a death.
func escaped(hunter: int) -> void:
	if _chases.has(hunter):
		escapes += 1
	_chases.erase(hunter)


## Everyone whose contract is currently at risk.
func hunters() -> PackedInt32Array:
	var out := PackedInt32Array()
	for hunter: Variant in _chases:
		out.append(int(hunter))
	return out


func is_chasing(hunter: int) -> bool:
	return _chases.has(hunter)


func prey_of(hunter: int) -> int:
	return ContractCycle.NOBODY if not _chases.has(hunter) else int(_row(hunter)[_PREY])


## Whoever is hunting `prey`, or `NOBODY`. **The reverse lookup is a scan and that
## is fine**: at most six chases exist, because at most six players do.
func hunter_of(prey: int) -> int:
	for hunter: Variant in _chases:
		if int((_chases[hunter] as Array)[_PREY]) == prey:
			return int(hunter)
	return ContractCycle.NOBODY


## 0.0 when the bar is empty, 1.0 when full. **What both parties are shown**, and
## it names nobody: the prey learns *a bar is draining*, never whose.
func fraction_of(hunter: int, full_ticks: int) -> float:
	if not _chases.has(hunter) or full_ticks <= 0:
		return 0.0
	return clampf(float(_row(hunter)[_TICKS]) / float(full_ticks), 0.0, 1.0)


func ticks_left(hunter: int) -> int:
	return 0 if not _chases.has(hunter) else int(_row(hunter)[_TICKS])


## **THE BLEND CLAUSE, AND IT IS GDD-03 §9.2's OWN RULE IN A NEW PLACE.** *The
## crowd hides you by being confusing, never by being solid.* A hunter with a clear
## line to a player in a held blend cannot pick them out of the pocket — **unless
## they had unbroken sight at the instant the blend began**, in which case they
## watched it happen and the pocket is transparent to them.
##
## So the prey's correct play is **break the corner first, then blend**. Blending
## in front of somebody looking straight at you buys nothing.
func note_blend_began(hunter: int, under_sight: bool) -> void:
	if _chases.has(hunter):
		_row(hunter)[_WATCHED_BLEND] = under_sight


## Cleared the moment sight breaks, which is what makes the clause a *memory of
## one moment* rather than a permanent property of the blend.
func note_sight_broken(hunter: int) -> void:
	if _chases.has(hunter):
		_row(hunter)[_WATCHED_BLEND] = false


func watched_the_blend(hunter: int) -> bool:
	return _chases.has(hunter) and bool(_row(hunter)[_WATCHED_BLEND])


func count() -> int:
	return _chases.size()


func clear() -> void:
	_chases.clear()


## **`Dictionary.get` HANDS BACK `null`, AND A TYPED `Array` REFUSES IT.** Every
## accessor here read `var row: Array = _chases.get(hunter)`, which is a runtime
## error on every miss — *"trying to assign value of type 'Nil' to a variable of
## type 'Array'"* — and eleven of thirteen tests went red at once. One guarded
## reader, asked only after `has()`.
func _row(hunter: int) -> Array:
	return _chases[hunter] as Array
