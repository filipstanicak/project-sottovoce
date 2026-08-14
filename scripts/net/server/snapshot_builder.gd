## **ONE SNAPSHOT PER CLIENT, PER TICK.** TDD-04 §10, NETWORK_PROTOCOL §4.
## SERVER ONLY.
##
## Per client and not broadcast, because two of the fields cannot be shared:
## `render_state` is computed **per observer** — the same player at the same
## suspicion is `PLAIN` to four people and `HARD` to one — and the compass block
## is about the observer's own contract. A broadcast snapshot would have to carry
## everyone's answer to everyone, which is the leak GDD-03 §2.1 is built to
## prevent.
##
## **DELIBERATELY MINIMAL.** Culling is US-0030's, delta encoding is US-0031's,
## and there is no crowd to cull until M3. What this does is the part the rest
## depends on: walk the pawns, fill a `Snapshot`, hand it to `Net`. Every
## omission below is a story, not an oversight:
##
## | Missing | Whose |
## |---|---|
## | Distance culling and rate LOD | US-0030 |
## | Delta against the client's last ack | US-0031 |
## | Suspicion, tier, compass, render state | M3 and M4's systems — the fields exist and read zero |
## | NPCs | `SYS-CROWD`, M3 |
class_name SnapshotBuilder
extends Node

var _ctx: MatchContext
var _pawns: PawnHost
var _router: RpcRouter


func setup(ctx: MatchContext, pawns: PawnHost, router: RpcRouter) -> void:
	_ctx = ctx
	_pawns = pawns
	_router = router


## Build and send one tick's worth. Connected to `MatchDirector.tick_completed`,
## which is the `snapshot` stage of `SystemOrder` — **last**, so every record
## carries the positions this tick ended at rather than the ones it started with.
##
## **IT WAS CONNECTED TO `net_ticked` UNTIL US-0035, AND THAT SENTENCE WAS FALSE.**
## `net_ticked` fires before the stage loop, so a snapshot stamped tick N carried
## the world from the end of N-1. It was internally consistent — position and
## `last_acked_seq` agreed, and the measured reconciliation error was 0.00000 m —
## so the only symptom was that remote pawns rendered one tick staler than
## `TUN-NET-INTERP-BUFFER` promises. Found by probing the emission order while
## deciding where the lag-comp history should be stamped.
func send_all(_ctx_in: MatchContext, _dt: float) -> void:
	if _ctx == null or _pawns == null:
		return
	for peer: int in _ctx.pawns.keys():
		Net.send_snapshot(peer, build_for(peer))


## The snapshot `peer` should receive. Public so a test can read one without a
## socket.
func build_for(peer: int) -> Snapshot:
	var snapshot := Snapshot.new()
	snapshot.server_tick = _ctx.tick
	snapshot.phase = _ctx.phase
	if _router != null:
		snapshot.last_acked_seq = maxi(_router.last_acked_seq(peer), 0)
	_fill_own(snapshot, peer)
	_fill_remotes(snapshot, peer)
	return snapshot


## The observer's own pawn, in full. **NOT QUANTISED** — this is the authority
## their prediction is reconciled against.
func _fill_own(snapshot: Snapshot, peer: int) -> void:
	var own := _pawns.context_for(peer)
	if own == null:
		return
	snapshot.own_position = own.position
	snapshot.own_velocity = own.velocity
	snapshot.own_state = own.state_id
	snapshot.own_state_timer = own.state_timer_ticks
	snapshot.own_grounded = own.grounded


## Everybody else, by **slot**. The observer is skipped rather than filtered out
## later: a client that received itself as a remote pawn would render a second
## copy of itself 100 ms in the past, which is a memorable bug to look at and a
## tedious one to explain.
func _fill_remotes(snapshot: Snapshot, peer: int) -> void:
	for other: int in _ctx.pawns.keys():
		if other == peer:
			continue
		var ctx := _pawns.context_for(other)
		if ctx == null:
			continue
		var slot: int = _ctx.slots.slot_of(other)
		if slot == SlotTable.NO_SLOT:
			continue
		# `render_state` is 0 (`PLAIN`) for everyone until `SYS-DETECTION` lands in
		# M3. It is filled per observer HERE when it does — the loop is already
		# per observer, which is the whole reason this is not a broadcast.
		snapshot.add_remote(slot, ctx.position, ctx.yaw, ctx.state_id, 0, 0)
