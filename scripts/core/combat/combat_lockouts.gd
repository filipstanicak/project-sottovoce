## **THE TWO COMBAT TIMERS THAT OUTLIVE THE ACTION THAT SET THEM.** GDD-03 §10,
## TDD-10 §3-4, US-0060 and US-0061. PURE Core.
##
## Three different shapes, deliberately in one class because every one of them is
## read by a combat system and written by a different one, and a system reaching
## another system's private dictionary is the drift `MatchContext` exists to
## prevent:
##
## - **A stagger is per player and blocks every initiation.** The contest loser's
##   `TUN-KILL-CONTEST-STAGGER` and the flailer's `TUN-STUN-INVALID-STAGGER` are
##   the same thing: no points, no lockout, no suspicion beyond what the action
##   already cost, and a window in which you cannot start anything.
## - **An exile is per (hunter, target) pair and blocks one kill.**
##   `TUN-STUN-LOCKOUT` is what makes a stun counterplay rather than a four-second
##   delay: the hunter is forbidden from re-initiating **on that specific target**,
##   and is free to hunt anybody else the cycle hands them.
## - **A protection is per player and blocks everything aimed AT them.**
##   `TUN-RESPAWN-INVULN`, written by `SYS-SPAWN` (US-0062). The other two restrain
##   an *initiator*; this one shields a *target*, which is why it is a third shape
##   rather than a stagger with the sign flipped. It begins when the player leaves
##   `Respawning`, because until then both combat systems already refuse them.
##
## **NEITHER IS A STATE, AND GDD-02 §3's DIAGRAM IS WHY.** That diagram declares
## fifteen states and none of them is a stagger, while three rules need one
## (`TUN-KILL-CONTEST-STAGGER`, `TUN-STUN-INVALID-STAGGER`,
## `TUN-LUNGE-WHIFF-STAGGER`). A sixteenth state amends a normative diagram and is
## the owner's; an initiation lockout expresses "losing should cost tempo, not the
## match" without one. Recorded in US-0060 and unchanged here.
##
## **IT IS KEYED BY PEER, NEVER BY WIRE SLOT.** Slots are reused the moment
## somebody leaves, so an exile resolving against slot 3 would exile whoever
## inherited it — US-0037's lesson, applied before it can bite.
class_name CombatLockouts
extends RefCounted

## peer -> the tick before which they may not initiate anything.
var _stagger: Dictionary = {}

## hunter -> { target -> the tick before which they may not kill that target }.
var _exile: Dictionary = {}

## peer -> the tick before which nothing may be aimed at them.
var _protected: Dictionary = {}


## Block every initiation by `peer` until `until_tick`.
##
## **THE LONGER OF THE TWO WINS.** A player already staggered who earns a shorter
## one must not have their punishment shortened by it, which is what a plain
## assignment would do.
func stagger(peer: int, until_tick: int) -> void:
	_stagger[peer] = maxi(until_tick, int(_stagger.get(peer, -1)))


func is_staggered(peer: int, now: int) -> bool:
	return now < int(_stagger.get(peer, -1))


func stagger_remaining(peer: int, now: int) -> int:
	return maxi(int(_stagger.get(peer, -1)) - now, 0)


## Forbid `hunter` from initiating on `target` until `until_tick`.
func exile(hunter: int, target: int, until_tick: int) -> void:
	if not _exile.has(hunter):
		_exile[hunter] = {}
	var rows: Dictionary = _exile[hunter]
	rows[target] = maxi(until_tick, int(rows.get(target, -1)))


func is_exiled(hunter: int, target: int, now: int) -> bool:
	return remaining(hunter, target, now) > 0


## TDD-10 §7's `lockout_remaining_ticks`, in net ticks. Zero when free.
##
## **THIS IS WHAT `NET-S2C-STUN-RESULT` CARRIES**, so both parties see the same
## number: the hunter learns how long their exile is and the prey learns how long
## they bought. A stun whose duration only one side could see would be a
## punishment neither could plan around.
func remaining(hunter: int, target: int, now: int) -> int:
	if not _exile.has(hunter):
		return 0
	return maxi(int((_exile[hunter] as Dictionary).get(target, -1)) - now, 0)


## A peer that has left, in **both** directions: their own timers and everybody
## else's timers about them. Missing the second half is how ENet's id reuse hands
## a joiner somebody else's exile.
func forget(peer: int) -> void:
	_stagger.erase(peer)
	_exile.erase(peer)
	_protected.erase(peer)
	for hunter: int in _exile.keys():
		(_exile[hunter] as Dictionary).erase(peer)


## Shield `peer` from every kill and stun until `until_tick`. `TUN-RESPAWN-INVULN`.
##
## **Long enough to orient and no longer.** The tunable's own note: *"long enough
## to be abusable would be worse than none"* — a player who could act during it
## would have a free window to initiate from, which is the opposite of what
## briefly protecting them is for.
func protect(peer: int, until_tick: int) -> void:
	_protected[peer] = maxi(until_tick, int(_protected.get(peer, -1)))


func is_protected(peer: int, now: int) -> bool:
	return now < int(_protected.get(peer, -1))


func protection_remaining(peer: int, now: int) -> int:
	return maxi(int(_protected.get(peer, -1)) - now, 0)


func clear() -> void:
	_stagger.clear()
	_exile.clear()
	_protected.clear()


## How many pairs are currently exiled at `now`. For tests and for a readout.
func exiles_live(now: int) -> int:
	var n := 0
	for hunter: int in _exile.keys():
		for target: int in (_exile[hunter] as Dictionary).keys():
			if remaining(hunter, target, now) > 0:
				n += 1
	return n
