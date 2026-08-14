## Smoothed per-peer RTT. US-0025.
##
## Asserted as *behaviour under a sequence of samples*, never against a
## particular smoothed value: the coefficient is an implementation choice, and a
## test that pinned `0.25` would fail the day someone tuned it while proving
## nothing about whether the smoothing works.
extends GutTest

var _table: RttTable


func before_each() -> void:
	_table = RttTable.new()


func test_an_unmeasured_peer_reads_zero() -> void:
	# And zero means UNKNOWN. Lag compensation clamps at TUN-NET-LAGCOMP-MIN, so
	# an unmeasured peer rewinds by the floor rather than by nothing at all.
	assert_eq(_table.rtt_ms(2), 0.0)
	assert_false(_table.has_peer(2))


func test_the_first_sample_is_taken_whole() -> void:
	# Smoothing toward a zero the peer never had would report half the truth for
	# several seconds — worst precisely at a join, which is when it is read.
	_table.record(2, 120.0)
	assert_almost_eq(_table.rtt_ms(2), 120.0, 0.001)


func test_it_moves_toward_a_changed_connection_without_jumping_to_it() -> void:
	# The shape of smoothing, stated as two facts rather than as an arithmetic
	# result: it moves, and it does not arrive in one sample.
	_table.record(2, 100.0)
	_table.record(2, 200.0)
	assert_gt(_table.rtt_ms(2), 100.0, "a worsening connection was ignored")
	assert_lt(_table.rtt_ms(2), 200.0, "one sample replaced the whole estimate")


func test_a_sustained_change_is_converged_on() -> void:
	_table.record(2, 100.0)
	for _i: int in 40:
		_table.record(2, 200.0)
	assert_almost_eq(_table.rtt_ms(2), 200.0, 1.0, "it never caught up with a settled connection")


func test_a_spike_decays_instead_of_being_remembered() -> void:
	for _i: int in 20:
		_table.record(2, 50.0)
	_table.record(2, 900.0)
	var spiked := _table.rtt_ms(2)
	for _i: int in 20:
		_table.record(2, 50.0)
	assert_lt(_table.rtt_ms(2), spiked, "the spike was not forgotten")
	assert_almost_eq(_table.rtt_ms(2), 50.0, 1.0)


func test_peers_do_not_share_an_estimate() -> void:
	_table.record(2, 30.0)
	_table.record(3, 300.0)
	assert_almost_eq(_table.rtt_ms(2), 30.0, 0.001)
	assert_almost_eq(_table.rtt_ms(3), 300.0, 0.001)


func test_a_departed_peer_is_forgotten() -> void:
	# **NOT TIDINESS.** ENet reuses peer ids, so a stale entry hands the next
	# joiner the last one's connection quality — and the number it decides is how
	# far into the past a kill may reach.
	_table.record(2, 300.0)
	_table.forget(2)
	assert_false(_table.has_peer(2), "a peer that left is still measured")
	assert_eq(_table.rtt_ms(2), 0.0)


func test_a_negative_sample_cannot_poison_the_estimate() -> void:
	# `client_time` is client-supplied. A clock that runs backwards, or a peer
	# that lies, must not be able to produce a negative round trip.
	_table.record(2, -50.0)
	assert_eq(_table.rtt_ms(2), 0.0)
