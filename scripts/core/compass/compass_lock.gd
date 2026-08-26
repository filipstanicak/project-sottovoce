## **THE LOCK ARC, THE REVEAL AND THE PORTRAIT.** GDD-03 §8.4, TDD-07 §4.5,
## ASM-0030, US-0058. PURE.
##
## The lock is the hardest skill in the game and the only way a hunter ever learns
## *which* figure is theirs. It fills while the contract sits inside a narrow
## facing cone, within range, with a clear line — and it **drains 1.4× faster than
## it fills** the moment any of those lapses.
##
## **THE DRAIN IS FASTER THAN THE FILL BECAUSE PEEKING MUST BE WORSE THAN
## WATCHING.** At `TUN-COMPASS-LOCK-DECAY-RATE` 1.4 an interrupted view nets
## *negative*: half a second on, half a second off, forever, never completes. That
## pushes the hunter toward standing still and looking — which also happens to
## keep their own suspicion at zero, so the mechanic and the thesis agree rather
## than pulling against each other.
##
## **AND THE PORTRAIT IS WHAT MAKES THE 1.6 s WORTH SPENDING.** The reveal alone
## is `TUN-COMPASS-REVEAL-DURATION` 1.5 s, which is too brief to pay for 1.6 s of
## standing still. ASM-0030 makes a completed lock *also* fill the contract
## portrait permanently — for that contract, resetting on reassignment. That is
## the durable payoff, and it is why locking is a thing a player does twice.
class_name CompassLock
extends RefCounted

## Slots in the per-hunter row below. Constants must precede variables in the
## global scope — `class-definitions-order`.
const FRACTION := 0
const REVEAL := 1
const COOLDOWN := 2
const PORTRAIT := 3
const ARC_FOR := 4

## peer -> `[fraction, reveal_ticks, cooldown_ticks, portrait_for, arc_for]`.
##
## `portrait_for` is the **contract** the portrait was filled for, not a boolean:
## ASM-0030 resets it on reassignment, and a bool would have to be cleared by
## whoever noticed the reassignment first. Storing *who* makes the reset a
## comparison rather than an event somebody can forget to send.
##
## **AND `arc_for` IS A SEPARATE FIELD BECAUSE THE ARC RESETS EVEN WHEN NO
## PORTRAIT WAS EVER EARNED.** The first version inferred the reassignment from
## `portrait_for` alone, so a hunter who had filled half an arc on one contract and
## never completed it carried that half onto the next — progress toward identifying
## somebody they had stopped hunting, and free.
var _locks: Dictionary = {}


func clear() -> void:
	_locks.clear()


func forget(peer: int) -> void:
	_locks.erase(peer)


## One tick of progression for one hunter.
##
## `can_lock` is the system's answer to cone × range × line of sight — this object
## deliberately cannot see the world, so the arithmetic can be exercised against
## any pattern of interruption without standing a district up.
##
## Returns true on the tick a reveal is granted, so the caller can announce it.
func advance(peer: int, contract: int, can_lock: bool, dt: float, cold_read: bool) -> bool:
	var row := _row_for(peer)
	# **THE ARC AND THE PORTRAIT BOTH RESET ON REASSIGNMENT**, ASM-0030. Checked
	# before anything else, because a fraction carried across a reassignment is
	# progress toward identifying somebody the hunter has just stopped hunting.
	#
	# **`NOBODY` IS NOT A REASSIGNMENT.** `TUN-CONTRACT-REASSIGN-DELAY` leaves a
	# killer pointed at nobody for three seconds; clearing on that would make the
	# breath itself destroy a portrait the hunter had earned before it.
	if contract != ContractCycle.NOBODY and int(row[ARC_FOR]) != contract:
		row[FRACTION] = 0.0
		if int(row[PORTRAIT]) != contract:
			row[PORTRAIT] = ContractCycle.NOBODY
		row[ARC_FOR] = contract
	row[REVEAL] = maxi(int(row[REVEAL]) - 1, 0)
	row[COOLDOWN] = maxi(int(row[COOLDOWN]) - 1, 0)
	if contract == ContractCycle.NOBODY:
		row[FRACTION] = 0.0
		return false
	var t := Tuning.compass
	row[FRACTION] = clampf(
		float(row[FRACTION]) + _delta_per_second(can_lock, cold_read, t) * dt, 0.0, 1.0
	)
	if float(row[FRACTION]) < 1.0 or int(row[COOLDOWN]) > 0:
		return false
	_grant(row, contract)
	return true


## Points of the arc per second: **positive while the view holds, negative and
## `TUN-COMPASS-LOCK-DECAY-RATE` steeper when it breaks.**
func _delta_per_second(can_lock: bool, cold_read: bool, t: CompassTuning) -> float:
	var fill := 1.0 / maxf(t.lock_fill_time, 0.001)
	if cold_read:
		fill *= t.cold_read_mult
	return fill if can_lock else -fill * t.lock_decay_rate


## **THE FRACTION IS NOT RESET ON COMPLETION**, TDD-07 §4.5. A hunter holding a
## clear view keeps a full arc; what stops the target being permanently outlined
## is `TUN-COMPASS-REVEAL-COOLDOWN`, not the arc emptying. Resetting it here would
## make the second reveal cost another 1.6 s of standing still, which is a
## different and much harsher rule than the one §8.4 argues for.
func _grant(row: Array, contract: int) -> void:
	row[REVEAL] = maxi(Tuning.ticks(&"TUN-COMPASS-REVEAL-DURATION"), 1)
	row[COOLDOWN] = maxi(Tuning.ticks(&"TUN-COMPASS-REVEAL-COOLDOWN"), 1)
	row[PORTRAIT] = contract


## How full the arc is, `[0, 1]`. The wire carries it as a byte.
func fraction_of(peer: int) -> float:
	return float(_row_for(peer)[FRACTION]) if _locks.has(peer) else 0.0


## Is the contract's silhouette being revealed to `peer` right now?
func revealing(peer: int) -> bool:
	return _locks.has(peer) and int(_row_for(peer)[REVEAL]) > 0


## **ASM-0030's PERMANENT HALF.** True once a lock has completed on *this*
## contract, and false again the moment the contract changes.
func portrait_revealed(peer: int, contract: int) -> bool:
	if not _locks.has(peer) or contract == ContractCycle.NOBODY:
		return false
	return int(_row_for(peer)[PORTRAIT]) == contract


## Ticks until another reveal is allowed. Zero means now.
func reveal_cooldown_ticks(peer: int) -> int:
	return int(_row_for(peer)[COOLDOWN]) if _locks.has(peer) else 0


func _row_for(peer: int) -> Array:
	if not _locks.has(peer):
		_locks[peer] = [0.0, 0, 0, ContractCycle.NOBODY, ContractCycle.NOBODY]
	return _locks[peer] as Array
