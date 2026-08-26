## **TWO PEOPLE PRESSED KILL ON THE SAME PLAYER.** ADR-0010, TDD-04 §8.4,
## TDD-10 §3, US-0060. PURE Core.
##
## **RESOLVED BY SERVER RECEIVE ORDER, AND THERE IS NOWHERE HERE TO PUT A CLIENT
## CLOCK.** `claim()` takes a server tick and an arrival ordinal, both stamped by
## the server as the packet landed. `InputCommand` carries no client clock at all
## — the two bytes that were `client_tick` became `acked_tick` in US-0031 — and
## `test_no_client_time_in_kill.gd` refuses any read of that field from combat
## code, because the *next* forgeable ordering is the one nobody notices.
##
## This is a real trade and ADR-0010 states it: **a low-ping player wins a genuine
## tie.** The alternative is comparing numbers a client chose, which hands the
## contest window to whoever lies best.
##
## **THE ORDINAL IS NOT DECORATION.** Two initiations in the same tick have to be
## separated by something, and the obvious candidates are both wrong: iteration
## order over `ctx.pawns` is *join* order, which would hand the earliest-joined
## player every tie for the whole match, and a seeded coin would make the most
## decisive moment in the game random. The ordinal is a monotonic counter stamped
## where arrival actually happens, in `MatchDirector.enqueue_input`, so a tie
## resolves by which packet the server read first — which is what "server receive
## order" says.
class_name KillContest
extends RefCounted

## victim -> `[killer, tick, ordinal]` of the initiation that holds the claim.
var _claims: Dictionary = {}


## Claim `victim` for `killer`. Returns true if this initiation wins.
##
## A claim older than `TUN-KILL-CONTEST-WINDOW` is not a contest at all — it is a
## previous, resolved attempt — and is simply replaced.
func claim(victim: int, killer: int, tick: int, ordinal: int) -> bool:
	var standing: Array = _claims.get(victim, [])
	if standing.is_empty() or _expired(standing, tick):
		_claims[victim] = [killer, tick, ordinal]
		return true
	if killer == int(standing[0]):
		# The same killer re-pressing inside the window. Not a contest with
		# themselves: they already hold the claim.
		return true
	if _earlier(tick, ordinal, int(standing[1]), int(standing[2])):
		_claims[victim] = [killer, tick, ordinal]
		return true
	return false


## Who currently holds the claim on `victim`, or `ContractCycle.NOBODY`.
func holder_of(victim: int) -> int:
	var standing: Array = _claims.get(victim, [])
	return ContractCycle.NOBODY if standing.is_empty() else int(standing[0])


## Drop the claim on `victim` — the attempt resolved, or the victim left.
func release(victim: int) -> void:
	_claims.erase(victim)


## Drop every claim by or on `peer`. A departing player must not keep a victim
## locked for the rest of the contest window, and must not still be somebody's
## contested target.
func forget(peer: int) -> void:
	release(peer)
	for victim: int in _claims.keys():
		if int((_claims[victim] as Array)[0]) == peer:
			_claims.erase(victim)


func count() -> int:
	return _claims.size()


func clear() -> void:
	_claims.clear()


func _expired(standing: Array, tick: int) -> bool:
	var window := maxi(Tuning.ticks(&"TUN-KILL-CONTEST-WINDOW"), 1)
	return tick - int(standing[1]) >= window


## Strictly earlier: a later tick never wins, and within one tick the lower
## arrival ordinal does.
static func _earlier(tick: int, ordinal: int, other_tick: int, other_ordinal: int) -> bool:
	if tick != other_tick:
		return tick < other_tick
	return ordinal < other_ordinal
