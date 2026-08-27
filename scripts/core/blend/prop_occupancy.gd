## **WHO IS INSIDE WHICH CONCEALMENT PROP.** GDD-03 §4.1.4, TDD-07 §3.3, US-0054.
## PURE Core.
##
## **CAPACITY ONE IS WHAT MAKES A PROP A RESOURCE RATHER THAN A FEATURE.** Five
## exist on `MAP-VETRAIO` and each holds one player, so a second arrival has a
## real problem — GDD-03 §4.1.4's own words. A capacity of two would make the
## strongest blend in the game freely available to everybody who wanted it, and
## the "claimable" half of the design would be decoration.
##
## **OCCUPANCY IS SERVER-OWNED STATE**, which is US-0054's last criterion and the
## reason this is a plain object on the server rather than anything a client
## mirrors. A client that believed a prop free would walk to it and be refused,
## which is a worse experience than being told; a client that *decided* a prop was
## free would be authoritative over an outcome, which is never-do #2.
##
## **AND IT IS KEYED BY PEER IN BOTH DIRECTIONS.** ENet reuses peer ids, so a prop
## left claimed by a peer that disconnected is one nobody can ever enter again —
## US-0037's lesson, and the failure mode is a hiding spot that silently vanishes
## from the map for the rest of the match.
class_name PropOccupancy
extends RefCounted

## Nobody is inside.
const VACANT := -1

## prop index -> peer id.
var _holders: Dictionary = {}

## peer -> { prop index -> the tick before which they may not re-enter it }.
var _too_soon: Dictionary = {}


## How many players a prop holds. `TUN-BLEND-PROP-CAPACITY`.
##
## **READ RATHER THAN WRITTEN AS 1**, so that raising it is a tuning change rather
## than a code change. The rest of this class is written against the number, not
## against the assumption.
static func capacity() -> int:
	return maxi(Tuning.suspicion.blend_prop_capacity, 1)


## `TUN-BLEND-PROP-EXIT-VULN` in **net** ticks. Trap 9: `SYS-BLEND` resolves at the
## 30 Hz suspicion pass, and `step_ticks` would halve the window.
static func reentry_ticks() -> int:
	return maxi(Tuning.ticks(&"TUN-BLEND-PROP-EXIT-VULN"), 1)


## Why `peer` may or may not enter `index` on `tick`. Asks; does not claim.
func may_enter(peer: int, index: int, tick: int) -> BlendRefusal.Why:
	if _locked_out(peer, index, tick):
		return BlendRefusal.Why.PROP_TOO_SOON
	if count_in(index) >= capacity() and holder_of(index) != peer:
		return BlendRefusal.Why.PROP_OCCUPIED
	return BlendRefusal.Why.TAKEN


## Take `index` for `peer`. Returns false if it was not available, so a caller
## cannot claim by asking twice.
##
## **THE CHECK AND THE CLAIM ARE ONE CALL.** Two players pressing on the same tick
## are resolved here rather than by whoever the caller happened to iterate first;
## `may_enter` exists for the readiness hint, not as a gate to be trusted.
func claim(peer: int, index: int, tick: int) -> bool:
	if may_enter(peer, index, tick) != BlendRefusal.Why.TAKEN:
		return false
	_holders[index] = peer
	return true


## `peer` steps out of whatever they hold, and cannot go back in for
## `TUN-BLEND-PROP-EXIT-VULN`.
##
## **THE LOCKOUT IS PER PROP, NOT PER PLAYER.** A player who leaves the well and
## runs to the hay cart is doing exactly what the design wants — the window exists
## to stop *door-flickering on one prop* to dodge a kill, not to punish moving
## between them.
func release(peer: int, tick: int) -> void:
	var index := prop_of(peer)
	if index == VACANT:
		return
	_holders.erase(index)
	if not _too_soon.has(peer):
		_too_soon[peer] = {}
	(_too_soon[peer] as Dictionary)[index] = tick + reentry_ticks()


func holder_of(index: int) -> int:
	return int(_holders.get(index, ContractCycle.NOBODY))


func count_in(index: int) -> int:
	return 1 if _holders.has(index) else 0


## Which prop `peer` is inside, or `VACANT`.
func prop_of(peer: int) -> int:
	for index: int in _holders.keys():
		if int(_holders[index]) == peer:
			return index
	return VACANT


func is_inside(peer: int) -> bool:
	return prop_of(peer) != VACANT


## Props currently held. For a readout and for tests.
func occupied_count() -> int:
	return _holders.size()


## A peer that has left. **Both directions**: the prop they held and the lockouts
## about them. Missing the first empties a hiding spot from the map permanently.
func forget(peer: int) -> void:
	var index := prop_of(peer)
	if index != VACANT:
		_holders.erase(index)
	_too_soon.erase(peer)


func clear() -> void:
	_holders.clear()
	_too_soon.clear()


func _locked_out(peer: int, index: int, tick: int) -> bool:
	if not _too_soon.has(peer):
		return false
	return tick < int((_too_soon[peer] as Dictionary).get(index, -1))
