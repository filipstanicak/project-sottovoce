## **NPCs FURTHER AWAY ARE SENT LESS OFTEN.** US-0031, TDD-04 §7.2.
##
## §7.2 has specified this since M0 — "NPCs beyond 45 m at 10 Hz" — and it could
## not be built until US-0030 put a crowd on the wire for it to apply to. Both
## numbers were bare prose until this story; they are `TUN-NET-NPC-RATE-LOD-RADIUS`
## and `TUN-NET-NPC-RATE-LOD-HZ` now, with the document's own values.
##
## **IT IS NPC-ONLY BY DESIGN AND THAT IS NOT AN OVERSIGHT.** §7.2 justifies the
## reduced tier with *"those NPCs are outside all gameplay radii anyway"*, which is
## not true of a **player** at 46 m — one interpolated at 10 Hz would be visibly
## coarse. Applying this to remote pawns would be a design error, so the builder's
## remote path is untouched and a test below says so.
##
## **THE STAGGER IS THE PART THAT WOULD SILENTLY NOT HAPPEN.** Sending every far
## NPC on the same tick reduces the *mean* and leaves the *peak* exactly where it
## was — one snapshot in three carrying the whole crowd, which is the size that
## meets an MTU and the jitter a client actually feels. Nothing about the kbit/s
## figure would reveal it. `CrowdBands` staggers brain steps by `(tick + index) %
## stride` for the same reason and this uses the same shape.
extends GutTest

const MAP_DATA := "res://data/maps/map_vetraio.tres"
const SEED := 20260818
const CROWD := 30
const ONE_PEER := 7702

## Enough ticks that a stride of any plausible size repeats several times.
const TICKS := 30

var _ctx: MatchContext
var _pool: NpcPool
var _host: PawnHost
var _builder: SnapshotBuilder
var _map: MapData
var _here := Vector3(30.0, 0.0, 30.0)


func before_each() -> void:
	_map = load(MAP_DATA) as MapData
	_ctx = MatchContext.new()
	_ctx.map = _map
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, 6)
	_ctx.crowd = _pool
	_host = PawnHost.new()
	add_child_autofree(_host)
	_host.setup(_ctx)
	_builder = SnapshotBuilder.new()
	add_child_autofree(_builder)
	_builder.setup(_ctx, _host, null)
	await get_tree().physics_frame
	_ctx.slots.assign(ONE_PEER)
	_host.spawn(ONE_PEER)
	_host.context_for(ONE_PEER).position = _here
	_lay_the_crowd_out()


## **HALF INSIDE THE RATE-LOD RADIUS AND HALF BETWEEN IT AND THE CULL RADIUS**, so
## both branches have something to be true about. Even indices are near, odd are in
## the slowed band; nothing is placed beyond the cull radius, because what is culled
## is `test_snapshot_culling.gd`'s subject and would only muddy the counts here.
func _lay_the_crowd_out() -> void:
	var slowed: float = Tuning.net.npc_rate_lod_radius
	var cull: float = Tuning.net.npc_cull_radius
	var middle := (slowed + cull) * 0.5
	for index: int in CROWD:
		var distance := (slowed * 0.5) if index % 2 == 0 else middle
		_pool.set_position(index, _here + Vector3(distance, 0.0, 0.0))


## How many of `TICKS` snapshots carried each NPC index.
func _sends_per_index() -> Dictionary:
	var seen: Dictionary = {}
	for tick: int in TICKS:
		_ctx.tick = tick
		for record: Array in _builder.build_for(ONE_PEER).npcs:
			var index := int(record[0])
			seen[index] = int(seen.get(index, 0)) + 1
	return seen


func _is_near(index: int) -> bool:
	return index % 2 == 0


# ---------------------------------------------------------------------------
# The guard against vacuous success comes first.
# ---------------------------------------------------------------------------


## **A CROWD ENTIRELY INSIDE THE RADIUS SATISFIES "FAR ONES ARE SENT LESS OFTEN"
## PERFECTLY**, and so does a builder that culls everything. The scenario must hold
## NPCs in both bands, and the near ones must arrive on every single tick — if they
## do not, the numbers below are measuring a cull rather than a rate.
func test_the_scenario_has_both_bands_and_the_near_ones_never_skip() -> void:
	var near := 0
	var far := 0
	for index: int in CROWD:
		if _is_near(index):
			near += 1
		else:
			far += 1
	assert_gt(near, 0, "nothing is inside the rate-LOD radius")
	assert_gt(far, 0, "nothing is in the slowed band, so the rule is vacuous")

	var seen := _sends_per_index()
	for index: int in CROWD:
		if _is_near(index):
			assert_eq(
				int(seen.get(index, 0)),
				TICKS,
				"a near NPC was skipped — rate LOD is reaching inside its own radius"
			)


# ---------------------------------------------------------------------------
# The rule.
# ---------------------------------------------------------------------------


## One tick in `stride`, where the stride is derived from the two rates rather
## than written down. Exact rather than approximate: `(tick + index) % stride` over
## a whole number of strides sends each far NPC exactly `TICKS / stride` times, and
## an assertion with slack would pass on a stride of one.
func test_a_far_npc_is_sent_one_tick_in_the_stride() -> void:
	var stride := _builder.rate_lod_stride()
	assert_gt(stride, 1, "the stride is 1, so nothing is being slowed down at all")
	assert_eq(TICKS % stride, 0, "the sample is not a whole number of strides")
	var seen := _sends_per_index()
	for index: int in CROWD:
		if not _is_near(index):
			assert_eq(
				int(seen.get(index, 0)),
				TICKS / stride,
				(
					"NPC %d in the slowed band was sent %d times in %d ticks, not %d"
					% [index, int(seen.get(index, 0)), TICKS, TICKS / stride]
				)
			)


## **THE STRIDE IS DERIVED FROM THE TWO RATES, NEVER DECLARED.** The criterion is
## that the send rate *is* `TUN-NET-NPC-RATE-LOD-HZ` — a literal 3 satisfies the
## words while ceasing to satisfy the meaning the first time either rate is
## retuned, and nothing would say so. Same reason `SpatialHash` reads its cell size
## from `TUN-SUSPICION-OPEN-RADIUS` instead of declaring 6.0.
func test_the_stride_comes_from_the_tunables() -> void:
	var expected: float = Tuning.net.snapshot_rate / Tuning.net.npc_rate_lod_hz
	assert_eq(
		_builder.rate_lod_stride(),
		int(round(expected)),
		"the stride does not follow TUN-NET-SNAPSHOT-RATE / TUN-NET-NPC-RATE-LOD-HZ"
	)


## **THE SAVING MUST BE IN EVERY SNAPSHOT, NOT IN THE AVERAGE OF THEM.** Sending
## the whole slowed band together would divide the mean by the stride and leave the
## largest snapshot exactly the size it was — the size that has to fit an MTU, and
## the one a client feels as jitter. The kbit/s figure would look identical either
## way, which is what makes this worth an assertion of its own.
func test_the_slowed_band_is_staggered_and_not_sent_all_at_once() -> void:
	var stride := _builder.rate_lod_stride()
	var far_total := 0
	for index: int in CROWD:
		if not _is_near(index):
			far_total += 1
	var worst := 0
	for tick: int in TICKS:
		_ctx.tick = tick
		var far_this_tick := 0
		for record: Array in _builder.build_for(ONE_PEER).npcs:
			if not _is_near(int(record[0])):
				far_this_tick += 1
		worst = maxi(worst, far_this_tick)
	gut.p(
		(
			"worst tick carries %d of %d slowed NPCs (a stagger of %d should give about %d)"
			% [worst, far_total, stride, far_total / stride]
		)
	)
	assert_lt(
		worst,
		far_total,
		"one tick carried the entire slowed band — the rate is reduced but the peak is not"
	)


## **REMOTE PAWNS ARE NOT SLOWED DOWN, AND THAT IS A DESIGN DECISION.** §7.2's
## justification is that a far NPC is outside every gameplay radius; a player at
## 46 m is not, and one drawn from 10 Hz samples would be visibly coarse. The
## builder's remote path must be untouched by any of this.
func test_a_distant_player_is_still_sent_every_tick() -> void:
	var other := ONE_PEER + 1
	_ctx.slots.assign(other)
	_host.spawn(other)
	var beyond: float = Tuning.net.npc_rate_lod_radius + 10.0
	_host.context_for(other).position = _here + Vector3(beyond, 0.0, 0.0)
	var sent := 0
	for tick: int in TICKS:
		_ctx.tick = tick
		# Nudge the distant player so the US-0031 delta cannot drop them for being
		# unchanged — this test is about the rate, and standing still is the other
		# mechanism's business.
		_host.context_for(other).position += Vector3(0.5, 0.0, 0.0)
		if not _builder.build_for(ONE_PEER).remote_pawns.is_empty():
			sent += 1
	assert_eq(sent, TICKS, "a distant PLAYER was rate-limited; §7.2's tier is NPC-only")
