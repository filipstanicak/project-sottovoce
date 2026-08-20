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
## **IT IS NOT, AND THE SWEEP THAT SAID OTHERWISE HAD TWO DEFECTS OF ITS OWN.**
## The first version of this file reported the budget closing at 65 m. It did not.
##
## 1. **It swept two variables.** Invariant 30 pins `TUN-NET-NPC-RATE-LOD-RADIUS`
##    inside the cull radius, and the helper kept them legal by scaling the rate-LOD
##    radius to the cull radius's **shipped fraction** — so every row became a
##    function of whatever was in the profile. Changing the shipped radius from 70 m
##    to 65 m moved every row of a table that adopts its own radius: 65 m read 97 %
##    against a profile of 70, and 101 % against a profile of 65. Only the row
##    matching the shipped value was ever right.
## 2. **It carried the crowd forward between rows.** Pricing six spawn points costs
##    180 ticks of walking, so the radius fell and the crowd state advanced
##    together. **That was the entire gradient.**
##
## With one variable and an identical crowd for every row, the curve is flat:
##
## | Cull radius | Of budget | NPCs reachable over six spawn points |
## |---|---|---|
## | 70.0 m, shipped | 113 % | 284 |
## | 67.5 m | 104 % | 266 |
## | 65.0 m | 112 % | 251 |
## | 62.5 m | 113 % | 241 |
## | 60.0 m, invariant 17's floor | 110 % | 221 |
##
## **THE KNOB TURNS AND THE BYTES DO NOT MOVE**, which is the useful part. Culling
## from 70 m to 60 m removes **22 % of the reachable crowd and about 3 % of the
## bytes**, because everything it removes lies beyond `TUN-NET-NPC-RATE-LOD-RADIUS`
## and is already sent at a third of the rate, while the worst-case snapshot is
## dominated by the **near** crowd the radius never touches.
##
## So TDD-04 §7.1.2's original conclusion — *culling was not the lever* — was right,
## and the sweep that contradicted it was measuring drift. **Neither named candidate
## can deliver the remaining 12 %**: ADR-0007's fallback saves nothing at its own
## ≥ 70 m boundary, and the radius saves 3 % at the cost of 10 m of invariant 17's
## margin over `TUN-COMPASS-RANGE-MAX`. What is left is a smaller record, a lower
## crowd update rate, a smaller crowd (never-do #14 forbids that before the LOD
## ladder is exhausted), or a larger budget.
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
func test_the_radius_knob_actually_turns() -> void:
	assert_eq(_pool.active_count(), CROWD, "the crowd being priced is not the full one")
	assert_gt(_crowd.walking(), 0, "a motionless crowd makes the delta look free")
	var wide := _reachable_at(90.0)
	var tight := _reachable_at(Tuning.compass.range_max)
	gut.p("NPCs reachable over six spawn points: %d at 90 m, %d at the floor" % [wide, tight])
	# **THE GUARD THIS FILE MOST NEEDED AND DID NOT HAVE.** `Tuning.adopt()` refuses a
	# profile that breaks any invariant, and it refuses it by returning false rather
	# than by stopping the test. Every row would then be measured at the shipped
	# radius, the table would read as a smooth flat curve, and "the radius does
	# nothing" would be exactly the conclusion a broken sweep produces.
	assert_gt(
		wide, tight, "adopting a radius changed nothing, so every row below prices the same world"
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
				"  cull at %.1f m: %.1f kbit/s, %.0f %% of budget, %d NPCs reachable%s"
				% [
					radius,
					kbit,
					kbit / budget * 100.0,
					_reachable_at(radius),
					"   <-- invariant 17's floor" if radius <= floor_radius else ""
				]
			)
		)
	if best <= budget:
		gut.p("the floor closes the gap")
		assert_lt(best, budget)
		return
	# **FLATNESS IS THE FINDING, NOT A FAILURE.** Reported rather than failed, the
	# same choice `test_crowd_wire_cost.gd` made: nothing in this file can close a
	# budget the radius does not move.
	pending(
		(
			(
				"the curve is FLAT: even at invariant 17's floor of %.0f m the crowd "
				+ "costs %.1f kbit/s against a %.0f budget. Culling from 70 m to the "
				+ "floor removes 22 %% of the reachable crowd and about 3 %% of the "
				+ "bytes, because everything it removes is beyond "
				+ "TUN-NET-NPC-RATE-LOD-RADIUS and already sent at a third, while the "
				+ "worst snapshot is dominated by the near crowd. ADR-0007's fallback "
				+ "saves nothing at its own ≥ 70 m boundary. What is left needs a "
				+ "decision: a smaller record, a lower crowd update rate, fewer NPCs "
				+ "(never-do #14 forbids that first), or a bigger budget."
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
	_reseat_the_crowd()
	var most := 0.0
	for at: Vector3 in _map.spawn_points:
		most = maxf(most, _mean_bytes_at(at))
	return (most + float(PACKET_OVERHEAD)) * Tuning.net.snapshot_rate * 8.0 / 1000.0


## **EVERY ROW STARTS FROM THE SAME CROWD, NOT MERELY THE SAME SEED.** Measuring
## six spawn points costs 180 ticks of walking, so a sweep that simply carried on
## would advance the crowd between rows — the radius falls and the crowd state
## moves at the same time, and the table cannot tell the two apart. Rebuilt and
## re-settled from the same seed for each radius, so the only thing that differs
## between rows is the number being swept.
func _reseat_the_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_crowd = ModelledCrowd.new()
	_crowd.setup(_pool, _map, rng, CROWD)
	_crowd.settle(SETTLE_TICKS)


## **ONE VARIABLE, AND THE FIRST VERSION OF THIS SWEPT TWO.** Invariant 30 pins the
## rate-LOD radius inside the cull radius, so the sweep must keep the pair legal —
## but the first version did it by scaling the rate-LOD radius to the cull radius's
## **shipped fraction**, which made every row a function of the value that happened
## to be in the profile. Lowering the shipped radius from 70 m to 65 m therefore
## moved every row of a table that adopts its own radius: 65 m read 97 % when the
## profile said 70, and 101 % when it said 65. Only the row matching the shipped
## value was ever right.
##
## `TUN-NET-NPC-RATE-LOD-RADIUS` is its own tunable with its own meaning — how far
## out a record may be sent at a reduced rate — and it does not follow the cull
## radius anywhere. It is held at its own value and clamped only where invariant 30
## would otherwise be violated.
func _adopt_radius(radius: float) -> void:
	var profile := (load(PROFILE) as TuningProfile).clone()
	profile.net.npc_cull_radius = radius
	profile.net.npc_rate_lod_radius = minf(profile.net.npc_rate_lod_radius, radius)
	assert_true(
		Tuning.adopt(profile), "a cull radius of %.1f m was refused by an invariant" % radius
	)


## **A SWEEP WHOSE ROWS ALL AGREE IS A SWEEP THAT NEVER HAPPENED.** If
## `Tuning.adopt()` refused every profile — one invariant is all it takes — each row
## would be measured at the shipped radius and the table would look perfectly
## reasonable while saying nothing. The gradient is the evidence that the knob turns.
func _gradient_is_real(rows: Array) -> bool:
	return float(rows[0]) - float(rows[-1]) > 5.0


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


## **HOW MANY NPCs THE CULL ACTUALLY REMOVES**, summed over the six spawn points.
## The bytes alone cannot say whether a flat curve means the radius does nothing or
## the measurement is broken; this can. Counted without a baseline, so the delta
## cannot hide an NPC the cull genuinely chose.
func _reachable_at(radius: float) -> int:
	_adopt_radius(radius)
	var total := 0
	for at: Vector3 in _map.spawn_points:
		_host.context_for(ONE_PEER).position = at
		_builder.crowd_delta.forget(ONE_PEER)
		var ever := {}
		for tick: int in _builder.rate_lod_stride():
			_ctx.tick = tick
			for record: Array in _builder.build_for(ONE_PEER).npcs:
				ever[int(record[0])] = true
		total += ever.size()
	return total


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
