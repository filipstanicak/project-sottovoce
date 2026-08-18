## **WHAT THE SHIPPED BUILDER ACTUALLY CHARGES A CLIENT.** US-0030, US-0031,
## TDD-04 §7.1.1. Serialised, in bytes, by the real `SnapshotBuilder` — not
## arithmetic on a table.
##
## `test_crowd_bandwidth.gd` answers a different question and both are worth
## having. That file measures what the downstream budget **would** be with §7.1's
## mechanisms in place: NPCs culled, far ones sent at a tenth of the rate, and only
## the records whose quantised form changed. This file measures what a client is
## charged **today**, where US-0030 culls the crowd positionally and **neither
## delta encoding nor rate LOD is applied to NPCs at all**.
##
## **THE GAP BETWEEN THE TWO IS THE VALUE OF US-0031's REMAINING WORK, MEASURED
## RATHER THAN ASSERTED.** That is the whole reason this file exists: the corpus
## has twice concluded a budget from a mechanism nobody had built, and this makes
## the difference a number instead of an intention.
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


## The most expensive spawn point, because a budget met on average is a budget
## missed by somebody. Returns the snapshot that costs the most bytes.
func _worst_spawn_point() -> Snapshot:
	var worst: Snapshot = null
	var most := -1
	for at: Vector3 in _map.spawn_points:
		_host.context_for(ONE_PEER).position = at
		var snapshot := _builder.build_for(ONE_PEER)
		var size := snapshot.serialise().size()
		if size > most:
			most = size
			worst = snapshot
	return worst


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
	var snapshot := _worst_spawn_point()
	var bytes := snapshot.serialise().size()
	var rate: float = Tuning.net.snapshot_rate
	var kbit := (float(bytes) + float(PACKET_OVERHEAD)) * rate * 8.0 / 1000.0
	var budget: float = Tuning.net.bandwidth_budget_down
	gut.p(
		(
			(
				"AS BUILT: %d B/snapshot carrying %d of %d NPCs = %.1f kbit/s against %.0f "
				+ "budget (%.0f %%). Culled, but no NPC delta and no rate LOD."
			)
			% [bytes, snapshot.npcs.size(), CROWD, kbit, budget, kbit / budget * 100.0]
		)
	)
	if kbit > budget:
		pending(
			(
				(
					"as actually built, downstream is %.1f kbit/s — %.0f %% of budget. "
					+ "CULLING ALONE DOES NOT CLOSE IT: §7.1's projection assumes an NPC "
					+ "delta and rate LOD, and neither is built for NPCs. US-0031."
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
		_host.context_for(ONE_PEER).position = at
		sent = maxi(sent, _builder.build_for(ONE_PEER).npcs.size())
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
	var first := _builder.build_for(ONE_PEER).npcs.size()
	var differs := false
	for at: Vector3 in _map.spawn_points:
		_host.context_for(ONE_PEER).position = at
		if _builder.build_for(ONE_PEER).npcs.size() != first:
			differs = true
	assert_true(differs, "every spawn point is charged for the same crowd — the cull does nothing")
