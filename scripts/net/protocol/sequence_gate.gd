## Drops stale and replayed input. NETWORK_PROTOCOL §2, US-0026.
##
## PURE. One `u16` per peer, and the whole difficulty is in that `u16`.
##
## **A SEQUENCE NUMBER WRAPS, SO "NEWER" IS NOT "GREATER".** `seq` is 16 bits and
## the client sends 60 a second, so it wraps roughly every 18 minutes — inside a
## single match. A gate written as `seq > last` works perfectly for eighteen
## minutes and then rejects **every** input for the next eighteen, because 0 is
## not greater than 65535. The player's pawn simply stops responding, on a server
## logging nothing, and nothing about the code looks wrong.
##
## The fix is the standard one: compare the *signed* distance in modular
## arithmetic. Anything within half the range ahead is newer; anything else is
## older. That is symmetric, wrap-free, and has no special case at the boundary.
##
## Why it exists at all: UDP reorders. Without the gate an input from two ticks
## ago arrives after a fresher one and is applied on top of it, which reads as
## the pawn twitching backwards — and a replayed packet becomes a *repeated*
## action, which is a client asserting an outcome by saying it twice.
class_name SequenceGate
extends RefCounted

## `u16`. The wire width, not a buffer size.
const RANGE := 65536
const HALF := 32768

var _last: Dictionary = {}


## True if `seq` is newer than everything seen from `peer`, which also records
## it. **CONSUMING** — a caller that asked is a caller that will act.
func accept(peer: int, seq: int) -> bool:
	var clean := seq & (RANGE - 1)
	if not _last.has(peer):
		_last[peer] = clean
		return true
	if not is_newer(clean, int(_last[peer])):
		return false
	_last[peer] = clean
	return true


## Whether `seq` is ahead of `last`, across the wrap. Static and separate from
## the bookkeeping, so the arithmetic can be tested at the boundary without
## constructing a peer.
static func is_newer(seq: int, last: int) -> bool:
	return ((seq - last + HALF) & (RANGE - 1)) - HALF > 0


## The newest sequence seen from `peer`, or -1 for a peer never heard from.
## The snapshot header's `last_acked_seq` is this number (TDD-04 §6.3).
func last_seen(peer: int) -> int:
	return int(_last.get(peer, -1))


## Drop a peer that left. ENet reuses peer ids, so a stale entry would make the
## next joiner's first eighteen minutes of input arrive "in the past".
func forget(peer: int) -> void:
	_last.erase(peer)


func clear() -> void:
	_last.clear()
