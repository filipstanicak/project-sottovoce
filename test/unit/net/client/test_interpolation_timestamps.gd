## **REMOTE ENTITIES ARE READ BETWEEN STAMPED SAMPLES, NEVER SPACED ONES.**
## TDD-04 §5, US-0034.
##
## The named test in TDD-04 §12: *mixed 30 Hz and 10 Hz entity streams both
## interpolate correctly with no stutter at the LOD boundary.* That case is the
## reason the buffer is timestamped at all — far NPCs arrive at 10 Hz and near
## ones at 30, and code that assumed a fixed interval would make the two rates
## fight.
##
## Everything here is asserted against **the samples' own timeline**, never
## against a wall clock and never against an assumed frame count.
extends GutTest

const NEAR := 1
const FAR := 2

var _interp: SnapshotInterpolator


func before_each() -> void:
	_interp = SnapshotInterpolator.new()


## Feed `count` samples at `hz`, walking a straight line at 2 m/s along +Z from
## `start_time`. Returns the time of the last sample.
func _stream(id: int, hz: float, count: int, start_time: float = 0.0) -> float:
	var step := 1.0 / hz
	var at := start_time
	for i: int in count:
		at = start_time + step * float(i)
		_interp.push(id, at, Vector3(0.0, 0.0, 2.0 * at), 0.0)
	return at


func test_a_sample_between_two_others_is_the_point_between_them() -> void:
	_interp.push(NEAR, 1.0, Vector3(0.0, 0.0, 0.0), 0.0)
	_interp.push(NEAR, 2.0, Vector3(0.0, 0.0, 10.0), 0.0)
	var at: Array = _interp.sample(NEAR, 1.5)
	assert_almost_eq((at[0] as Vector3).z, 5.0, 0.001, "halfway between is not halfway")


func test_thirty_hertz_and_ten_hertz_both_read_the_same_line() -> void:
	# **THE LOD BOUNDARY.** The same motion, sampled at two rates, must produce
	# the same answer at the same moment — otherwise a crowd member crossing 45 m
	# would visibly change speed as its rate halved.
	#
	# Both streams are kept inside `HISTORY`, deliberately. Feeding 30 samples at
	# 30 Hz pushes the early ones out of a 16-deep buffer, and the test then reads
	# the HOLD path while claiming to measure interpolation — which is how the
	# first version of this case failed.
	_stream(NEAR, 30.0, 15)
	_stream(FAR, 10.0, 5)
	for moment: float in [0.15, 0.25, 0.35]:
		var near: Array = _interp.sample(NEAR, moment)
		var far: Array = _interp.sample(FAR, moment)
		assert_almost_eq(
			(near[0] as Vector3).z,
			(far[0] as Vector3).z,
			0.02,
			"the two rates disagree at t=%.2f" % moment
		)


func test_the_slower_stream_still_moves_between_its_samples() -> void:
	# The failure this guards is a 10 Hz entity that teleports 10 times a second
	# while a 30 Hz one glides — which is what "assume a fixed interval" produces.
	_stream(FAR, 10.0, 10)
	var early: Array = _interp.sample(FAR, 0.42)
	var later: Array = _interp.sample(FAR, 0.48)
	assert_gt(
		(later[0] as Vector3).z,
		(early[0] as Vector3).z,
		"a slow stream did not move between two of its own samples"
	)


func test_it_never_extrapolates_past_the_newest_sample() -> void:
	# **NO GUESSING.** An extrapolated player who was about to stop is a player
	# who appears to walk through a wall, and in a game where thirty centimetres
	# decides a kill, guessing is worse than lagging (TDD-04 §5.1).
	var last := _stream(NEAR, 30.0, 10)
	var held: Array = _interp.sample(NEAR, last)
	var far_future: Array = _interp.sample(NEAR, last + 5.0)
	assert_eq(far_future[0], held[0], "the buffer extrapolated instead of holding")


func test_it_holds_the_oldest_sample_before_the_stream_starts() -> void:
	# What a client that has just seen an entity for the first time gets. Holding
	# is right there too: it has no evidence of anything earlier.
	_stream(NEAR, 30.0, 5, 10.0)
	var before: Array = _interp.sample(NEAR, 0.0)
	assert_almost_eq((before[0] as Vector3).z, 20.0, 0.001, "it invented a past")


func test_an_unknown_entity_reads_as_nothing() -> void:
	# Not the origin. A remote pawn placed at (0,0,0) is standing in the corner of
	# the district, which looks like a real position and is not one.
	assert_true(_interp.sample(99, 1.0).is_empty())


func test_out_of_order_samples_are_dropped() -> void:
	# UDP reorders. A sample older than one already held describes a past the
	# buffer has moved beyond, and inserting it would drag the entity backwards.
	_interp.push(NEAR, 2.0, Vector3(0.0, 0.0, 10.0), 0.0)
	_interp.push(NEAR, 1.0, Vector3(0.0, 0.0, 0.0), 0.0)
	assert_eq(_interp.sample_count(NEAR), 1, "a late sample was inserted")
	assert_almost_eq(_interp.newest_time(NEAR), 2.0, 0.001)


func test_yaw_takes_the_short_way_round() -> void:
	# A pawn turning past north goes 359° -> 1°. A straight lerp spins it 358
	# degrees in one frame, on a silhouette a player is trying to read.
	_interp.push(NEAR, 0.0, Vector3.ZERO, deg_to_rad(359.0))
	_interp.push(NEAR, 1.0, Vector3.ZERO, deg_to_rad(1.0))
	var mid: Array = _interp.sample(NEAR, 0.5)
	var degrees := fposmod(rad_to_deg(mid[1] as float), 360.0)
	assert_true(degrees > 359.0 or degrees < 1.0, "yaw spun the long way: %.1f°" % degrees)


func test_the_history_is_bounded() -> void:
	# A buffer that grew forever would be a leak measured in minutes of match.
	_stream(NEAR, 30.0, 200)
	assert_eq(_interp.sample_count(NEAR), SnapshotInterpolator.HISTORY)


func test_the_kept_history_covers_more_than_the_interpolation_delay() -> void:
	# **THE PROPERTY THAT MATTERS, NOT THE NUMBER.** However many samples are
	# kept, they must span longer than `TUN-NET-INTERP-BUFFER` — or the render
	# time falls off the back of the buffer and every entity holds, permanently.
	_stream(NEAR, Tuning.net.snapshot_rate, 200)
	var span := (
		_interp.newest_time(NEAR) - (SnapshotInterpolator.HISTORY - 1) / Tuning.net.snapshot_rate
	)
	assert_gt(
		_interp.newest_time(NEAR) - span,
		Tuning.net.interp_buffer / 1000.0,
		"the history is shorter than the interpolation delay"
	)


func test_a_forgotten_entity_leaves_nothing_behind() -> void:
	_stream(NEAR, 30.0, 5)
	_interp.forget(NEAR)
	assert_false(_interp.has(NEAR))
	assert_true(_interp.sample(NEAR, 0.1).is_empty())
