## **AT MOST `TUN-PERF-CROWD-REPATH-PER-TICK` PATH QUERIES A TICK.** TDD-08 §12
## question 2, US-0041. SERVER ONLY, and PURE — no agent, no node, no navigation
## server, so "is it actually staggered?" is a question a unit test can ask.
##
## **A PATH QUERY IS THE CROWD'S ONLY UNBOUNDED PER-AGENT COST.** Everything else
## a brain does is a compare and a decrement. Recast pathfinding is not: it walks
## a polygon graph, and ninety of those arriving in the same tick is a server
## *hitch* rather than a slow tick — which in this game is a lost kill, because
## kill and stun are decided at 2.5 m inside a 0.4 s window.
##
## **FIFO, WHICH IS WHAT MAKES IT STARVATION-FREE.** A queue that picked the
## nearest, or the oldest by state, would leave somebody at the back forever
## under load — and an NPC waiting forever for a path is an NPC standing still
## in a city, which is the most legible defect the crowd can have. The order out
## is the order in, and a second request from an NPC already waiting is dropped
## rather than moving it.
class_name RepathQueue
extends RefCounted

## Indices waiting, oldest first.
var _waiting: Array[int] = []

## Membership, so `request()` is a constant-time duplicate check rather than a
## linear scan across ninety entries every tick.
var _queued: Dictionary = {}


## Ask for a path. **A repeat request while already waiting is ignored**, which
## is what stops a state that re-requests every tick from filling the queue with
## itself and starving everyone behind it.
func request(index: int) -> void:
	if _queued.has(index):
		return
	_queued[index] = true
	_waiting.append(index)


## Up to `limit` indices, oldest first, removed from the queue.
##
## A non-positive limit serves nobody rather than everybody: a misconfigured
## budget should stop the crowd visibly, not remove the cap silently.
func take(limit: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if limit <= 0:
		return out
	while not _waiting.is_empty() and out.size() < limit:
		var index: int = _waiting.pop_front()
		_queued.erase(index)
		out.append(index)
	return out


func pending() -> int:
	return _waiting.size()


func is_waiting(index: int) -> bool:
	return _queued.has(index)


## Drop everything. Called at match end — a queue that survived into the next
## match would hand the first tick a list of indices from a crowd that no longer
## exists.
func clear() -> void:
	_waiting.clear()
	_queued.clear()
