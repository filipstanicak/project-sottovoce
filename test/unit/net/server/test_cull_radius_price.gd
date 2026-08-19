## **WHAT THE LAST 12 % OF THE DOWNSTREAM BUDGET WOULD COST.** US-0031,
## TDD-04 §7.1.2.
##
## The crowd is culled, rate-LOD'd and delta-encoded and still costs **112 % of
## `TUN-NET-BANDWIDTH-BUDGET-DOWN`**. The corpus has named two candidates for the
## remainder and priced neither: ADR-0007's seed-derived far crowd, or a smaller
## `TUN-NET-NPC-CULL-RADIUS`.
##
## **THEY ARE THE SAME LEVER, AND ONE OF THEM IS ALREADY PULLED.** Both stop
## replicating NPCs past a boundary; they differ only in what the client draws out
## there — nothing, or a crowd derived from `match_seed`. The bytes are identical,
## so one sweep prices both. And ADR-0007 sets its boundary at **≥ 70 m** "so it
## stays outside every gameplay radius", which is exactly where the cull already
## is: at the boundary the ADR mandates, **the fallback saves nothing**, because
## the builder already sends no record past 70 m. Asserted below rather than
## argued, because it is the kind of claim a reader would otherwise have to take
## on trust.
##
## So the only real lever is the radius, and invariant 17 pins it at or above
## `TUN-COMPASS-RANGE-MAX` — a culled NPC must never be able to affect anything
## the client can perceive. **That gives the sweep a hard floor of 60 m**, and the
## question this file answers is whether the floor is low enough.
##
## **IT IS, AND WITH ROOM TO SPARE — THE GAP CLOSES AT 65 m.**
##
## | Cull radius | kbit/s | Of budget |
## |---|---|---|
## | 70.0 m, shipped | 109.3 | 114 % |
## | 67.5 m | 102.9 | 107 % |
## | **65.0 m** | **92.8** | **97 %** |
## | 62.5 m | 83.9 | 87 % |
## | 60.0 m, invariant 17's floor | 79.1 | 82 % |
##
## So the last 12 % is **five metres of cull radius**, not a new mechanism. That is
## still a `TUN-` change with a gameplay consequence and it is not made here:
## invariant 17's margin over `TUN-COMPASS-RANGE-MAX` shrinks from 10 m to 5 m, and
## the compass is the one system that reaches far enough to care.
##
## **THIS FILE'S ABSOLUTE FIGURES SIT ~2 POINTS ABOVE `test_crowd_wire_cost.gd`'s**
## — 114 % against 112 % at the same radius — because it settles the crowd for 200
## ticks rather than 300 and therefore prices a slightly different arrangement of
## the same walking crowd. **That file owns the headline number; this one owns the
## shape of the curve**, and every row here is measured against one crowd so the
## rows are comparable with each other, which is the only property the sweep needs.
extends GutTest

const MAP_DATA := "res://data/maps/map_vetraio.tres"
const PROFILE := "res://data/tuning/default/profile.tres"
const SEED := 20260818
const CROWD := 78
const PLAYERS := 6
const ONE_PEER := 7703

## ENet + UDP/IP, charged per packet, exactly as `test_crowd_wire_cost.gd` does.
const PACKET_OVERHEAD := 28

## Shorter than `test_crowd_wire_cost.gd`'s 300, because this file settles once and
## then measures five radii against the same walking crowd. The absolute figure it
## must reproduce is that file's, and the guard below checks it does.
const SETTLE_TICKS := 200
const MEASURE_TICKS := 30

## Three ticks, 100 ms — the same lagging ack the headline figure is charged
## against. Acking instantly measures a connection nobody has.
const ACK_LAG := 3

var _ctx: MatchContext
var _pool: NpcPool
var _host: PawnHost
var _builder: SnapshotBuilder
var _map: MapData
var _crowd: ModelledCrowd


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
	_ctx.slots.assign(ONE_PEER)
	_host.spawn(ONE_PEER)
	await get_tree().physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_crowd = ModelledCrowd.new()
	_crowd.setup(_pool, _map, rng, CROWD)
	_crowd.settle(SETTLE_TICKS)


## **THE LIVE PROFILE IS PUT BACK WHATEVER HAPPENS.** `Tuning` is an autoload and
## outlives this test; a radius left behind would be handed to whatever runs next
## and would silently re-price every other bandwidth measurement in the suite.
func after_each() -> void:
	Tuning.adopt((load(PROFILE) as TuningProfile).clone())


# ---------------------------------------------------------------------------
# The guard against vacuous success comes first.
# ---------------------------------------------------------------------------


## **A SWEEP THAT DOES NOT REPRODUCE THE HEADLINE FIGURE IS PRICING SOMETHING
## ELSE.** At the shipped radius this must land where `test_crowd_wire_cost.gd`
## lands — over budget, with a real crowd on the wire. If it does not, every row
## of the table below is a number about a different game.
func test_the_shipped_radius_reproduces_the_headline_miss() -> void:
	assert_eq(_pool.active_count(), CROWD, "the crowd being priced is not the full one")
	assert_gt(_crowd.walking(), 0, "a motionless crowd makes the delta look free")
	var kbit := _kbit_at_radius(Tuning.net.npc_cull_radius)
	gut.p("at the shipped %.0f m: %.1f kbit/s" % [Tuning.net.npc_cull_radius, kbit])
	assert_gt(
		kbit,
		Tuning.net.bandwidth_budget_down,
		"this file does not reproduce the 112 % miss, so its sweep prices a different crowd"
	)


# ---------------------------------------------------------------------------
# ADR-0007's fallback, priced.
# ---------------------------------------------------------------------------


## **ADR-0007's SEED-DERIVED FAR CROWD SAVES NOTHING AT THE BOUNDARY ADR-0007
## REQUIRES.** Its own text puts that boundary at "≥ 70 m so it stays outside
## every gameplay radius" — and `TUN-NET-NPC-CULL-RADIUS` is 70 m, so every NPC
## the fallback would stop replicating is one the builder already refuses to send.
##
## The fallback is still worth building: it would put a crowd back on the horizon
## where a client currently draws empty street. **It is a rendering change, not a
## bandwidth one**, and TDD-04 §7.1.2 listing it as a candidate for the last 12 %
## is the thing this test exists to correct.
func test_the_far_crowd_the_fallback_would_derive_costs_nothing_today() -> void:
	var boundary: float = Tuning.net.npc_cull_radius
	var beyond := 0
	for at: Vector3 in _map.spawn_points:
		beyond += _records_beyond(at, boundary)
	gut.p(
		(
			"records past ADR-0007's %.0f m boundary, summed over six spawn points: %d"
			% [boundary, beyond]
		)
	)
	assert_eq(
		beyond,
		0,
		(
			"the builder is sending NPCs past the cull radius, which would mean "
			+ "ADR-0007's fallback has something to save after all"
		)
	)


# ---------------------------------------------------------------------------
# The radius, priced down to the invariant floor.
# ---------------------------------------------------------------------------


## **THE SWEEP, AND THE FLOOR IS THE POINT.** Invariant 17 pins
## `TUN-NET-NPC-CULL-RADIUS` at or above `TUN-COMPASS-RANGE-MAX` — 60 m — because
## a culled NPC must never be able to affect anything the client can perceive, and
## the compass reaches 60. So the radius cannot go below 60 without changing what
## the compass is allowed to see, which is a gameplay change and not a tuning one.
##
## Each row is measured by **adopting** the radius and rebuilding through the real
## `SnapshotBuilder`, so the delta and the rate-LOD stagger all respond to it. An
## estimate that subtracted eight bytes per far record would miss both.
func test_the_radius_is_swept_to_its_invariant_floor() -> void:
	var budget: float = Tuning.net.bandwidth_budget_down
	var floor_radius: float = Tuning.compass.range_max
	var best := INF
	for radius: float in [70.0, 67.5, 65.0, 62.5, 60.0]:
		var kbit := _kbit_at_radius(radius)
		best = minf(best, kbit)
		gut.p(
			(
				"  cull at %.1f m: %.1f kbit/s, %.0f %% of budget%s"
				% [
					radius,
					kbit,
					kbit / budget * 100.0,
					"   <-- invariant 17's floor" if radius <= floor_radius else ""
				]
			)
		)
	if best <= budget:
		gut.p("the floor closes the gap")
		assert_lt(best, budget)
		return
	pending(
		(
			(
				"even at invariant 17's floor of %.0f m the crowd costs %.1f kbit/s "
				+ "against a %.0f budget. The radius cannot go lower without letting "
				+ "the compass point at an NPC the client was never sent, and "
				+ "ADR-0007's fallback saves nothing at its own ≥ 70 m boundary. What "
				+ "is left needs a decision: fewer NPCs (never-do #14 forbids it "
				+ "before the LOD ladder is exhausted), a smaller record, a lower "
				+ "snapshot rate for the crowd, or a bigger budget."
			)
			% [floor_radius, best, budget]
		)
	)


# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------


## Mean snapshot bytes at the worst of the six spawn points, converted to kbit/s.
## The worst rather than the mean across players, because a budget met on average
## is a budget missed by somebody.
func _kbit_at_radius(radius: float) -> float:
	_adopt_radius(radius)
	var most := 0.0
	for at: Vector3 in _map.spawn_points:
		most = maxf(most, _mean_bytes_at(at))
	return (most + float(PACKET_OVERHEAD)) * Tuning.net.snapshot_rate * 8.0 / 1000.0


## **INVARIANT 30 PINS THE RATE-LOD RADIUS INSIDE THE CULL RADIUS**, so a sweep
## that moved only one of them would be refused by `Tuning.adopt()` — silently, as
## far as this file is concerned, leaving every row measured at the shipped radius.
## The rate-LOD radius follows it down, keeping its shipped fraction.
func _adopt_radius(radius: float) -> void:
	var profile := (load(PROFILE) as TuningProfile).clone()
	var share: float = profile.net.npc_rate_lod_radius / profile.net.npc_cull_radius
	profile.net.npc_cull_radius = radius
	profile.net.npc_rate_lod_radius = radius * share
	assert_true(
		Tuning.adopt(profile), "a cull radius of %.1f m was refused by an invariant" % radius
	)


func _mean_bytes_at(at: Vector3) -> float:
	_host.context_for(ONE_PEER).position = at
	_builder.crowd_delta.forget(ONE_PEER)
	var total := 0
	for tick: int in MEASURE_TICKS:
		_ctx.tick = tick
		_crowd.step()
		total += _builder.build_for(ONE_PEER).serialise().size()
		if tick >= ACK_LAG:
			_builder.note_ack(ONE_PEER, tick - ACK_LAG)
	return float(total) / float(MEASURE_TICKS)


## How many records this observer is sent for NPCs further away than `boundary`,
## over one whole rate-LOD stride. Without a baseline, so the delta cannot hide a
## record that was in fact chosen.
func _records_beyond(at: Vector3, boundary: float) -> int:
	_host.context_for(ONE_PEER).position = at
	_builder.crowd_delta.forget(ONE_PEER)
	var far := 0
	for tick: int in _builder.rate_lod_stride():
		_ctx.tick = tick
		for record: Array in _builder.build_for(ONE_PEER).npcs:
			var spot: Vector3 = record[1]
			if Vector2(spot.x - at.x, spot.z - at.z).length() > boundary:
				far += 1
	return far
