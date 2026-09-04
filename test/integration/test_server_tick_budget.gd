## **HOW LONG A SERVER TICK ACTUALLY TAKES.** US-0048, PERFORMANCE_BUDGET §2,
## `TUN-PERF-SERVER-TICK-BUDGET`.
##
## The M3 gate names "server tick p99 at or under 8.0 ms" and **nothing had ever
## measured it**. `test_crowd_perf.gd` times `CrowdDirector.tick()`, which is one
## row of §2's eight; summing the rows that have been measured would be a
## projection, and this corpus has now been wrong twice about a budget nobody
## measured.
##
## **IT BOOTS THE REAL `server_root.tscn`**, which no test had ever done — trap 4
## names the server scene specifically. Every stage runs the way it runs in a
## match: the crowd on its own director, pawns substepped through `PawnHost`, the
## snapshot built per client, the lag-comp ring recorded.
##
## **THE TWO SIGNALS BRACKET EXACTLY THE THING UNDER BUDGET.** `MatchDirector`
## emits `net_ticked` before the stage loop and `tick_completed` after it, an
## arrangement US-0035 had to fix once already. Timing between them measures the
## stages and nothing else — not the physics frame around them, which is
## `test_crowd_perf.gd`'s wall-clock line.
##
## **IT ASSERTED THE MAXIMUM UNTIL 2026-09-03, AND THAT FAILED A BUILD WITH
## NOTHING BEHIND IT.** The old argument was that a max is *strictly stronger* than
## a p99 — true of the arithmetic and false of a shared runner, where the largest
## of 180 samples is decided by whichever tick the CI scheduler interrupted rather
## than by this project's code.
##
## Measured on the same commit, minutes apart: **CI 10.84 ms** against a local max
## of **3.179**, budget 8.0. The re-run went green untouched.
##
## **AND THE TWO ESTIMATORS WERE THEN COMPARED ON ONE MACHINE**, which is the
## evidence rather than the argument. Two runs, same commit, nothing else changed:
##
## | | p99 | max | max / p99 |
## |---|---|---|---|
## | run 1 | 3.042 | 3.179 | 1.05x |
## | run 2 | 2.909 | **5.554** | **1.91x** |
## | run 3 | 2.783 | 2.794 | 1.00x |
##
## **The p99 spans 9 % across the three and the max spans 99 %** — on a quiet
## desktop, before CI is involved at all. An estimator that doubles between
## identical runs cannot tell a regression from a scheduler, and a gate built on one
## fails builds that mean nothing.
##
## **This corpus had already learned it once** — `test_crowd_perf.gd` read 1.067,
## 1.249 and then 1.815 on CI for the same estimator, and now asserts an
## ordinary-tick p95 and prints the population beside it.
##
## **p99 IS ALSO WHAT THE GATE ACTUALLY ASKS FOR.** ROADMAP's M3 line is *"server
## tick p99 at or under 8.0 ms"*, so asserting the max was an over-reach past the
## documented criterion, not a stricter reading of it.
##
## **AND IT IS PRECISE ABOUT WHAT IT FORGIVES.** `_stats` takes
## `sorted[int(size * 0.99)]`, so over `TICKS` 180 samples the index is 178 and the
## p99 is the **second-highest** reading: it tolerates exactly one scheduler spike
## and no more. Two ticks over budget in 180 still fails, which is the line worth
## holding — one outlier says something about the runner, two say something about
## the code. **The max is printed on every run**, so a real regression that shows
## up only as spikes is visible to a reader even though it does not fail a build.
extends GutTest

const SERVER_ROOT := "res://scenes/server_root.tscn"

## Net ticks measured, after warmup. Two physics frames each, so this is the
## dominant term in the file's runtime and the integration suite has about 20 s
## of headroom. Enough that one unlucky frame does not decide the answer.
const TICKS := 180

## Ticks discarded first. The first ones pay for the navigation server's initial
## path per agent, the repath backlog and GDScript's first-call costs — the cost
## of *starting* a match, which happens once, not of running one.
const WARMUP := 30

const PLAYERS := 6

var _root: Node
var _started_usec: int = 0
var _samples: PackedFloat32Array = PackedFloat32Array()
var _collecting := false


func before_each() -> void:
	_root = (load(SERVER_ROOT) as PackedScene).instantiate()
	# **THE SERVER TURNS PHYSICS INTERPOLATION OFF, AND THIS TEST MUST TOO.**
	# `physics/common/physics_interpolation` is on for the client (US-0045), and
	# `boot.gd` disables it for a headless server because a server renders nothing.
	# This file loads `server_root.tscn` directly and never runs `boot.gd`, so
	# without this it measures a server doing 0.27 ms of work per tick that the real
	# one does not — on the very number this gate exists to report.
	#
	# **SET ON THE SUBTREE, NOT ON THE `SceneTree`.** Toggling the global flag from a
	# test mutates state that outlives the file, and the suite hung when it did:
	# every script passed alone and the full run never finished. Node-local scope
	# reaches exactly the nodes being measured and leaves everything else alone.
	_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child_autofree(_root)
	_samples = PackedFloat32Array()
	_collecting = false
	# `server_root` places the crowd through `call_deferred` after waiting on the
	# navigation map — two iterations, and querying before the first is an error.
	# The same wait it does, from out here.
	for _i: int in 150:
		await get_tree().physics_frame
		if _root.crowd.active_count() > 0:
			break
	_seat_a_full_lobby()
	_root.director.net_ticked.connect(_on_tick_began)
	_root.director.tick_completed.connect(_on_tick_ended)


## **THE AUTOLOAD IS PUT BACK.** `server_root._ready()` calls `Net.bind_router`,
## and `Net` outlives this test — a dangling router would be handed to whatever
## ran next, which is the shape of defect US-0037 exists to prevent.
func after_each() -> void:
	Net.bind_router(null, null)


## **SIX PLAYERS, THROUGH THE SHIPPED JOIN PATH.** `Net.peer_joined` is what a
## real handshake emits, so this exercises `server_root._on_peer_joined` rather
## than reaching past it. Without them the pawn stage does nothing, the snapshot
## stage builds nothing and the crowd bands everything Far — which is exactly the
## empty-district measurement US-0041 found in `test_crowd_perf.gd`.
func _seat_a_full_lobby() -> void:
	for seat: int in PLAYERS:
		Net.peer_joined.emit(9100 + seat)


func _on_tick_began(_ctx: MatchContext, _dt: float) -> void:
	_started_usec = Time.get_ticks_usec()


func _on_tick_ended(_ctx: MatchContext, _dt: float) -> void:
	if _collecting:
		_samples.append(float(Time.get_ticks_usec() - _started_usec) / 1000.0)


## Let the server run. Physics frames drive `MatchDirector._physics_process`, so
## nothing here calls a tick by hand — the point is to measure the shipped clock.
func _run(ticks: int) -> void:
	for _i: int in ticks * 2:
		await get_tree().physics_frame


func _stats(samples: PackedFloat32Array) -> Dictionary:
	var sorted := Array(samples)
	sorted.sort()
	var total := 0.0
	for value: float in sorted:
		total += float(value)
	return {
		"mean": total / float(sorted.size()),
		"p50": float(sorted[sorted.size() / 2]),
		"p95": float(sorted[int(float(sorted.size()) * 0.95)]),
		"p99": float(sorted[int(float(sorted.size()) * 0.99)]),
		"max": float(sorted[sorted.size() - 1]),
	}


# ---------------------------------------------------------------------------
# The guard against vacuous success comes first.
# ---------------------------------------------------------------------------


## **A SERVER WITH NOTHING IN IT MEETS EVERY BUDGET.** The crowd must be standing,
## the lobby must be full, the systems must be registered and the director must
## actually be emitting — a scene that booted but never ticked would produce zero
## samples, and `_stats` on an empty array is the only thing between that and a
## green suite reporting a very fast server.
func test_the_server_under_measurement_is_a_real_one() -> void:
	await _run(WARMUP)
	_collecting = true
	await _run(20)
	_collecting = false

	assert_eq(
		_root.crowd.active_count(),
		int(Tuning.crowd.count_default_6p),
		"the crowd is not stood up, so the crowd stage costs nothing"
	)
	assert_eq(_root.pawns.pawn_count(), PLAYERS, "the lobby is not full, so the pawn stage is idle")
	assert_not_null(
		_root.director.system_for(&"crowd"), "no system is registered at the crowd stage"
	)
	assert_gt(_samples.size(), 0, "the director never completed a tick — nothing was measured")


# ---------------------------------------------------------------------------
# The gate's line.
# ---------------------------------------------------------------------------


## `TUN-PERF-SERVER-TICK-BUDGET`, read rather than written down.
func test_the_server_tick_against_its_budget() -> void:
	await _run(WARMUP)
	_collecting = true
	await _run(TICKS)
	_collecting = false
	assert_gt(_samples.size(), TICKS / 2, "too few samples arrived to say anything")

	var budget: float = Tuning.perf.server_tick_budget
	var stats := _stats(_samples)
	gut.p(
		(
			(
				"server tick over %d samples: mean %.3f p50 %.3f p95 %.3f p99 %.3f max %.3f ms "
				+ "(budget %.1f)"
			)
			% [
				_samples.size(),
				stats["mean"],
				stats["p50"],
				stats["p95"],
				stats["p99"],
				stats["max"],
				budget
			]
		)
	)
	# **THE GAP BETWEEN THE WORST TICK AND THE SECOND-WORST IS THE DIAGNOSTIC.** A
	# max far above the p99 is one interrupted tick; a max close to it is the shape
	# of a real slowdown, and only one of those is worth waking somebody for.
	gut.p(
		(
			"worst tick %.3f ms, %.1fx the p99 — a large gap here is the runner, not the code"
			% [stats["max"], float(stats["max"]) / maxf(float(stats["p99"]), 0.001)]
		)
	)
	assert_lt(
		float(stats["p99"]),
		budget,
		(
			"the server tick is over TUN-PERF-SERVER-TICK-BUDGET at the p99, which is "
			+ "ROADMAP's own M3 criterion. Over 180 samples that is the second-worst "
			+ "tick, so this forgives one scheduler spike and not two — see the note at "
			+ "the top of this file, and the max printed above."
		)
	)


## **WHAT THIS NUMBER DOES NOT INCLUDE, MEASURED RATHER THAN WAVED AT.**
## `Net.send_snapshot` returns early when there is no ENet peer, so the snapshot
## stage above pays for `build_for` — cull, rate LOD, delta — and **not** for
## `serialise()`. That is a real part of §2's 1.20 ms snapshot row and it is
## missing from the figure.
##
## It is reported beside the tick and **deliberately not added to it**: summing a
## measured number and a separately-measured number is a projection, and this gate
## exists because two projections in this corpus turned out to be wrong. What the
## two together support is a much weaker and safer claim — that the omission is
## nowhere near large enough to put the tick over 8.0 ms.
func test_what_the_tick_measurement_leaves_out() -> void:
	await _run(WARMUP)
	var builder: SnapshotBuilder = _root.snapshots
	var peers: Array = _root.director.ctx.pawns.keys()
	assert_gt(peers.size(), 0, "no peer to build a snapshot for")

	var began := Time.get_ticks_usec()
	for peer: int in peers:
		builder.build_for(peer).serialise()
	var spent := float(Time.get_ticks_usec() - began) / 1000.0
	gut.p(
		(
			(
				"serialising %d clients' snapshots costs %.3f ms, and is NOT in the tick "
				+ "figure above: Net.send_snapshot early-returns without a real peer"
			)
			% [peers.size(), spent]
		)
	)
	assert_lt(spent, Tuning.perf.server_tick_budget, "serialisation alone exceeds the whole budget")
