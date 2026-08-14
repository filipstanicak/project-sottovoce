## The 500 ms ring. US-0035, TDD-04 §8.3, ADR-0010.
##
## **RECORDING ONLY.** Kill and stun do not exist until M4, so nothing here
## asserts that a rewind resolves a contest correctly — `test_lagcomp_rewind.gd`
## is M4's. What this file proves is that the buffer holds what it claims to
## hold, for as long as it claims, and answers the question §8.3 says it will.
##
## Every assertion is written against arrays the test chose. That is the whole
## reason `LagCompHistory` is pure and `LagCompRecorder` is a separate object:
## a ring fed by walking a live world could only be asked questions by standing
## one up, and then a rewind assertion would fail for reasons that had nothing to
## do with rewinding.
extends GutTest

var _history: LagCompHistory


func before_each() -> void:
	_history = LagCompHistory.new()


## Record `count` ticks of one entity walking +Z at one metre per tick.
func _walk(count: int, first_tick: int = 1) -> void:
	for i: int in count:
		var ids := PackedInt32Array([7])
		var positions := PackedVector3Array([Vector3(0.0, 0.0, float(i))])
		var yaws := PackedFloat32Array([0.0])
		_history.record(first_tick + i, ids, positions, yaws)


func test_the_ring_is_fifteen_entries_at_thirty_hertz() -> void:
	# 500 ms at 30 Hz. **Derived from tuning, never written as 15** — invariant 16
	# ties the ring to the rewind ceiling, and a hardcoded length would let
	# somebody widen the ceiling and find at M4 that the history no longer reached.
	assert_eq(_history.capacity(), 15, "the ring is not 500 ms at the server tick rate")
	assert_eq(
		_history.capacity(),
		int(round(Tuning.net.lagcomp_history / 1000.0 * Tuning.net.server_tick)),
		"capacity stopped being derived from TUN-NET-LAGCOMP-HISTORY"
	)


func test_it_is_two_and_a_half_times_the_maximum_rewind() -> void:
	# §8.3's actual claim, and the reason the number is 500 and not 200: the
	# buffer must never be the binding constraint on how far back §8.1 may reach.
	var max_rewind_ticks: float = Tuning.net.lagcomp_max / 1000.0 * Tuning.net.server_tick
	assert_gt(
		float(_history.capacity()),
		max_rewind_ticks * 2.0,
		"the ring no longer covers twice the maximum rewind"
	)


func test_an_empty_history_answers_with_an_empty_world() -> void:
	# **NOT NULL.** A caller forced to branch on null will eventually forget to,
	# and at M4 the thing it forgets to branch on validates a kill.
	var world := _history.rewind(5, Vector3.ZERO, 10.0)
	assert_not_null(world, "rewinding an empty history returned null")
	assert_true(world.is_empty(), "an empty history produced entities")


func test_it_records_and_returns_a_transform() -> void:
	_history.record(
		4, PackedInt32Array([3]), PackedVector3Array([Vector3(1, 2, 3)]), PackedFloat32Array([0.5])
	)
	var world := _history.rewind(4, Vector3(1, 2, 3), 1.0)
	assert_eq(world.tick, 4, "the rewind answered a different tick")
	assert_true(world.has(3), "the recorded entity is missing")
	assert_eq(world.position_of(3), Vector3(1, 2, 3), "the position was not preserved")
	assert_almost_eq(world.yaw_of(3), 0.5, 0.001, "the yaw was not preserved")


func test_the_past_is_the_past_and_not_the_present() -> void:
	# **THE ASSERTION THE WHOLE FEATURE IS FOR.** If a rewind returned current
	# positions, every test above would still pass and lag compensation would do
	# nothing at all — which is precisely the failure that would survive to M4.
	_walk(10)
	var world := _history.rewind(1, Vector3.ZERO, 100.0)
	assert_eq(world.position_of(7), Vector3.ZERO, "tick 1 did not return tick 1's position")
	var latest := _history.rewind(10, Vector3.ZERO, 100.0)
	assert_eq(latest.position_of(7), Vector3(0, 0, 9), "the newest tick is wrong")


func test_the_oldest_frame_is_overwritten_rather_than_grown() -> void:
	# A ring that grew would hold the whole match — 14 400 frames at eight
	# minutes, not 15 — and the memory budget in §8.3 would be wrong by three
	# orders of magnitude.
	_walk(40)
	assert_eq(_history.size(), _history.capacity(), "the ring grew past its capacity")
	assert_eq(_history.newest_tick(), 40, "the newest tick is not the last recorded")
	assert_eq(_history.oldest_tick(), 26, "the ring is not holding exactly the last 15 ticks")


func test_only_entities_near_the_action_are_rewound() -> void:
	# §8.3's optimisation, and it is a cost property rather than a correctness
	# one: fewer than 10 entities per validation rather than 96 is what makes lag
	# compensation affordable per kill.
	var ids := PackedInt32Array([1, 2, 3])
	var positions := PackedVector3Array([Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(50, 0, 0)])
	var yaws := PackedFloat32Array([0.0, 0.0, 0.0])
	_history.record(1, ids, positions, yaws)

	var world := _history.rewind(1, Vector3.ZERO, 7.5)
	assert_eq(world.size(), 2, "the radius did not exclude the distant entity")
	assert_true(world.has(1) and world.has(2), "a nearby entity was excluded")
	assert_false(world.has(3), "an entity 50 m away was rewound")


func test_an_absent_entity_is_not_reported_at_the_origin() -> void:
	# **THE DANGEROUS DEFAULT.** At M4 a kill validated against (0, 0, 0) would
	# succeed from anywhere in the district for anybody standing near the corner
	# of the map, so the fallback must be unmistakable rather than plausible.
	_history.record(
		1, PackedInt32Array([1]), PackedVector3Array([Vector3.ZERO]), PackedFloat32Array([0.0])
	)
	var world := _history.rewind(1, Vector3.ZERO, 10.0)
	assert_eq(world.position_of(99), Vector3.INF, "an absent entity defaulted to the origin")


func test_a_tick_past_the_ring_clamps_rather_than_failing() -> void:
	# §8.1's clamp should make this unreachable. If it is ever reached, the safe
	# answer is the oldest world actually held — which is *less* far into the
	# past, never more — rather than an error that fails a legitimate kill.
	_walk(20)
	var world := _history.rewind(1, Vector3.ZERO, 100.0)
	assert_false(world.is_empty(), "a tick older than the ring produced nothing at all")
	assert_eq(world.tick, _history.oldest_tick(), "the clamp did not land on the oldest frame")
	assert_gt(world.tick, 1, "the ring claims to still hold a tick it has overwritten")


func test_memory_stays_around_the_budgeted_twenty_three_kilobytes() -> void:
	# §8.3 budgets 6 pawns + 90 NPCs × 16 B × 15 ≈ 23 KB. **Measured, not
	# trusted** — §7.1 budgeted the snapshot from sizes nobody had measured and
	# reported 87 % of a budget it was at 113 % of.
	for tick: int in 15:
		var ids := PackedInt32Array()
		var positions := PackedVector3Array()
		var yaws := PackedFloat32Array()
		for entity: int in 96:
			ids.append(entity)
			positions.append(Vector3(float(entity), 0.0, float(tick)))
			yaws.append(0.0)
		_history.record(tick + 1, ids, positions, yaws)

	var kb := _history.bytes() / 1024.0
	gut.p("lag-comp history at 96 entities × 15 ticks: %.1f KB" % kb)
	# 20 B per record, not §8.3's 16: the id is stored rather than implied,
	# because entities join and leave and a dense array indexed by slot would
	# name the wrong player after a rejoin.
	assert_between(kb, 20.0, 32.0, "the history is nowhere near §8.3's 23 KB budget")


func test_clear_empties_it() -> void:
	_walk(10)
	_history.clear()
	assert_eq(_history.size(), 0, "clear left frames behind")
	assert_true(_history.rewind(5, Vector3.ZERO, 10.0).is_empty(), "clear left a rewindable world")
