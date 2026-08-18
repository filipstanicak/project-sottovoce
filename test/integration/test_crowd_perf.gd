## **THE PROJECT'S LARGEST UNVALIDATED ASSUMPTION, MEASURED.** US-0048, TDD-08
## §11.2, ADR-0001, `RISK-CROWD-PERF`.
##
## Godot 4.7.1's GDScript across ninety agents is the thing ADR-0001 accepted a
## risk on. Until this file existed, no number in the corpus about crowd cost had
## ever been measured — and this project has twice found a budget table that
## described its author's expectations rather than the program (TDD-04 §7.1, §7.3).
##
## **BUILT BEFORE US-0045's LOD, DELIBERATELY.** LOD exists to buy frame time, and
## optimising against a budget nobody has measured is how the bandwidth miss
## reached 253 % while a document said 112 %. The number this file prints today is
## the **no-LOD** cost: 78 brains stepping every tick against §4.1's ~34.
##
## **IT MEASURES THE SERVER AND SAYS SO.** §11.1's client budget is
## animation-dominated and there is no `NpcView`, mesh or animation in the project
## at all. That half is US-0046's, and it is not estimated here.
extends GutTest

const MAP_COLLISION := "res://scenes/map/map_vetraio_collision.tscn"
const MAP_DATA := "res://data/maps/map_vetraio.tres"

const SEED := 20260816

## §11.2's line: everything the crowd does per net tick, on the server.
const SERVER_BUDGET_MS := 1.75

## Ticks measured. Ninety samples at 30 Hz is three seconds — enough that one
## unlucky frame does not decide the answer, short enough that the integration
## suite stays inside its 180 s.
const TICKS := 90

var _world: Node3D
var _pool: NpcPool
var _director: CrowdDirector
var _ctx: MatchContext
var _map: RID
var _count: int = 0

## The last run's samples, split by whether the 2 s director pass fired on that
## tick. Members rather than a return value because `_sample_ticks` is already the
## thing every test awaits.
var _on_pass: PackedFloat32Array = PackedFloat32Array()
var _off_pass: PackedFloat32Array = PackedFloat32Array()


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_world.add_child((load(MAP_COLLISION) as PackedScene).instantiate())
	_map = get_tree().get_root().get_world_3d().navigation_map

	_pool = NpcPool.new()
	_world.add_child(_pool)
	_director = CrowdDirector.new()
	_world.add_child(_director)

	_ctx = MatchContext.new()
	_ctx.map = load(MAP_DATA) as MapData
	_ctx.match_seed = SEED
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	_ctx.crowd = _pool


## **THE FULL CROWD, NOT A CONVENIENT ONE**, and six players in it.
##
## **AND SIX PLAYERS IN IT, WHICH IT DID NOT HAVE UNTIL US-0041's LAST LINE.**
## `MatchContext.pawns` was empty, so every NPC banded Far and two subsystems did
## nothing in the measurement — `CloneBalance` counts against player positions and
## the sprinter sweep reads pawn velocity. TDD-08 §11.2.1 records what that cost.
## The observer count is printed on every run, because the reason it went
## unnoticed for two stories is that nothing said the scenario was empty.
func _stand_up() -> void:
	var started: int = NavigationServer3D.map_get_iteration_id(_map)
	for _i: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_map) >= started + 2:
			break

	_count = int(Tuning.crowd.count_default_6p)
	_pool.preallocate(int(Tuning.crowd.count_max))
	_pool.activate(_count, SEED, CrowdRoster.PLAYABLE, 6)
	_seat_the_players()
	var spots := CrowdPlacement.positions(_count, SEED, _ctx.map.idle_anchors, _map)
	for index: int in spots.size():
		_pool.set_position(index, spots[index])
	_director.setup(_ctx)
	_director.form_groups()

	# **WARM UP BEFORE MEASURING.** The first ticks pay for the repath queue's
	# backlog, the navigation server's first path per agent and GDScript's own
	# first-call costs. Measuring those would report the cost of *starting* a
	# match, which happens once, as the cost of *running* one, which happens
	# fourteen thousand times.
	for _i: int in 30:
		_ctx.tick += 1
		_director.tick(_ctx, MatchContext.net_dt())
		await get_tree().physics_frame
		await get_tree().physics_frame


## **A FULL LOBBY AT THE MAP'S OWN SPAWN POINTS.** `CharacterBody3D` rather than
## `Node3D`, because the sprinter sweep reads `velocity` off one and would skip a
## plain node — silently, which would leave a subsystem out of the measurement
## while the observer count said six.
##
## They stand still. A moving lobby would make the banding differ between runs and
## this file's whole value is that its numbers are comparable across them.
func _seat_the_players() -> void:
	for at: Vector3 in _ctx.map.spawn_points:
		var pawn := CharacterBody3D.new()
		_world.add_child(pawn)
		pawn.global_position = at
		_ctx.pawns[_ctx.pawns.size() + 1] = pawn


## Milliseconds spent inside `CrowdDirector.tick()`, one sample per net tick.
func _sample_ticks(count: int) -> PackedFloat32Array:
	_on_pass = PackedFloat32Array()
	_off_pass = PackedFloat32Array()
	var interval := maxi(Tuning.ticks(&"TUN-CROWD-DIRECTOR-INTERVAL"), 1)
	var samples := PackedFloat32Array()
	for _i: int in count:
		_ctx.tick += 1
		var started := Time.get_ticks_usec()
		_director.tick(_ctx, MatchContext.net_dt())
		var spent := float(Time.get_ticks_usec() - started) / 1000.0
		samples.append(spent)
		# **PARTITIONED WHILE IT IS BEING MEASURED**, not reconstructed afterwards.
		# The 2 s pass is the only thing that happens on some ticks and not others,
		# so it is the only thing a max-versus-p95 gap can be attributed to — and
		# the two subsets sum to the whole, which is what makes that attribution
		# checkable rather than a story about a number.
		if _ctx.tick % interval == 0:
			_on_pass.append(spent)
		else:
			_off_pass.append(spent)
		await get_tree().physics_frame
		await get_tree().physics_frame
	return samples


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
		"max": float(sorted[sorted.size() - 1]),
	}


func test_the_crowd_under_measurement_is_the_full_one() -> void:
	# **GUARDS EVERY NUMBER BELOW.** A perf test that measured twelve NPCs would
	# report a comfortable figure and mean nothing; this project has shipped a
	# vacuously green suite six times.
	await _stand_up()
	assert_eq(_pool.body_count(), int(Tuning.crowd.count_max), "the pool is not the full ninety")
	assert_eq(_pool.active_count(), _count, "the crowd is not TUN-CROWD-COUNT-DEFAULT-6P")
	var walking := 0
	for index: int in _count:
		if _pool.brain_of(index).state == NpcBrain.State.WALKING_GROUP:
			walking += 1
	assert_gt(walking, 0, "no formations formed — the measurement is missing a whole subsystem")
	# **AND SOMEBODY IS WATCHING.** With no pawns every NPC bands Far, which is the
	# cheapest arrangement there is; the numbers below described that for two
	# stories without saying so.
	assert_eq(
		_ctx.pawns.size(),
		int(Tuning.contract.spawn_point_count),
		"the crowd is not being watched by a full lobby — every number here is a best case"
	)
	var bands: Dictionary = {}
	for index: int in _count:
		var band := _director.band_of(index)
		bands[band] = int(bands.get(band, 0)) + 1
	gut.p("bands with %d players: %s" % [_ctx.pawns.size(), bands])
	assert_gt(bands.size(), 1, "the whole crowd is in one band — the players are not spread")


func test_the_server_crowd_tick_against_the_budget() -> void:
	# **THE CHAPTER'S GATE.** TDD-08 §11.2 budgets 1.75 ms of the 8.0 ms server
	# tick for the whole crowd: hash rebuild, LOD banding, brains, steering, path
	# queries and the director's 2 s pass.
	await _stand_up()
	var stats := _stats(await _sample_ticks(TICKS))
	var load := _director.lod_load()
	gut.p(
		(
			"LOD: %d of %d brains stepped on the last tick, with %d players watching"
			% [load.x, load.y, _ctx.pawns.size()]
		)
	)
	(
		gut
		. p(
			(
				"CrowdDirector.tick() x%d, %d NPCs: mean %.3f p50 %.3f p95 %.3f max %.3f ms (budget %.2f)"
				% [
					TICKS,
					_count,
					stats["mean"],
					stats["p50"],
					stats["p95"],
					stats["max"],
					SERVER_BUDGET_MS
				]
			)
		)
	)
	assert_gt(float(stats["mean"]), 0.0, "the clock measured nothing — the sampler is broken")
	assert_lt(
		float(stats["p95"]),
		SERVER_BUDGET_MS,
		(
			"the crowd is over TDD-08 §11.2's server budget. Work §11.3's ladder IN ORDER; "
			+ "reducing TUN-CROWD-COUNT-MAX is last and never below TUN-CROWD-COUNT-MIN."
		)
	)


## §11.2 budgets 0.05 ms for the 2 s pass and its measured column said "inside the
## same", which is not a measurement — and it is the one row that can hide a spike.
func test_the_two_second_pass_is_what_the_max_is() -> void:
	# A max over budget with p95 under it is one expensive tick, not a slow crowd,
	# and the 2 s pass is the only work that happens on some ticks and not others.
	await _stand_up()
	await _sample_ticks(TICKS)
	assert_gt(_on_pass.size(), 0, "no 2 s pass fell inside the sample — nothing to attribute")
	assert_gt(_off_pass.size(), 0, "every tick was a pass tick — the partition is broken")
	var busy := _stats(_on_pass)
	var quiet := _stats(_off_pass)
	gut.p(
		(
			"2 s pass ticks (%d): mean %.3f max %.3f ms | ordinary ticks (%d): mean %.3f max %.3f"
			% [
				_on_pass.size(),
				busy["mean"],
				busy["max"],
				_off_pass.size(),
				quiet["mean"],
				quiet["max"]
			]
		)
	)
	var attributable: float = float(busy["max"]) >= float(quiet["max"])
	var whole := float(busy["mean"]) - float(quiet["mean"])
	# **AND WHICH HALF OF THE PASS.** Emptying `personas_in_use` makes layer 4 a
	# no-op without touching the formations or the corpse sweep, so the difference
	# is `CloneBalance`'s own share. An A/B against a field that already exists,
	# rather than a timer threaded through three objects to answer one question.
	_director.personas_in_use = []
	await _sample_ticks(TICKS)
	var without := _stats(_on_pass)
	gut.p(
		(
			(
				"pass costs %.3f ms over an ordinary tick (§11.2 budgets 0.05); "
				+ "without layer 4 it is %.3f ms, so clone balancing is about %.3f of it"
			)
			% [
				whole,
				float(without["mean"]) - float(quiet["mean"]),
				float(busy["mean"]) - float(without["mean"])
			]
		)
	)
	# **REPORTED, NOT ASSERTED: TWO SAMPLES CANNOT SUPPORT A PERCENTILE.** What this
	# refuses to allow is the attribution going unrecorded.
	assert_true(
		attributable or float(quiet["max"]) < SERVER_BUDGET_MS,
		"an ordinary tick, with no 2 s pass in it, exceeded the server budget"
	)


func test_the_hash_rebuild_holds_its_own_line() -> void:
	# §11.2's first row, isolated. US-0042 measured 0.0561 ms on synthetic points;
	# this is the same structure over the real district with the real crowd, which
	# is a different distribution across cells.
	await _stand_up()
	var here := PackedVector3Array()
	here.resize(_count)
	for index: int in _count:
		here[index] = _pool.body_of(index).global_position
	var started := Time.get_ticks_usec()
	for _i: int in 500:
		_ctx.crowd_hash.rebuild(here, _pool.roster, _count)
	var each := float(Time.get_ticks_usec() - started) / 500.0 / 1000.0
	gut.p("spatial hash rebuild with %d real positions: %.4f ms (budget 0.15)" % [_count, each])
	assert_lt(each, 0.15, "the spatial hash rebuild is over TDD-08 §11.2's 0.15 ms line")


func test_the_brains_hold_theirs() -> void:
	# §11.2 budgets 0.50 ms for **~34 effective** brain steps, which assumes
	# US-0045's LOD. There is none, so this measures all of them and the comparison
	# is against the *unbanded* cost — printed rather than asserted against a
	# budget that describes a system this milestone does not have.
	await _stand_up()
	var started := Time.get_ticks_usec()
	var dt := MatchContext.net_dt()
	for _pass: int in 100:
		for index: int in _count:
			_pool.brain_of(index).step(_pool.context_of(index), dt)
	var each := float(Time.get_ticks_usec() - started) / 100.0 / 1000.0
	gut.p(
		(
			(
				"NpcBrain.step() x%d (no LOD): %.4f ms. §11.2 budgets 0.50 ms for ~34 effective, "
				+ "so LOD must bring this under it"
			)
			% [_count, each]
		)
	)
	assert_gt(each, 0.0, "the clock measured nothing")


func test_the_physics_frame_still_fits_inside_its_deadline() -> void:
	# **THE CROWD SPENDS MOST OF ITS TIME OUTSIDE `tick()`.** `Steering` moves
	# bodies from `NavigationAgent3D`'s avoidance callback, on the **physics**
	# frame — it has to, because `move_and_slide()` integrates by the physics delta
	# and driving it from the 30 Hz tick would halve every NPC's speed (US-0041).
	# So a measurement of the crowd stage alone misses RVO, the callback and
	# seventy-eight `move_and_slide()` calls.
	#
	# **AND `Performance.TIME_PHYSICS_PROCESS` COULD NOT BE MADE TO MEASURE IT.**
	# Three attempts, all incoherent: it reported 31 ms a frame in one arrangement
	# and 24 ms of "crowd cost" in another — **inside a frame the wall clock says
	# takes 16.73 ms**. A figure larger than the interval that contains it is not a
	# slow frame, it is a broken instrument, and the earlier version of this file
	# published 5.69 ms from it before the contradiction was noticed.
	#
	# So the monitor is printed and believed by nobody, and the assertion is on the
	# **wall clock**, which is coherent, reproducible to two decimal places across
	# runs, and answers the only question that matters: does the server keep up.
	await _stand_up()
	var full := await _physics_ms(40)
	for index: int in int(Tuning.crowd.count_max):
		var agent := _pool.agent_of(index)
		if agent != null:
			agent.avoidance_enabled = false
	var no_rvo := await _physics_ms(40)
	_pool.deactivate_all()
	var empty := await _physics_ms(40)

	var deadline := 1000.0 / Tuning.net.client_input_rate
	(
		gut
		. p(
			(
				"physics wall clock, %d NPCs: full %.2f | no avoidance %.2f | none %.2f (deadline %.2f) ms"
				% [_count, full[1], no_rvo[1], empty[1], deadline]
			)
		)
	)
	(
		gut
		. p(
			(
				"TIME_PHYSICS_PROCESS says %.2f / %.2f / %.2f ms — INCOHERENT, it exceeds the frame it is in"
				% [full[0], no_rvo[0], empty[0]]
			)
		)
	)
	assert_gt(full[1], 0.0, "the wall clock measured nothing")
	assert_lt(
		full[1],
		deadline * 1.2,
		"physics frames run long with the full crowd — the server is not keeping up"
	)


## Mean `TIME_PHYSICS_PROCESS` over `frames`, in milliseconds, **with the wall
## clock beside it**. The monitor alone is not evidence: the engine paces physics
## to real time, so a wall clock still reading 16.7 ms while the monitor claims
## 31 says the monitor is wrong, not that the server is drowning. The first
## version of this test asserted on the monitor alone and reported a 17x miss
## that the wall clock flatly contradicts.
func _physics_ms(frames: int) -> Array:
	var total := 0.0
	var wall := Time.get_ticks_usec()
	for _i: int in frames:
		await get_tree().physics_frame
		total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var elapsed := float(Time.get_ticks_usec() - wall) / float(frames) / 1000.0
	return [total / float(frames) * 1000.0, elapsed]


func test_the_client_half_is_not_measurable_yet() -> void:
	# **SAID RATHER THAN ESTIMATED.** §11.1 budgets 1.90 ms of the client's 2.0 ms,
	# of which 1.20 is `AnimationTree` updates. There is no `NpcView`, no mesh and
	# no animation in the project, so any client figure produced today would be a
	# measurement of the absence of the expensive part. US-0045 and US-0046.
	assert_false(
		ResourceLoader.exists("res://scenes/npc/npc_view.tscn"),
		"npc_view.tscn now exists — the client half of §11.1 can be measured, so measure it"
	)
