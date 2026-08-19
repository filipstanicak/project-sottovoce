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
## **THE CROWD IS ON THE WIRE AND CULLED AS OF US-0030**, and what that cost was
## measured rather than assumed: `test_crowd_wire_cost.gd` prices one client at
## **148.6 kbit/s against a 96 budget — 155 %**, with the cull removing 11 of 78
## NPCs. **Culling was not the lever**; §7.1's projection assumes an NPC delta and
## rate LOD and neither is built for NPCs. TDD-04 §7.1.1.
##
## Every omission below is a story, not an oversight:
##
## | Missing | Whose |
## |---|---|
## | Delta and rate LOD **for NPCs** | US-0031 — and it is now the whole gap |
## | Suspicion, tier, compass, render state | M3 and M4's systems — the fields exist and read zero |
class_name SnapshotBuilder
extends Node

## **PER-CLIENT ACKNOWLEDGED-SNAPSHOT BOOKKEEPING**, US-0031's first criterion.
## Pure and separable, so what a delta omits can be asked directly.
var delta := SnapshotDelta.new()

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


## The client says which snapshot tick it holds. Connected to
## `RpcRouter.snapshot_acked`.
func note_ack(peer: int, tick: int) -> void:
	delta.note_ack(peer, tick)


## Release a departed peer's baselines. ENet reuses ids, so a baseline left
## behind would be delta-ed against by whoever inherits the id — US-0037.
func forget(peer: int) -> void:
	delta.forget(peer)


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
	_fill_crowd(snapshot, peer)
	return snapshot


## **THE CROWD THIS OBSERVER CAN REACH, AND NOBODY ELSE'S.** US-0030.
##
## **POSITIONAL, NEVER VISUAL**, which is a design law and not an optimisation.
## Culling on line of sight would make the set of NPCs a client holds depend on
## where they are looking, so an NPC would pop into existence when a player turns
## their head — and worse, a player could infer *from the popping* that they had
## just been given a fresh piece of world. Distance is a fact about the district;
## facing is a fact about the player, and GDD-03 §2.1 keeps those apart.
##
## Horizontal and squared, like every other radius in this project: a clone on a
## balcony is not further away in any sense replication cares about, and nothing
## here wants a distance — only an ordering against a radius.
##
## **THE INDEX IS THE POOL'S OWN, NOT A COMPACTED ONE.** A client that received
## "the third NPC near me" could not tell the same NPC apart between two ticks,
## which is exactly what interpolation needs to do. `u8` holds the pool's index up
## to 255 and `TUN-CROWD-COUNT-MAX` is 90.
func _fill_crowd(snapshot: Snapshot, peer: int) -> void:
	var crowd: NpcPool = _ctx.crowd
	var own := _pawns.context_for(peer)
	if crowd == null or own == null:
		return
	var beyond: float = Tuning.net.npc_cull_radius * Tuning.net.npc_cull_radius
	var slowed: float = Tuning.net.npc_rate_lod_radius * Tuning.net.npc_rate_lod_radius
	var stride := rate_lod_stride()
	for index: int in crowd.active_count():
		var at := crowd.position_of(index)
		var dx := at.x - own.position.x
		var dz := at.z - own.position.z
		var away := dx * dx + dz * dz
		if away > beyond:
			continue
		if away > slowed and (snapshot.server_tick + index) % stride != 0:
			continue
		snapshot.add_npc(index, at, _yaw_of(crowd, index), _anim_of(crowd, index), 0)


## Ticks between sends for an NPC past `TUN-NET-NPC-RATE-LOD-RADIUS`. US-0031,
## TDD-04 §7.2.
##
## **DERIVED FROM THE TWO RATES, NEVER DECLARED AS 3.** A literal stops meaning
## what it says the first time either rate is retuned, and nothing would report
## it: the crowd would simply be replicated at a rate no tunable describes.
##
## Never below one. Invariant 31 already refuses a far rate above the snapshot
## rate, so the clamp is for the tick a profile is being adopted rather than for a
## profile that survived validation.
func rate_lod_stride() -> int:
	var full: float = Tuning.net.snapshot_rate
	var reduced: float = Tuning.net.npc_rate_lod_hz
	if reduced <= 0.0:
		return 1
	return maxi(int(round(full / reduced)), 1)


## The brain's state stands in for the animation state, and the phase is zero.
##
## **SAID RATHER THAN LEFT TO BE DISCOVERED.** The wire carries `u3 + u5` — a
## state and a phase within it — and there is **no animation in this project on
## either rig**, so there is no phase to send and nothing on the client to play
## one. The state is real and is what a clone's `AnimationTree` would be driven
## from; the phase is a zero that will stop being one in US-0046. Sending the
## state now is what lets a client interpolate a crowd at all.
func _anim_of(crowd: NpcPool, index: int) -> int:
	var brain := crowd.brain_of(index)
	return int(brain.state) if brain != null else 0


func _yaw_of(crowd: NpcPool, index: int) -> float:
	var body := crowd.body_of(index)
	return body.global_rotation.y if body != null else 0.0


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
	var everyone: Array = []
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
		everyone.append([slot, ctx.position, ctx.yaw, ctx.state_id, 0, 0])

	# **WHO EXISTS IS STATED; WHO MOVED IS SENT.** The mask is built from every
	# visible player, the records from only those whose quantised state changed —
	# so a player omitted for standing still is still known to be there, and one
	# who left is not.
	snapshot.present_slots = _mask(everyone)
	snapshot.baseline_age = delta.baseline_age(peer, snapshot.server_tick)
	for record: Array in delta.changed(peer, snapshot.server_tick, everyone):
		snapshot.remote_pawns.append(record)
	delta.remember(peer, snapshot.server_tick, everyone)


static func _mask(records: Array) -> int:
	var mask := 0
	for record: Array in records:
		var slot := int(record[0])
		if slot > 0 and slot <= 8:
			mask |= 1 << (slot - 1)
	return mask
