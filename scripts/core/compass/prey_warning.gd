## **WHETHER THIS PREY IS OWED A WARNING THIS TICK.** GDD-03 §9.1, US-0059. PURE.
##
## `SYS-DETECTION` supplies the two facts — *is the pursuer inside
## `TUN-COMPASS-WARN-RADIUS`* and *has the pursuer revealed themselves* — and this
## holds the only thing that is not a fact: the re-trigger cooldown.
##
## **THE COOLDOWN RE-ARMS WHEN THE PURSUER CHANGES, AND THAT IS THE DEFECT
## `CompassLock` ALREADY TAUGHT.** US-0058 found a half-filled lock arc crossing to
## a hunter's next contract because it was inferred from the portrait rather than
## tracked. The same shape lives here: a prey warned about one pursuer, then handed
## a new one by a repair, would be **silent about the new one for up to
## `TUN-COMPASS-WARN-COOLDOWN`** — 2.5 s of the one thing the design calls the
## prey's only warning, suppressed by a relationship that no longer exists.
##
## **AND THE TIER GATE IS NOT IN HERE.** It is one comparison against a pawn this
## object cannot see, and `SYS-DETECTION`'s early-out ladder has already made it
## before anything reaches this class. Duplicating it would be a second authority
## on the question design law 6 makes load-bearing.
class_name PreyWarning
extends RefCounted

## prey peer -> `[pursuer_peer, tick_the_last_warning_went_out]`.
##
## **A prey with no entry has never been warned**, which is not the same as one
## whose cooldown has elapsed, and only the first is a state this class can be in
## at match start.
var _last: Dictionary = {}


## Should `prey` be warned about `pursuer` on tick `tick`?
##
## `within` is the range test and `revealed` is the tier test; both are
## `SYS-DETECTION`'s, because both are questions about pawns.
##
## **CALLING THIS IS WHAT ARMS THE COOLDOWN.** It is not a getter — a caller that
## asks twice in one tick gets `true` then `false`, which is the correct answer to
## "is another warning owed" and the wrong answer to "was one owed". There is one
## caller for exactly that reason.
func consider(prey: int, pursuer: int, within: bool, revealed: bool, tick: int) -> bool:
	if not within or not revealed:
		return false
	if _is_new_pursuer(prey, pursuer) or _cooldown_elapsed(prey, tick):
		_last[prey] = [pursuer, tick]
		return true
	return false


## **A REPAIR HANDED THIS PREY SOMEBODY ELSE.** The old pursuer's cooldown says
## nothing about the new one, so it does not suppress them.
func _is_new_pursuer(prey: int, pursuer: int) -> bool:
	if not _last.has(prey):
		return true
	return int((_last[prey] as Array)[0]) != pursuer


## **`Tuning.ticks()` TAKES THE `TUN-` ID, NOT THE SECONDS.** Trap 7: the autoload
## precomputes every duration into a tick table at load, so the lookup key is the
## identifier and handing it the float is a parse error rather than a wrong
## number. `maxi(..., 1)` is the shape every other system uses — a cooldown that
## rounded to zero ticks would warn on every tick of a chase.
func _cooldown_elapsed(prey: int, tick: int) -> bool:
	var since := tick - int((_last[prey] as Array)[1])
	return since >= cooldown_ticks()


## The cooldown in **net** ticks. Public so a test asserts the same number the
## gate uses rather than recomputing it and agreeing with itself.
static func cooldown_ticks() -> int:
	return maxi(Tuning.ticks(&"TUN-COMPASS-WARN-COOLDOWN"), 1)


## The tick this prey was last warned on, or `-1`. For tests and for a readout;
## nothing in the shipped path reads it.
func last_warned(prey: int) -> int:
	if not _last.has(prey):
		return -1
	return int((_last[prey] as Array)[1])


## Who this prey was last warned about, or `ContractCycle.NOBODY`.
func warned_about(prey: int) -> int:
	if not _last.has(prey):
		return ContractCycle.NOBODY
	return int((_last[prey] as Array)[0])


## A peer that has left. Its cooldown would otherwise be inherited by whoever
## reuses the id — US-0037's lesson, applied before it can bite.
func forget(peer: int) -> void:
	_last.erase(peer)


func clear() -> void:
	_last.clear()
