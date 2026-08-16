## **A STARTLE WAVE, AND THE TWO HOPS IT IS CAPPED AT.** US-0044, GDD-03 §6.4,
## TDD-08 §3.1–3.2.
##
## **THE MEASUREMENTS THAT COULD PASS VACUOUSLY ARE ASSERTED AGAINST FIRST.** A
## wave that never propagated satisfies "capped at two hops" perfectly, and a
## `startle_at` that startled nobody satisfies "nobody beyond the reach was
## startled" better still. So every claim about the *shape* of a wave is paired
## with a count of how many NPCs it actually caught.
extends GutTest

const SEED := 20260816

var _pool: NpcPool
var _hash: SpatialHash
var _alarm: CrowdAlarm
var _rng: RandomNumberGenerator


## A line of NPCs one metre apart along +X from the origin. A line rather than a
## cloud, because "how far did the wave reach" is then a single number a reader
## can check by counting.
func _line(count: int) -> void:
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(count)
	_pool.activate(count, SEED, CrowdRoster.PLAYABLE, 6)
	_rng = RandomNumberGenerator.new()
	_rng.seed = SEED
	var points := PackedVector3Array()
	for index: int in count:
		var at := Vector3(float(index), 0.0, 0.0)
		_pool.set_position(index, at)
		points.append(at)
		_pool.context_of(index).rng = _rng
	_hash = SpatialHash.new()
	_hash.setup(AABB(Vector3(-10.0, -2.0, -10.0), Vector3(200.0, 10.0, 20.0)), count)
	_hash.rebuild(points, _pool.roster, count)
	_alarm = CrowdAlarm.new()


## Let the flags become states, the way `CrowdDirector._advance` does.
func _settle(count: int) -> void:
	for index: int in count:
		_pool.brain_of(index).step(_pool.context_of(index), MatchContext.net_dt())
		_pool.context_of(index).clear_events()


func _startled(count: int) -> PackedInt32Array:
	var who := PackedInt32Array()
	for index: int in count:
		if _pool.brain_of(index).state == NpcBrain.State.STARTLE:
			who.append(index)
	return who


func test_violence_startles_everybody_inside_the_radius() -> void:
	_line(40)
	_alarm.startle_at(Vector3.ZERO, 12.0, _hash, _pool)
	_settle(40)
	# 0..12 inclusive is thirteen NPCs, and every one of them must be caught: a
	# startle that *sometimes* fires is an information channel players stop
	# reading, which is why `NpcBrain` refuses to let anything override it.
	for index: int in 13:
		assert_eq(
			_pool.brain_of(index).state,
			NpcBrain.State.STARTLE,
			"NPC %d is inside 12 m and was not startled" % index
		)
	assert_eq(_alarm.last_wave[0], 13, "the direct round caught the wrong number")


func test_propagation_actually_fires() -> void:
	# **THE ANTI-VACUOUS ASSERTION FOR EVERY HOP CLAIM BELOW.** At
	# `TUN-CROWD-STARTLE-PROPAGATION` 0.4 over a dense line, a second round that
	# caught nobody would make "capped at two hops" trivially true.
	_line(40)
	_alarm.startle_at(Vector3.ZERO, 3.0, _hash, _pool)
	_settle(40)
	gut.p("wave: %d direct, %d propagated" % [_alarm.last_wave[0], _alarm.last_wave[1]])
	assert_gt(_alarm.last_wave[1], 0, "propagation never fired — every hop claim is vacuous")


func test_the_wave_stops_at_two_hops() -> void:
	# Round one reaches 3 m; round two reaches `TUN-CROWD-STARTLE-RADIUS-SPRINT`
	# further. Nothing beyond that, ever — a startle in a dense market that
	# cascaded across the district would say "something happened *somewhere*",
	# which is worse than saying nothing at all.
	_line(40)
	_alarm.startle_at(Vector3.ZERO, 3.0, _hash, _pool)
	_settle(40)
	var reach := 3.0 + Tuning.crowd.startle_radius_sprint
	var furthest := 0
	for index: int in _startled(40):
		furthest = maxi(furthest, index)
	gut.p("furthest startled NPC: %d m from the origin (reach %.0f m)" % [furthest, reach])
	assert_lt(float(furthest), reach + 0.001, "the wave crossed more than two hops")
	assert_gt(furthest, 3, "the wave did not get past the direct radius")


func test_a_propagated_npc_does_not_propagate_again() -> void:
	# The per-agent flag, asked directly. Round one's NPCs set it; round two's are
	# never given the chance, which is what the two-round structure means.
	_line(40)
	_alarm.startle_at(Vector3.ZERO, 3.0, _hash, _pool)
	var propagators := 0
	for index: int in 40:
		if _pool.brain_of(index).has_propagated:
			propagators += 1
	assert_true(
		propagators <= 4, "more NPCs propagated (%d) than the direct round held (4)" % propagators
	)
	assert_gt(propagators, 0, "nobody propagated — the cap is vacuous")


func test_the_flag_clears_when_the_fleeing_stops() -> void:
	# **OR AN NPC PROPAGATES ONCE PER MATCH.** Set on the way in and never cleared,
	# every wave after an NPC's first would die at its first hop — and the crowd
	# would grow quieter as the match went on, which nothing would report.
	_line(10)
	_alarm.startle_at(Vector3.ZERO, 3.0, _hash, _pool)
	_settle(10)
	var brain := _pool.brain_of(0)
	assert_true(brain.has_propagated, "the direct round did not propagate")
	brain.handle(NpcBrain.Event.TIMER_EXPIRED, _pool.context_of(0))
	assert_eq(brain.state, NpcBrain.State.STROLL)
	assert_false(brain.has_propagated, "the flag survived the startle it belonged to")


func test_re_startling_does_not_buy_a_second_propagation() -> void:
	# Re-entering `STARTLE` restarts the timer on purpose, and must not restart the
	# wave: two overlapping waves would otherwise chain without any cap.
	_line(10)
	_alarm.startle_at(Vector3.ZERO, 3.0, _hash, _pool)
	_settle(10)
	var first := _alarm.last_wave[1]
	_alarm.startle_at(Vector3.ZERO, 3.0, _hash, _pool)
	_settle(10)
	assert_eq(_alarm.last_wave[0], 0, "already-fleeing NPCs were counted as a fresh hop")
	assert_eq(_alarm.last_wave[1], 0, "a second wave over the same NPCs propagated again")
	assert_gt(first, 0, "the first wave propagated nothing — the comparison is vacuous")


func test_the_wave_is_deterministic_from_the_seed() -> void:
	# It draws from `ctx.rng`, never `randf`. A wave that differed between a match
	# and its replay would make every recorded playtest unreadable.
	_line(40)
	_alarm.startle_at(Vector3.ZERO, 3.0, _hash, _pool)
	_settle(40)
	var first := _startled(40)
	_line(40)
	_alarm.startle_at(Vector3.ZERO, 3.0, _hash, _pool)
	_settle(40)
	assert_eq(Array(first), Array(_startled(40)), "two waves from one seed differ")
	assert_gt(first.size(), 4, "the wave was too small to be a comparison")


func test_a_sprinting_pawn_startles_and_a_walking_one_does_not() -> void:
	# GDD-03 §6.4's second source. **Read from speed**, because the speed ladder is
	# monotonic (invariant 2) so nothing but a sprint exceeds `TUN-SPEED-RUN` — and
	# because a `GameSystem` cannot reach `PawnContext.state_id`.
	_line(20)
	var ctx := MatchContext.new()
	var pawn := CharacterBody3D.new()
	add_child_autofree(pawn)
	pawn.global_position = Vector3(2.0, 0.0, 0.0)
	ctx.pawns[7] = pawn

	pawn.velocity = Vector3(Tuning.movement.stroll, 0.0, 0.0)
	assert_eq(
		_alarm.sweep_for_sprinters(ctx, _hash, _pool), 0, "a strolling pawn startled the crowd"
	)

	pawn.velocity = Vector3(Tuning.movement.sprint, 0.0, 0.0)
	assert_gt(_alarm.sweep_for_sprinters(ctx, _hash, _pool), 0, "a sprinting pawn startled nobody")
	_settle(20)
	assert_eq(
		_pool.brain_of(2).state,
		NpcBrain.State.STARTLE,
		"the NPC the pawn ran past was not startled"
	)
	assert_eq(_pool.brain_of(19).state, NpcBrain.State.STROLL, "the ripple reached 19 m")
