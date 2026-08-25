## **THE INSTANT SOURCES, QUEUED AND DRAINED AT ONE PLACE IN THE TICK.**
## TDD-07 §2.2, GDD-03 §3.2, US-0052. PURE.
##
## A bump, a loud ability, a whiffed kill, a witnessed kill and an invalid stun
## are *events*: they happen at whatever pipeline position raised them, which is
## `combat` for three of them and `abilities` for another — both **after**
## `suspicion`. So an impulse raised this tick is spent at the top of the next
## one, and every impulse in a tick is spent together.
##
## **THE QUEUE IS THE SYSTEM'S, NOT THE PAWN'S, WHICH AMENDS TDD-07 §2.2.** That
## section says impulses "queue on `PawnContext`" — and `PawnContext` lives in
## `scripts/pawn/`, the code replayed during prediction reconciliation. A client
## replaying twenty commands would walk a queue of gameplay impulses twenty times,
## which is never-do #3 with a queue in front of it. Holding them here also makes
## the debounce a thing a test can *ask about* rather than infer, which is the
## lesson `RpcRouter` learned about keeping its own roster.
##
## **ORDER WITHIN A TICK CANNOT MATTER, AND THAT IS ARITHMETIC RATHER THAN
## DISCIPLINE.** Every impulse is positive and the sum is clamped once at the end,
## so `min(max, a + b)` is the answer whichever arrived first. A queue that
## clamped on each application would be order-independent too — but only for
## positive values, and the first negative impulse anybody adds would break it
## silently. Summing first is the version that stays true.
class_name SuspicionImpulses
extends RefCounted

## peer -> points owed at the next drain.
var _pending: Dictionary = {}

## peer -> the tick its last bump landed on. Absent means never.
var _last_bump: Dictionary = {}


## Owe `peer` a flat impulse. Negative values are refused rather than clamped: a
## *reduction* is decay's job or a blend's, and the two have different rules.
func queue(peer: int, points: float) -> void:
	if points <= 0.0:
		return
	_pending[peer] = float(_pending.get(peer, 0.0)) + points


## **ONE SHOVE INTO A GROUP IS NOT FIVE STACKED CHARGES.** US-0052's fourth
## criterion, and the only impulse with a debounce — the rest are gated by the
## cooldown or the attempt that raised them.
##
## Returns whether the bump landed, so a caller can tell "charged" from "inside
## the cooldown" without reading the queue. A silent no-op here would look
## identical to a caller that never fired.
func bump(peer: int, tick: int, t: SuspicionTuning) -> bool:
	# **AT LEAST ONE TICK**, so a cooldown tuned below the net tick still debounces
	# rather than degrading to no rule at all.
	var cooldown := maxi(Tuning.ticks(&"TUN-SUSPICION-GAIN-NPC-BUMP-COOLDOWN"), 1)
	if _last_bump.has(peer) and tick - int(_last_bump[peer]) < cooldown:
		return false
	_last_bump[peer] = tick
	queue(peer, t.gain_npc_bump)
	return true


## Everything owed to `peer`, taken away in one piece. Zero when nothing is owed.
func drain(peer: int) -> float:
	if not _pending.has(peer):
		return 0.0
	var owed := float(_pending[peer])
	_pending.erase(peer)
	return owed


## What `peer` is owed, without taking it. For tests and for a log line; the pass
## itself always drains.
func pending(peer: int) -> float:
	return float(_pending.get(peer, 0.0))


## Release a departed peer. **ENet reuses peer ids**, so an undrained impulse left
## behind would be charged to whoever inherits the id — US-0037's defect, in a
## dictionary nobody would think to check.
func forget(peer: int) -> void:
	_pending.erase(peer)
	_last_bump.erase(peer)


func clear() -> void:
	_pending.clear()
	_last_bump.clear()
