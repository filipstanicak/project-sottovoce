## **WHAT THE CHASE COSTS IN RAYCASTS.** US-0097's last open criterion, TDD-07 §4.3.
##
## The story asks for *"no raycast the Compass lock has not already spent"* and
## **contradicts itself in the same breath**, because it also specifies a 90°
## pursuit cone against the lock's 25°: a cast gated on the lock leaves the chase
## blind through two thirds of its own cone. So the cast moved to the wider test
## and the lock reads the same answer.
##
## What is true, and is asserted here rather than claimed: **one query site, at
## most one cast per hunter per tick** — and the per-tick count **rises**. This
## file is the measurement that was owed.
##
## **A CONTEXT WITH NO TREE CASTS NOTHING AND COUNTS NOTHING**, because
## `_clear_of_geometry` answers *nothing blocks* before it increments. So the
## premise below is not decoration: without it every assertion in this file would
## be satisfied by a system that never casts at all.
extends GutTest

## Six, which is `TUN-MATCH-MAX-PLAYERS`, arranged so every hunter's contract is
## the next player round the ring. A chord of a 12 m circle at 60° is 12 m —
## inside `TUN-COMPASS-LOCK-RANGE` 20 and `TUN-PURSUIT-SIGHT-RANGE` 25 alike.
const LOBBY := 6
const RING_RADIUS := 12.0

## Off the lock's 12.5° half-cone and well inside the pursuit's 45°. This is the
## band the story's own two tunables create and the band the cast had to move for.
const OFF_AXIS_DEGREES := 35.0

var _system: DetectionSystem
var _ctx: MatchContext


func before_each() -> void:
	_system = DetectionSystem.new()
	add_child_autofree(_system)
	_ctx = MatchContext.new()
	_ctx.tick = 100
	_system.setup(_ctx)
	for i: int in LOBBY:
		var pawn := PawnContext.new()
		pawn.peer_id = _peer(i)
		pawn.reset_for_spawn(_at(i), 0.0)
		pawn.state_id = PawnStateId.IDLE
		pawn.tier = SuspicionMath.Tier.NOTICED
		pawn.suspicion = Tuning.suspicion.tier_noticed
		_ctx.pawn_contexts[_peer(i)] = pawn
		_ctx.announced_contracts[_peer(i)] = _peer((i + 1) % LOBBY)


func _peer(i: int) -> int:
	return 41 + i


func _at(i: int) -> Vector3:
	var a := TAU * float(i) / float(LOBBY)
	return Vector3(cos(a) * RING_RADIUS, 0.0, sin(a) * RING_RADIUS)


## Aim every hunter at their own contract, `off` degrees to one side.
func _aim(off_degrees: float) -> void:
	for i: int in LOBBY:
		var here := _ctx.pawn_contexts[_peer(i)] as PawnContext
		var there := _ctx.pawn_contexts[_peer((i + 1) % LOBBY)] as PawnContext
		here.yaw = CompassMath.bearing_to(here.position, there.position) + deg_to_rad(off_degrees)


func _casts() -> int:
	_system.tick(_ctx, MatchContext.net_dt())
	return _system.raycasts_last_tick


func test_the_system_can_cast_at_all() -> void:
	# **THE PREMISE.** `_clear_of_geometry` returns before incrementing when there
	# is no `World3D`, so a fixture out of the tree measures zero for every
	# arrangement below and every assertion in this file passes over nothing.
	_aim(0.0)
	assert_gt(_casts(), 0, "the fixture has no world, so no cast was ever counted")


## **THE CEILING THE STORY CAN HONESTLY CLAIM.** One query site, and a hunter is
## asked about their own contract exactly once per pass — so the count can never
## exceed the lobby however the ring is arranged.
func test_at_most_one_cast_per_hunter_per_tick() -> void:
	_aim(0.0)
	assert_lte(_casts(), LOBBY, "a hunter was asked about their contract more than once")


func test_a_hunter_facing_away_spends_nothing() -> void:
	_aim(180.0)
	assert_eq(_casts(), 0, "a hunter with their back turned paid for a raycast")


## **THE MEASUREMENT, AND IT IS THE RISE THE STORY OWED.** At 35° off axis the
## Compass lock's 25° cone refuses every pair and would have cast nothing; the 90°
## pursuit cone admits all six. This is the band the two tunables create, and the
## reason "no raycast the lock has not already spent" is not achievable as written.
func test_the_pursuit_cone_casts_where_the_lock_cone_would_not() -> void:
	var half_lock := Tuning.compass.lock_cone * 0.5
	assert_gt(OFF_AXIS_DEGREES, half_lock, "the fixture stopped being outside the lock cone")
	assert_lt(
		OFF_AXIS_DEGREES,
		Tuning.contract.pursuit_sight_cone * 0.5,
		"the fixture stopped being inside the pursuit cone"
	)
	_aim(OFF_AXIS_DEGREES)
	var casts := _casts()
	gut.p(
		(
			(
				"PURSUIT RAYCAST BUDGET: %d casts for %d hunters at %.0f deg off axis, "
				+ "where the lock cone alone would have spent 0. TDD-07 §4.3 budgets 2-6."
			)
			% [casts, LOBBY, OFF_AXIS_DEGREES]
		)
	)
	assert_eq(casts, LOBBY, "the chase is blind through its own cone")


## The worst case a six-player lobby can produce, against §4.3's published band.
## **Reported as well as asserted**, because the number is what the criterion asked
## for and a green tick is not a measurement.
func test_the_worst_case_is_inside_the_published_band() -> void:
	_aim(0.0)
	var casts := _casts()
	gut.p("PURSUIT RAYCAST BUDGET: worst case %d casts per tick against §4.3's 2-6." % casts)
	assert_lte(casts, 6, "the worst case is outside TDD-07 §4.3's published band")
