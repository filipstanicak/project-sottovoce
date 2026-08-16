## **BANDS CHANGE THE RATE AND NOTHING ELSE.** US-0045, TDD-08 §4.1, ADR-0003.
##
## **THE ASSERTION THAT MATTERS IS NOT THE SAVING.** US-0048 measured the crowd
## before this was built: the brains are 0.046 ms of a 5.7 ms crowd, so banding
## them saves under 1 %. What LOD must not do is change what the crowd *does* —
## and it very nearly did, twice, in ways nothing would have reported:
##
## 1. A brain stepped every fifteenth tick decrements its timer every fifteenth
##    tick, so an 8–25 s idle pause becomes 120–375 s. `stride` fixes that.
## 2. Events cleared on a tick the brain did not think are events nobody read, so
##    **startles and gawk tokens would vanish for two thirds of the crowd**.
extends GutTest

const SEED := 20260816
const CROWD := 30

var _pool: NpcPool
var _director: CrowdDirector
var _ctx: MatchContext


func before_each() -> void:
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, 6)
	_director = CrowdDirector.new()
	add_child_autofree(_director)
	_ctx = MatchContext.new()
	_ctx.crowd = _pool
	_ctx.match_seed = SEED
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	# Two metres apart along +X: index 0 at 0 m, index 29 at 58 m, so one line
	# crosses all three bands from a watcher at the origin.
	for index: int in CROWD:
		_pool.set_position(index, Vector3(float(index) * 2.0, 0.0, 0.0))


func _watch_from(where: Vector3) -> void:
	var observer := CharacterBody3D.new()
	add_child_autofree(observer)
	observer.global_position = where
	_ctx.pawns[1] = observer


func _tick(times: int) -> void:
	for _t: int in times:
		_ctx.tick += 1
		_director.tick(_ctx, MatchContext.net_dt())


func test_the_bands_are_the_documented_radii() -> void:
	var players := PackedVector3Array([Vector3.ZERO])
	var near: float = Tuning.perf.crowd_lod_near
	var mid: float = Tuning.perf.crowd_lod_mid
	assert_eq(CrowdLod.band_of(Vector3(near - 0.5, 0.0, 0.0), players), CrowdLod.Band.NEAR)
	assert_eq(CrowdLod.band_of(Vector3(near + 0.5, 0.0, 0.0), players), CrowdLod.Band.MID)
	assert_eq(CrowdLod.band_of(Vector3(mid - 0.5, 0.0, 0.0), players), CrowdLod.Band.MID)
	assert_eq(CrowdLod.band_of(Vector3(mid + 0.5, 0.0, 0.0), players), CrowdLod.Band.FAR)


func test_the_nearest_player_decides_and_not_the_first() -> void:
	# Six players, and an NPC is Near if **any** of them is close. Taking the first
	# would band the crowd by whoever happened to join first.
	var players := PackedVector3Array([Vector3(100.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0)])
	assert_eq(CrowdLod.band_of(Vector3(6.0, 0.0, 0.0), players), CrowdLod.Band.NEAR)


func test_an_unwatched_crowd_is_far_rather_than_near() -> void:
	# An empty server has nobody to be fooled by a slow crowd. The other way round
	# would make the emptiest server the most expensive one.
	assert_eq(CrowdLod.band_of(Vector3.ZERO, PackedVector3Array()), CrowdLod.Band.FAR)


func test_the_strides_are_the_documented_rates() -> void:
	assert_eq(CrowdLod.stride_of(CrowdLod.Band.NEAR), 1, "Near is not every tick")
	assert_eq(CrowdLod.stride_of(CrowdLod.Band.MID), 3, "Mid is not every third tick")
	assert_eq(CrowdLod.stride_of(CrowdLod.Band.FAR), 15, "Far is not every fifteenth tick")


func test_a_band_is_spread_across_its_own_period() -> void:
	# **OR A THIRD OF THE CROWD THINKS ON THE SAME TICK.** `tick % stride` alone
	# gives a real average saving and a worse spike than the flat cost it replaced.
	var busiest := 0
	for tick: int in 15:
		var due := 0
		for index: int in 90:
			if CrowdLod.due(CrowdLod.Band.FAR, tick, index):
				due += 1
		busiest = maxi(busiest, due)
	assert_lt(busiest, 90 / 15 + 2, "a Far tick had far more than its share of the crowd")
	assert_gt(busiest, 0, "nobody was ever due — the stagger is vacuous")


func test_everybody_is_still_stepped_within_their_period() -> void:
	# The other half: a stagger that starved somebody would be an NPC that never
	# thinks again, and nothing anywhere would report it.
	for band: CrowdLod.Band in [CrowdLod.Band.NEAR, CrowdLod.Band.MID, CrowdLod.Band.FAR]:
		for index: int in 90:
			var seen := false
			for tick: int in CrowdLod.stride_of(band):
				seen = seen or CrowdLod.due(band, tick, index)
			assert_true(seen, "NPC %d in band %d is never due" % [index, band])


func test_a_far_brain_keeps_the_documented_duration() -> void:
	# **THE FAILURE THAT WOULD HAVE LOOKED LIKE NOTHING.** Stepped every fifteenth
	# tick and decremented by one, `TUN-CROWD-IDLE-DURATION-MIN` 8 s would become
	# two minutes, and the only symptom is a distant crowd that stands unusually
	# still — which reads as atmosphere.
	var cctx := CrowdContext.new()
	var slow := NpcBrain.new()
	slow.handle(NpcBrain.Event.REACHED_ANCHOR, cctx)
	assert_eq(slow.state, NpcBrain.State.IDLE)
	var ticks := slow.timer_ticks
	assert_gt(ticks, 15, "the idle pause is too short to see a stride error")

	var stepped := 0
	while slow.state == NpcBrain.State.IDLE and stepped < ticks * 2:
		slow.step(cctx, MatchContext.net_dt(), 15)
		stepped += 15
	assert_almost_eq(
		float(stepped), float(ticks), 15.0, "a Far brain's idle pause is not the documented one"
	)


func test_lod_actually_reduces_how_many_brains_think() -> void:
	# §4.1's claim, measured on a line that crosses all three bands.
	_watch_from(Vector3.ZERO)
	_director.setup(_ctx)
	var total := 0
	for _t: int in 15:
		_tick(1)
		total += _director.lod_load().x
	var effective := float(total) / 15.0
	gut.p("%.1f of %d brains stepped per tick, watched from one end" % [effective, CROWD])
	assert_lt(effective, float(CROWD), "LOD stepped every brain every tick — it is not banding")
	assert_gt(effective, 0.0, "no brain ever stepped")


func test_a_watched_crowd_is_stepped_every_tick() -> void:
	# The other direction, and the one that matters for fairness: an NPC beside a
	# player must think at full rate, or the crowd would behave differently exactly
	# where somebody can tell.
	_watch_from(Vector3(30.0, 0.0, 0.0))
	_director.setup(_ctx)
	_tick(3)
	for index: int in CROWD:
		var at := _pool.body_of(index).global_position
		if at.distance_to(Vector3(30.0, 0.0, 0.0)) <= Tuning.perf.crowd_lod_near:
			assert_eq(
				_director.band_of(index),
				CrowdLod.Band.NEAR,
				"NPC %d beside a player is not Near" % index
			)


func test_a_startle_is_not_dropped_by_a_band() -> void:
	# **THE SECOND FAILURE LOD NEARLY INTRODUCED.** Events cleared on a tick the
	# brain did not think are events nobody read, so a startle raised on the wrong
	# tick would vanish for two thirds of the crowd — silently, and worse the
	# further away you are. Startle is the one interrupt the design requires to be
	# **reliable**, because players read it as information.
	_watch_from(Vector3(-200.0, 0.0, 0.0))  # everybody is Far
	_director.setup(_ctx)
	_tick(1)
	for index: int in CROWD:
		assert_eq(_director.band_of(index), CrowdLod.Band.FAR, "the crowd is not all Far")

	_director.startle_at(Vector3.ZERO, 100.0)
	_tick(CrowdLod.stride_of(CrowdLod.Band.FAR) + 1)
	var startled := 0
	for index: int in CROWD:
		if _pool.brain_of(index).state == NpcBrain.State.STARTLE:
			startled += 1
	gut.p("%d of %d Far NPCs kept the startle raised until they thought" % [startled, CROWD])
	assert_eq(startled, CROWD, "a band dropped a startle")
