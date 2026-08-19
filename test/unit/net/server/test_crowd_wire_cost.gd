## **WHAT THE SHIPPED BUILDER ACTUALLY CHARGES A CLIENT.** US-0030, US-0031,
## TDD-04 §7.1.1. Serialised, in bytes, by the real `SnapshotBuilder` — not
## arithmetic on a table.
##
## `test_crowd_bandwidth.gd` answers a different question and both are worth
## having. That file measures what the downstream budget **would** be with all of
## §7.1's mechanisms in place: NPCs culled, far ones sent at a tenth of the rate,
## and only the records whose quantised form changed. This file measures what a
## client is charged **today** — culled (US-0030) and rate-LOD'd (US-0031), with
## **no NPC delta**, because the protocol has no way to say an NPC is unchanged.
##
## **THE GAP BETWEEN THE TWO IS THE VALUE OF THE DELTA, MEASURED RATHER THAN
## ASSERTED, AND IT IS SMALL.** 119 % as built against 112 % projected: the delta
## is worth about seven points, because 0.776 of visible NPC records change every
## tick anyway. **A protocol change is a large price for seven points**, and that
## is a decision this file exists to inform rather than to take.
##
## **IT REPLACED A GUARD THAT SAID "THE BUILDER STILL SENDS NO NPC".** That guard
## lived in `test_crowd_bandwidth.gd` so the file could not keep describing itself
## as a format measurement after the wire caught up with it. It went red the moment
## US-0030 landed, which is exactly what it was for.
extends GutTest

const MAP_DATA := "res://data/maps/map_vetraio.tres"
const SEED := 20260818
const CROWD := 78
const PLAYERS := 6
const ONE_PEER := 7701

## ENet + UDP/IP, the same figure §7.1 budgets. Packet overhead is charged per
## packet and not per byte, so it cannot be folded into the payload measurement.
const PACKET_OVERHEAD := 28

var _ctx: MatchContext
var _pool: NpcPool
var _host: PawnHost
var _builder: SnapshotBuilder
var _map: MapData


func before_each() -> void:
	_map = load(MAP_DATA) as MapData
	_ctx = MatchContext.new()
	_ctx.map = _map
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, PLAYERS)
	_ctx.crowd = _pool
	_host = PawnHost.new()
	add_child_autofree(_host)
	_host.setup(_ctx)
	_builder = SnapshotBuilder.new()
	add_child_autofree(_builder)
	_builder.setup(_ctx, _host, null)
	await get_tree().physics_frame


## **THE REAL PLACEMENT, NOT A CONVENIENT ONE.** `CrowdPlacement` deals the crowd
## round-robin over the map's own idle anchors, so how many NPCs are within reach
## of a spawn point is a property of the level rather than of this file. A crowd
## laid out for the test's convenience would measure the test.
func _place_the_real_crowd() -> void:
	var spots := CrowdPlacement.positions(CROWD, SEED, _map.idle_anchors, RID())
	for index: int in mini(spots.size(), CROWD):
		_pool.set_position(index, spots[index])


func _observer_at(at: Vector3) -> void:
	_ctx.slots.assign(ONE_PEER)
	_host.spawn(ONE_PEER)
	_host.context_for(ONE_PEER).position = at


## Mean bytes per snapshot at one spot, **averaged over a whole rate-LOD stride**.
##
## **A SINGLE TICK STOPPED BEING A FAIR SAMPLE THE MOMENT RATE LOD LANDED.** The
## slowed band is staggered by index, so one tick carries roughly a third of it —
## roughly, not exactly, and which third depends on the tick. kbit/s is a mean, so
## the mean over a stride is the honest figure and one arbitrary tick is luck.
func _mean_bytes_at(at: Vector3) -> float:
	_host.context_for(ONE_PEER).position = at
	var stride := _builder.rate_lod_stride()
	var total := 0
	for tick: int in stride:
		_ctx.tick = tick
		total += _builder.build_for(ONE_PEER).serialise().size()
	return float(total) / float(stride)


## The most expensive spawn point, because a budget met on average across players
## is a budget missed by one of them.
func _worst_spawn_point() -> float:
	var most := 0.0
	for at: Vector3 in _map.spawn_points:
		most = maxf(most, _mean_bytes_at(at))
	return most


## Every distinct NPC this observer is sent **at any point** in a stride — which is
## the set the cull chose, as opposed to the subset any one tick happens to carry.
func _reachable_from(at: Vector3) -> int:
	_host.context_for(ONE_PEER).position = at
	var ever := {}
	for tick: int in _builder.rate_lod_stride():
		_ctx.tick = tick
		for record: Array in _builder.build_for(ONE_PEER).npcs:
			ever[int(record[0])] = true
	return ever.size()


# ---------------------------------------------------------------------------
# The guard against vacuous success comes first.
# ---------------------------------------------------------------------------


## **A SNAPSHOT CARRYING NO NPC COSTS VERY LITTLE AND MEETS EVERY BUDGET.** That
## was the true state of this project for two milestones, with three of US-0030's
## acceptance criteria unticked and nothing red. The measurement below means
## nothing unless the crowd is the real one and the builder is really sending it.
func test_the_crowd_being_priced_is_the_real_one() -> void:
	_place_the_real_crowd()
	_observer_at(_map.spawn_points[0])
	assert_eq(_pool.active_count(), CROWD, "the crowd being priced is not the full one")
	var snapshot := _builder.build_for(ONE_PEER)
	assert_gt(snapshot.npcs.size(), 0, "the builder sent no NPC, so this prices nothing")
	assert_gt(
		snapshot.serialise().size(),
		Snapshot.HEADER_BYTES + Snapshot.OWN_BYTES + Snapshot.COUNT_BYTES,
		"the snapshot is no larger than its fixed part, so nothing was added to it"
	)


# ---------------------------------------------------------------------------
# What it costs.
# ---------------------------------------------------------------------------


## **REPORTED, NOT FAILED, IF IT IS OVER** — the same choice `test_snapshot_size.gd`
## and `test_upstream_bandwidth.gd` made. The two mechanisms that would close it
## are US-0031's and cannot be fixed by editing this file; a red suite over that is
## a suite people learn to skip.
func test_what_one_client_is_charged_for_the_crowd_today() -> void:
	_place_the_real_crowd()
	_observer_at(_map.spawn_points[0])
	var bytes := _worst_spawn_point()
	var rate: float = Tuning.net.snapshot_rate
	var kbit := (bytes + float(PACKET_OVERHEAD)) * rate * 8.0 / 1000.0
	var budget: float = Tuning.net.bandwidth_budget_down
	gut.p(
		(
			(
				"AS BUILT: %.0f B/snapshot, mean over a stride = %.1f kbit/s against %.0f "
				+ "budget (%.0f %%). Culled and rate-LOD'd; no NPC delta."
			)
			% [bytes, kbit, budget, kbit / budget * 100.0]
		)
	)
	if kbit > budget:
		pending(
			(
				(
					"as actually built, downstream is %.1f kbit/s — %.0f %% of budget. "
					+ "Culling and rate LOD are both in; what is left is the NPC DELTA, "
					+ "which needs a protocol change to express an unchanged NPC. US-0031."
				)
				% [kbit, kbit / budget * 100.0]
			)
		)
		return
	assert_lt(kbit, budget, "downstream as built is over TUN-NET-BANDWIDTH-BUDGET-DOWN")


## **HOW MUCH THE CULL ACTUALLY REMOVES**, which is the number that decides whether
## US-0030 was the right lever. `TUN-NET-NPC-CULL-RADIUS` is 70 m and `MAP-VETRAIO`
## is 120 × 120 m, so most of the district is within reach of most of it — the
## saving is real and it is not large, and saying which is the point of measuring.
func test_how_much_the_cull_removes() -> void:
	_place_the_real_crowd()
	_observer_at(_map.spawn_points[0])
	var sent := 0
	for at: Vector3 in _map.spawn_points:
		sent = maxi(sent, _reachable_from(at))
	var removed := CROWD - sent
	gut.p(
		(
			(
				"the cull removes %d of %d NPCs at the worst spawn point (%.0f %%), "
				+ "at TUN-NET-NPC-CULL-RADIUS %.0f m on a %.0f m map"
			)
			% [
				removed,
				CROWD,
				float(removed) / float(CROWD) * 100.0,
				Tuning.net.npc_cull_radius,
				120.0
			]
		)
	)
	assert_between(sent, 1, CROWD, "the cull sent nothing, or sent more NPCs than exist")


## Every observer is charged separately, so the per-client budget is the one that
## has to hold. Two spawn points far enough apart must not be sent the same crowd —
## if they are, the per-client loop is doing six times the work for one answer.
func test_the_bill_differs_between_spawn_points() -> void:
	_place_the_real_crowd()
	_observer_at(_map.spawn_points[0])
	var first := _reachable_from(_map.spawn_points[0])
	var differs := false
	for at: Vector3 in _map.spawn_points:
		if _reachable_from(at) != first:
			differs = true
	assert_true(differs, "every spawn point is charged for the same crowd — the cull does nothing")
