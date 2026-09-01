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
## | Compass, render state, cooldowns | M4's systems — the fields exist and read zero |
##
## **SUSPICION, TIER AND THE SOURCE BITFIELD ARE FILLED AS OF US-0052**, from the
## pawn's own context. They cost nothing on the wire: the own block is sent in
## full every tick and those three bytes were already in it.
class_name SnapshotBuilder
extends Node

## **PER-CLIENT ACKNOWLEDGED-SNAPSHOT BOOKKEEPING**, US-0031's first criterion.
## Pure and separable, so what a delta omits can be asked directly.
var delta := SnapshotDelta.new()

## **THE CROWD'S OWN BASELINE, AND IT COULD NOT SHARE THE ONE ABOVE.** `SnapshotDelta`
## keys by tick, which is right for pawns because every pawn is offered every tick.
## A rate-LOD'd NPC is offered on one tick in three and would read as "new" on every
## one of them. `NpcDelta` keys per NPC and advances on the ack. TDD-04 §7.1.2.
var crowd_delta := NpcDelta.new()

## `SYS-ABILITY`, for the owner's own cooldowns. **Optional**: every snapshot test
## written before US-0066 builds this without one, and a null means both cooldowns
## read zero — which is what a match with no abilities should say.
##
## **THERE IS NO FIELD IN THE FORMAT FOR ANOTHER PLAYER'S COOLDOWNS**, which is the
## rule living in the wire rather than in a filter — **kit-reading is a skill**
## (GDD-04 §5.1), and a hunter who could see your Lunge was down would simply wait.
var abilities: AbilitySystem = null

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
	crowd_delta.note_ack(peer, tick)


## Release a departed peer's baselines. ENet reuses ids, so a baseline left
## behind would be delta-ed against by whoever inherits the id — US-0037.
func forget(peer: int) -> void:
	delta.forget(peer)
	crowd_delta.forget(peer)


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
	# **WHAT THE CULL REMOVED, KEPT SEPARATELY FROM WHAT THE RATE MERELY DELAYED.**
	# The two look identical in the snapshot and mean opposite things to the
	# baseline: a culled NPC is one the client will discard, a rate-skipped one is
	# one it still holds.
	var culled := PackedInt32Array()
	var offered := _choose(crowd, peer, own.position, snapshot.server_tick, culled)
	# **THE FAREWELL GOES OUT BEFORE THE BASELINE IS CLEARED, AND THE ORDER IS THE
	# WHOLE TRICK.** `changed` sends it because the position differs; `drop` then
	# forgets it, so an NPC that comes back is re-sent in full rather than withheld
	# as already-held.
	for record: Array in crowd_delta.changed(peer, snapshot.server_tick, offered):
		snapshot.add_npc(record[0], record[1], record[2], record[3], record[4])
	crowd_delta.drop(peer, culled)


## Which NPC records this observer is owed this tick, and which the cull removed.
##
## **THREE DISTANCES, NOT ONE.** An NPC is admitted inside `readmit_margin()` of
## the cull radius, kept until it passes the radius itself, and sent at a reduced
## rate beyond `TUN-NET-NPC-RATE-LOD-RADIUS`. The gap between admitting and
## dropping is hysteresis: without it an NPC parked on the boundary is created and
## freed on the client every tick, because nothing in a crowd is ever exactly
## still — RVO may shove a standing body at up to 0.1 m/s so a walking group does
## not walk through an idle cluster.
func _choose(crowd: NpcPool, peer: int, eye: Vector3, tick: int, culled: PackedInt32Array) -> Array:
	var beyond: float = Tuning.net.npc_cull_radius ** 2
	var admit: float = (Tuning.net.npc_cull_radius - readmit_margin()) ** 2
	var slowed: float = Tuning.net.npc_rate_lod_radius ** 2
	var stride := rate_lod_stride()
	var offered: Array = []
	for index: int in crowd.active_count():
		var at := crowd.position_of(index)
		var dx := at.x - eye.x
		var dz := at.z - eye.z
		var away := dx * dx + dz * dz
		var held := crowd_delta.holds(peer, index)
		if not held and away > admit:
			continue
		if away > beyond:
			culled.append(index)
			# **ONE FINAL RECORD, IF THE CLIENT IS HOLDING THIS ONE.** Absence cannot
			# say "gone": the last position a client was told is inside the radius by
			# definition, so its own distance check never fires and the NPC is drawn
			# frozen at the boundary for the rest of the match.
			if held:
				offered.append(_record(crowd, index, at))
			continue
		if away > slowed and (tick + index) % stride != 0:
			continue
		offered.append(_record(crowd, index, at))
	return offered


func _record(crowd: NpcPool, index: int, at: Vector3) -> Array:
	return [index, at, _yaw_of(crowd, index), _anim_of(crowd, index), 0]


## **HOW FAR INSIDE THE RADIUS AN NPC MUST COME BACK TO BE RE-ADMITTED.**
##
## Leaving is decided at `TUN-NET-NPC-CULL-RADIUS`; returning is decided one margin
## inside it. Without the gap, an NPC parked on the boundary is created and freed
## on the client every tick, because nothing in a crowd is ever exactly still.
##
## **IT IS THE SAME NUMBER `NpcView.drop_margin()` USES, AND FOR THE SAME REASON** —
## the furthest the observer and a drawn NPC can drift apart across one
## `TUN-NET-INTERP-BUFFER` at `TUN-SPEED-SPRINT`. The two are asserted equal rather
## than shared, because the server may not reach into `scripts/presentation/`.
func readmit_margin() -> float:
	return Tuning.net.interp_buffer / 1000.0 * Tuning.movement.sprint


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

	# **THE OWN-GAMEPLAY BLOCK, TO THE OWNER AND NOBODY ELSE** (US-0052). There is
	# no field anywhere else in the format for another player's suspicion, tier or
	# sources — an observer learns `render_state`, two bits, and that is the whole
	# of it. The rule is the format's rather than a filter's, which is why it
	# cannot be broken by a later caller.
	snapshot.suspicion = own.suspicion
	snapshot.tier = own.tier
	snapshot.active_sources = own.active_sources
	snapshot.blend_state = own.blend_state
	snapshot.kill_ready = own.kill_ready
	snapshot.stun_ready = own.stun_ready
	_fill_cooldowns(snapshot, peer)
	_fill_pursuit(snapshot, peer)

	# **THE COMPASS BLOCK, BUCKETED AND WOBBLED BEFORE IT GOT HERE** (US-0057).
	# `SYS-DETECTION` decided both at the `detection` stage; this reads them. The
	# bearing is a **world** angle the client rotates into view space itself, and
	# the distance is a bucket, so nothing downstream can recover a precision the
	# server refused to send. `lock_fraction` is a byte of the arc and
	# `portrait_revealed` is ASM-0030's earned identification, both US-0058's.
	snapshot.bearing = Quantise.yaw_to_u8(_ctx.compass.bearing_of(peer))
	snapshot.distance_bucket = _ctx.compass.bucket_of(peer)
	snapshot.lock_fraction = int(round(_ctx.compass.lock_of(peer) * 255.0))
	snapshot.portrait_revealed = _ctx.compass.portrait_of(peer)


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
		# **"NOT RENDERED AT ALL"** — GDD-03 §4.1.4, US-0054. A player inside a
		# concealment prop leaves `present_slots` entirely, which is the one thing
		# absence in this format still means: `RemotePawns` frees the body. Omitting
		# only the *record* would leave them drawn at their last position, which is a
		# worse lie than not drawing them.
		#
		# **They rejoin in full when they step out**, because dropping out of
		# `everyone` also drops them from the baseline `delta.remember` keeps — the
		# same shape as the crowd's farewell.
		if ctx.blend_state == BlendKind.Kind.PROP_CONCEAL:
			continue
		# **PER OBSERVER, WHICH IS THE WHOLE REASON THIS IS NOT A BROADCAST.** The
		# same player at the same suspicion is `PLAIN` to four people and `HARD` to
		# one, simultaneously — `SYS-DETECTION` decided that at the `detection`
		# stage and the matrix carries it here. Absent means `PLAIN`.
		var seen := _ctx.render_states.state_of(peer, other)
		everyone.append([slot, ctx.position, ctx.yaw, ctx.state_id, 0, seen])

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


## **YOUR OWN COOLDOWNS AND NOBODY ELSE'S** — see the `abilities` field above.
## Split out for the length guard, and the seam is the one the format already
## draws: this is the only part of the own-gameplay block that comes from a system
## rather than from the pawn.
func _fill_cooldowns(snapshot: Snapshot, peer: int) -> void:
	if abilities == null:
		return
	snapshot.cooldown_a_tick = abilities.cooldown_ticks(peer, 0)
	snapshot.cooldown_b_tick = abilities.cooldown_ticks(peer, 1)


## **BOTH SIDES OF A CHASE, TO THE ONE PLAYER EACH IS ABOUT** (US-0097, ADR-0014).
##
## `hunt_fraction` is read for the observer directly — they are the hunter of their
## own chase. `hunted_fraction` needs a reverse lookup, which is a scan of at most
## six rows, because `PursuitBoard` is keyed on the hunter: a cycle gives every
## player exactly one outgoing edge, so that is the key that cannot go stale.
##
## **NOBODY IS NAMED IN EITHER DIRECTION.** The observer is told a bar and never
## whose finger is on it — and they already knew a pursuer existed, because
## `NET-S2C-PREY-WARNING` fired on the same condition that opened the chase.
func _fill_pursuit(snapshot: Snapshot, peer: int) -> void:
	var full := Tuning.ticks(&"TUN-PURSUIT-DURATION")
	snapshot.hunt_fraction = _byte(_ctx.pursuit.fraction_of(peer, full))
	# **`NOBODY` IS ZERO AND ZERO IS A DICTIONARY KEY LIKE ANY OTHER.** No engine
	# peer id is ever 0 so the lookup would miss anyway, but resting a rule on that
	# is `CompassBoard.NO_CONTRACT`'s hazard exactly: the safe default must be
	# stated, not inherited from a coincidence about the id space.
	var pursuer := _ctx.pursuit.hunter_of(peer)
	if pursuer == ContractCycle.NOBODY:
		snapshot.hunted_fraction = 0
		return
	snapshot.hunted_fraction = _byte(_ctx.pursuit.fraction_of(pursuer, full))


## A `[0, 1]` fraction as the byte the wire carries. `lock_fraction`'s own rounding,
## said once rather than twice.
func _byte(fraction: float) -> int:
	return clampi(int(round(fraction * 255.0)), 0, 255)
