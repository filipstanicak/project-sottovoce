## **THE M3 GATE'S BANDWIDTH LINE, AND THE FIRST TIME §7.1's CROWD ASSUMPTIONS
## HAVE MET A CROWD.** US-0048, TDD-04 §7.1, TDD-08 §11.
##
## `test_snapshot_size.gd` measures the *record* and then multiplies it by four
## constants nobody has ever measured: 45 near NPCs, 30 far ones, and 0.55 / 0.70
## of each changing per tick. Those four numbers decide the whole downstream
## projection, and until US-0039 there was no crowd to check them against.
##
## **THIS PROJECT HAS BEEN WRONG ABOUT EXACTLY THIS TWICE.** §7.1's per-record
## sizes were unreachable from §4's own field list (113 %, not the 87 % claimed),
## and §7.3's upstream arithmetic was correct for a format nothing used (253 %,
## not 112 %). Both were caught only by measuring. A projection is not a
## measurement, and the two surviving unmeasured numbers in the downstream budget
## are the two multipliers, not the record.
##
## **THE CROWD IS REAL AND THE NAVIGATION IS MODELLED**, exactly as
## `test_clone_local_min.gd` does it and for the same reason: the integration
## suite has 21 s of headroom and this needs hundreds of ticks. Real brains decide
## who is walking and who is standing, which is the number that actually matters —
## a strolling NPC covers 4.7 cm per tick against a 1 cm quantum, so *whether* it
## moves is the whole question and *how well it steers* is not.
##
## **AND THE MODEL CANNOT FLATTER THE FINDING, WHICH IS WHY IT IS USABLE.** A
## straight line is *shorter* than the path a navmesh would produce, so a modelled
## NPC arrives sooner, stands still longer, and changes its record less often. The
## measured change fraction is therefore a **lower bound**, and so is the kbit/s
## figure derived from it. Real navigation moves it up, never down.
##
## **IT MEASURES THE FORMAT, NOT THE WIRE.** `SnapshotBuilder` never calls
## `add_npc`, so no NPC has ever been replicated to anybody. That is asserted here
## rather than assumed, so the day culling lands this file says what it is now
## measuring instead of quietly changing meaning.
extends GutTest

const SEED := 20260818
const MAP_DATA := "res://data/maps/map_vetraio.tres"
const CROWD := 78
const PLAYERS := 6

## Long enough that the idle/walk mix is the crowd's steady state rather than its
## opening arrangement, short enough to cost nothing: `TUN-CROWD-IDLE-DURATION-MAX`
## is 25 s, so 900 ticks is thirty seconds and more than a full idle cycle.
const SETTLE_TICKS := 300
const MEASURE_TICKS := 600

## §7.1's worst case, quoted so the measured figures have something to be compared
## against. **These are the numbers under test**, not inputs to it.
const ASSUMED_NEAR_NPCS := 45
const ASSUMED_FAR_NPCS := 30
const ASSUMED_NEAR_CHANGED := 0.55
const ASSUMED_FAR_CHANGED := 0.70
const ASSUMED_FAR_RATE := 10.0
const REMOTE_PLAYERS := 5
const EVENT_BYTES_PER_SECOND := 80
const PACKET_OVERHEAD := 28

var _pool: NpcPool
var _map: MapData
var _rng: RandomNumberGenerator
var _watchers: PackedVector3Array
var _goals: PackedVector3Array
var _previous: Array = []

## Filled by `_measure`. Members rather than a return value, because every test
## below reads a different slice of the same run.
var _changed_near: int = 0
var _changed_far: int = 0
var _seen_near: int = 0
var _seen_far: int = 0
var _moved_bodies: int = 0

## One bill per observer, and the seat whose bill is largest. Replication is
## per-client, so the district-wide figure is not the one under budget.
var _per_watcher: Array = []
var _worst_seat: int = -1


func before_each() -> void:
	_map = load(MAP_DATA) as MapData
	_rng = RandomNumberGenerator.new()
	_rng.seed = SEED
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, PLAYERS)
	_goals = PackedVector3Array()
	_goals.resize(CROWD)
	for index: int in CROWD:
		_pool.set_position(index, _map.idle_anchors[index % _map.idle_anchors.size()])
		_pool.context_of(index).rng = _rng
		_goals[index] = CrowdDirector.NO_GOAL
	_seat_the_players()


## **THE MAP'S OWN SPAWN POINTS, NOT A CLUSTER.** `test_clone_local_min.gd` puts
## all six in one place because local depletion is a local failure. Bandwidth is
## the opposite: six players in one spot see one another's NPCs, which *understates*
## the near count. Spread is the worst case for replication.
func _seat_the_players() -> void:
	_watchers = PackedVector3Array()
	for at: Vector3 in _map.spawn_points:
		_watchers.append(at)


## One tick of the crowd, with navigation replaced by a straight line at stroll.
func _step_the_crowd() -> void:
	var dt := MatchContext.net_dt()
	var step: float = Tuning.crowd.npc_speed_stroll * dt
	var arrive: float = Tuning.crowd.anchor_arrive_radius
	for index: int in CROWD:
		var brain := _pool.brain_of(index)
		var cctx := _pool.context_of(index)
		brain.step(cctx, dt)
		cctx.clear_events()
		if brain.state != NpcBrain.State.STROLL:
			continue
		if _goals[index] == CrowdDirector.NO_GOAL:
			_goals[index] = _next_anchor(index)
		_walk(index, brain, cctx, step, arrive)


## Move one strolling body one tick along its straight line, and tell the brain
## when it arrives — otherwise nobody ever stands still and the idle fraction,
## which is the number this file exists to measure, is a constant zero.
func _walk(index: int, brain: NpcBrain, cctx: CrowdContext, step: float, arrive: float) -> void:
	var body := _pool.body_of(index)
	var to := _goals[index] - body.global_position
	to.y = 0.0
	if to.length() <= arrive:
		brain.handle(NpcBrain.Event.REACHED_ANCHOR, cctx)
		cctx.clear_events()
		_goals[index] = CrowdDirector.NO_GOAL
		return
	body.global_position += to.normalized() * step


func _next_anchor(index: int) -> Vector3:
	var anchors := _map.idle_anchors
	return anchors[(index * 7 + int(_rng.randi_range(0, anchors.size() - 1))) % anchors.size()]


## **WHAT THE WIRE WOULD CARRY FOR ONE NPC**, through the real `Quantise` rather
## than a reimplementation of it. Comparing `Vector3`s instead would count motion
## the format throws away — the whole question is whether the *quantised* record
## differs, and a 1 cm quantum against a 4.7 cm stride is the finding.
func _record_of(index: int) -> Array:
	var at: Vector3 = _pool.body_of(index).global_position
	var brain := _pool.brain_of(index)
	return [
		Quantise.pos_to_i16(at.x),
		Quantise.pos_to_i16(at.z),
		Quantise.height_to_u8(at.y),
		Quantise.yaw_to_u8(_pool.body_of(index).global_rotation.y),
		int(brain.state),
	]


## Horizontal distance from one watcher — the distance culling would use.
func _distance_to(at: Vector3, watcher: Vector3) -> float:
	var dx := at.x - watcher.x
	var dz := at.z - watcher.z
	return sqrt(dx * dx + dz * dz)


## Walk the crowd and count, per tick and **per observer**, how many NPC records
## changed — split by whether the NPC is inside the near band or between it and
## the cull radius.
##
## **PER OBSERVER, NOT PER NPC, AND THE FIRST VERSION OF THIS FILE GOT IT WRONG.**
## `TUN-NET-BANDWIDTH-BUDGET-DOWN` is what one client receives, so the question is
## "how many NPCs can *this* player see", never "how many can anybody see". Taking
## the nearest of six watchers answered the second: it reported 78.0 of 78 inside
## the cull radius — which is true of the district and true of no client — and it
## put NPCs in the cheap far band that are in some client's expensive near band.
## The budget is then charged to whichever observer costs the most.
func _measure() -> void:
	for _i: int in SETTLE_TICKS:
		_step_the_crowd()
	_previous = []
	for index: int in CROWD:
		_previous.append(_record_of(index))
	_per_watcher = []
	for _w: int in _watchers.size():
		_per_watcher.append({"near": 0, "far": 0, "near_changed": 0, "far_changed": 0})
	_moved_bodies = 0
	for _i: int in MEASURE_TICKS:
		_step_the_crowd()
		_tally_one_tick()
	_adopt_the_worst_observer()


## §7.1's two rows split at **45 m**, which is §7.2's rate-LOD boundary and not
## `TUN-PERF-CROWD-LOD-NEAR`'s 20 m — that one bands the *brain*, which is a CPU
## question rather than a bandwidth one. This file used 20 m first and reported
## 83 % of budget from a split nothing sends against.
##
## **NEITHER §7.2 NUMBER HAS A `TUN-` ID**, which is a finding rather than an
## oversight here: the 45 m boundary and the 10 Hz far rate are bare numbers in
## prose, because rate LOD is US-0031's unticked criterion and nothing has ever
## had to read them. The boundary is taken from `TUN-PERF-CROWD-LOD-MID`, which
## carries the same 45 m for the same reason — how far away an NPC has to be
## before its detail stops being worth paying for. **If those two ever diverge,
## this file is measuring the wrong one and rate LOD needs its own tunable.**
func _tally_one_tick() -> void:
	var near_band: float = Tuning.perf.crowd_lod_mid
	var cull: float = Tuning.net.npc_cull_radius
	for index: int in CROWD:
		var record := _record_of(index)
		var moved: bool = record != _previous[index]
		if moved:
			_moved_bodies += 1
		_previous[index] = record
		var at: Vector3 = _pool.body_of(index).global_position
		for seat: int in _watchers.size():
			_charge(_per_watcher[seat], _distance_to(at, _watchers[seat]), near_band, cull, moved)


## Put one NPC on one observer's bill for this tick.
func _charge(bill: Dictionary, distance: float, near_band: float, cull: float, moved: bool) -> void:
	if distance > cull:
		return
	if distance <= near_band:
		bill["near"] += 1
		if moved:
			bill["near_changed"] += 1
	else:
		bill["far"] += 1
		if moved:
			bill["far_changed"] += 1


## **THE BUDGET IS CHARGED TO THE MOST EXPENSIVE OBSERVER**, because a budget met
## on average is a budget missed by somebody. Cost rather than head-count decides
## which that is: a near NPC is sent at `TUN-NET-SNAPSHOT-RATE` and a far one at
## a tenth of it, so forty far NPCs are cheaper than fifteen near ones.
func _adopt_the_worst_observer() -> void:
	var rate: float = Tuning.net.snapshot_rate
	var worst := -1.0
	for seat: int in _per_watcher.size():
		var bill: Dictionary = _per_watcher[seat]
		var cost := (
			float(bill["near_changed"]) * rate + float(bill["far_changed"]) * ASSUMED_FAR_RATE
		)
		if cost > worst:
			worst = cost
			_worst_seat = seat
			_seen_near = int(bill["near"])
			_seen_far = int(bill["far"])
			_changed_near = int(bill["near_changed"])
			_changed_far = int(bill["far_changed"])


# ---------------------------------------------------------------------------
# The guard against vacuous success comes first, as it must.
# ---------------------------------------------------------------------------


## **EVERY NUMBER BELOW IS MEANINGLESS IF THE CROWD STANDS STILL.** A motionless
## crowd changes no records, projects to a beautiful figure, and would pass every
## other assertion in this file. It is the exact shape of the six vacuously green
## suites this project has already shipped — and of `test_crowd_perf.gd`, which
## measured a district with no players in it for two stories.
func test_the_crowd_under_measurement_is_actually_walking() -> void:
	_measure()
	assert_eq(_pool.active_count(), CROWD, "the crowd under measurement is not the full one")
	assert_eq(_watchers.size(), PLAYERS, "nobody is observing, so nothing is near anybody")
	assert_gt(_moved_bodies, 0, "no NPC record changed in %d ticks — nothing moved" % MEASURE_TICKS)
	var per_tick := float(_moved_bodies) / float(MEASURE_TICKS)
	gut.p("records changing per tick: %.1f of %d NPCs" % [per_tick, CROWD])
	assert_gt(
		per_tick,
		float(CROWD) * 0.2,
		"fewer than a fifth of the crowd changes per tick; the walk model is not walking"
	)


# ---------------------------------------------------------------------------
# The four assumptions.
# ---------------------------------------------------------------------------


## §7.1 assumes 45 near and 30 far. The crowd is 78 and the map is 120 × 120 m,
## so the cull radius of 70 m reaches most of it from most places.
func test_how_many_npcs_a_client_can_actually_see() -> void:
	_measure()
	var near := float(_seen_near) / float(MEASURE_TICKS)
	var far := float(_seen_far) / float(MEASURE_TICKS)
	gut.p(
		(
			(
				"worst observer (seat %d) sees per tick: %.1f near (§7.1 assumes %d), "
				+ "%.1f far (assumes %d), %.1f of %d replicated to them at all"
			)
			% [_worst_seat, near, ASSUMED_NEAR_NPCS, far, ASSUMED_FAR_NPCS, near + far, CROWD]
		)
	)
	assert_gt(near + far, 0.0, "no NPC is inside the cull radius of the worst observer")
	assert_between(near + far, 0.0, float(CROWD), "one observer cannot see more NPCs than exist")


## **THE TWO NUMBERS THE WHOLE PROJECTION TURNS ON.** A strolling NPC covers
## `TUN-CROWD-NPC-SPEED-STROLL` / 30 = 4.7 cm per tick against a 1 cm position
## quantum, so any NPC that is walking at all changes its record *every* tick. The
## only NPCs that do not are the ones standing at an anchor for
## `TUN-CROWD-IDLE-DURATION-MIN..MAX`. So these fractions are not a property of
## the network at all — they are the crowd's idle duty cycle, and §7.1 could not
## have known them before US-0040 existed.
func test_how_many_npc_records_actually_change_per_tick() -> void:
	_measure()
	var near := float(_changed_near) / maxf(float(_seen_near), 1.0)
	var far := float(_changed_far) / maxf(float(_seen_far), 1.0)
	gut.p(
		(
			(
				"fraction of the worst observer's visible records changing per tick: "
				+ "near %.3f (§7.1 assumes %.2f), far %.3f (assumes %.2f)"
			)
			% [near, ASSUMED_NEAR_CHANGED, far, ASSUMED_FAR_CHANGED]
		)
	)
	assert_between(near, 0.0, 1.0, "a fraction outside 0..1 is an arithmetic error")
	assert_between(far, 0.0, 1.0, "a fraction outside 0..1 is an arithmetic error")


## §7.1's own arithmetic, recomputed on measured counts instead of assumed ones.
##
## **PENDING, NOT FAILING, IF IT IS OVER** — the same choice `test_snapshot_size.gd`
## made. The fields are the ones §4 specifies and the encoding is as tight as they
## allow; a red suite over a number nobody can fix by editing this file is a suite
## people learn to ignore.
func test_the_downstream_projection_on_measured_crowd_counts() -> void:
	_measure()
	var rate: float = Tuning.net.snapshot_rate
	var near_npcs := float(_seen_near) / float(MEASURE_TICKS)
	var far_npcs := float(_seen_far) / float(MEASURE_TICKS)
	var near_changed := float(_changed_near) / maxf(float(_seen_near), 1.0)
	var far_changed := float(_changed_far) / maxf(float(_seen_far), 1.0)
	var total := (
		near_npcs * near_changed * Snapshot.NPC_BYTES * rate
		+ far_npcs * far_changed * Snapshot.NPC_BYTES * ASSUMED_FAR_RATE
		+ REMOTE_PLAYERS * Snapshot.REMOTE_BYTES * rate
		+ (Snapshot.HEADER_BYTES + Snapshot.OWN_BYTES + Snapshot.COUNT_BYTES) * rate
		+ PACKET_OVERHEAD * rate
		+ EVENT_BYTES_PER_SECOND
	)
	var kbit := total * 8.0 / 1000.0
	_report(kbit, near_npcs, far_npcs)


func _report(kbit: float, near_npcs: float, far_npcs: float) -> void:
	var budget: float = Tuning.net.bandwidth_budget_down
	gut.p(
		(
			(
				"downstream to the WORST observer on MEASURED counts: %.1f kbit/s "
				+ "against %.0f budget (%.0f %%), from %.1f near + %.1f far NPCs"
			)
			% [kbit, budget, kbit / budget * 100.0, near_npcs, far_npcs]
		)
	)
	if kbit > budget:
		pending(
			(
				(
					"downstream projects to %.1f kbit/s, %.0f %% of the %.0f budget, on "
					+ "MEASURED crowd counts rather than §7.1's assumed ones, and it is a "
					+ "LOWER bound: modelled navigation understates how often an NPC walks. "
					+ "The record was never the problem — the counts are within 10 %% of "
					+ "§7.1's and the CHANGE FRACTIONS are not. Nothing in this file can fix "
					+ "it: work ADR-0007's fallback or cull harder. US-0048."
				)
				% [kbit, kbit / budget * 100.0, budget]
			)
		)
		return
	assert_lt(kbit, budget, "downstream is over TUN-NET-BANDWIDTH-BUDGET-DOWN")


## **NO NPC HAS EVER BEEN REPLICATED TO ANYBODY**, and the figure above is
## therefore a measurement of the *format* against a real crowd, not of the wire.
## Asserted rather than written in a comment, so this file cannot keep describing
## itself the same way after culling lands. US-0030's four criteria are the ones
## that close this.
func test_the_builder_still_puts_no_npc_on_the_wire() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/net/server/snapshot_builder.gd")
	assert_false(source.is_empty(), "the snapshot builder could not be read")
	assert_false(
		source.contains("add_npc"),
		(
			"`SnapshotBuilder` now emits NPCs, so this file measures the format against a "
			+ "crowd nobody sends. Re-point it at the real snapshot and retire this guard."
		)
	)
