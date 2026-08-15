## **DELTA ENCODING, END TO END.** US-0031, TDD-04 §7.2 mechanism 3.
##
## `test_snapshot_delta.gd` proves what the server omits and
## `test_snapshot_assembler.gd` proves the client recovers it, both against
## arrays a test chose. This proves the two halves agree **across a real
## serialised wire**, with real clients reconciling against real server pawns.
##
## **THE FIRST TEST IN THIS FILE IS THE ONE THAT MATTERS.** Every other assertion
## here would pass unchanged if `baseline_age` were always `FULL` and the delta
## did nothing at all — the loop already worked before US-0031. A feature that is
## silently inert while its suite goes green is trap 3's family, and this project
## has now hit it four times.
extends GutTest

const PEERS: Array[int] = [1, 2, 3]

var _harness: IntegrationHarness


func before_each() -> void:
	IntegrationHarness.release_everything()
	_harness = IntegrationHarness.new()
	_harness.start(get_tree(), self, &"LAN")


func after_each() -> void:
	_harness.tear_down()


func test_the_stream_really_contains_deltas() -> void:
	# **GUARDS EVERY OTHER TEST IN THIS FILE.** If the ack never reaches the
	# server, or the baseline is never found, the server sends full snapshots
	# forever — correct, wasteful, and indistinguishable from working.
	_harness.add_client(1)
	_harness.add_client(2)
	await _harness.drive(&"input_move_forward", 60)

	assert_gt(_harness.full_snapshots, 0, "no full snapshot was ever sent — the first one must be")
	assert_gt(
		_harness.delta_snapshots,
		_harness.full_snapshots,
		"the stream is mostly full snapshots — delta encoding is inert"
	)


func test_a_standing_player_stops_costing_bytes() -> void:
	# **THE SAVING, MEASURED.** Two clients, both still. Once the first full
	# snapshot is acknowledged there is nothing left to say about either of them,
	# and the remote-pawn section should empty out.
	_harness.add_client(1)
	_harness.add_client(2)
	await _harness.advance(40)

	var settled_bytes := _harness.snapshot_bytes
	var settled_deltas := _harness.delta_snapshots
	await _harness.advance(40)

	var per_snapshot := (
		float(_harness.snapshot_bytes - settled_bytes)
		/ maxf(float(_harness.delta_snapshots - settled_deltas), 1.0)
	)
	gut.p("standing still: %.1f B per snapshot" % per_snapshot)
	# **THE EXACT FIXED BLOCK, NOT AN UPPER BOUND.** Header 8 + own 43 (which
	# covers the gameplay, compass and match blocks too) + counts 4 = 55 bytes,
	# and a settled delta must be exactly that: **not one remote record.** An
	# assertion written as "less than 72" would pass with a record still being
	# sent, which is trap 4 — true, and not the question.
	var fixed := float(Snapshot.HEADER_BYTES + Snapshot.OWN_BYTES + Snapshot.COUNT_BYTES)
	assert_almost_eq(per_snapshot, fixed, 0.5, "a motionless player is still being sent every tick")
	gut.p(
		(
			"one remote record is %d B, so the saving is %.0f %% of the moving cost"
			% [
				Snapshot.REMOTE_BYTES,
				100.0 * Snapshot.REMOTE_BYTES / (fixed + Snapshot.REMOTE_BYTES)
			]
		)
	)


func test_a_moving_player_is_still_sent() -> void:
	# The other half. A delta that omitted everything would pass the test above
	# and would freeze every remote player in the district.
	_harness.add_client(1)
	_harness.add_client(2)
	await _harness.advance(30)
	var before := _harness.driver_for(2).ctx.position

	await _harness.drive(&"input_move_forward", 60)
	await _harness.advance(20)

	var moved := _harness.driver_for(2).ctx.position.distance_to(before)
	assert_gt(moved, 0.5, "the pawn did not actually move — the test proves nothing")
	assert_almost_eq(
		_harness.host.context_for(2).position.distance_to(_harness.driver_for(2).ctx.position),
		0.0,
		Tuning.net.reconcile_threshold,
		"the server and client disagree about a moving pawn under delta encoding"
	)


func test_everyone_still_agrees_with_deltas_live() -> void:
	# Three clients, the real reconciler, real serialised bytes. If assembly
	# produced a wrong world, the reconciliation error is where it would surface.
	for peer: int in PEERS:
		_harness.add_client(peer)
	await _harness.drive(&"input_move_forward", 90)
	await _harness.advance(30)

	for peer: int in PEERS:
		assert_lt(
			_harness.reconciliation_error(peer),
			Tuning.net.reconcile_threshold,
			"peer %d diverged under delta encoding" % peer
		)


func test_a_departing_player_vanishes_rather_than_being_inherited() -> void:
	# **THE DEFECT `present_slots` EXISTS TO PREVENT**, across the real wire.
	# Before delta encoding, absent meant gone. Now absent means unchanged — so a
	# player who leaves while standing still is omitted for being unchanged, and
	# without the mask would stand in the district for the rest of the match.
	_harness.add_client(1)
	_harness.add_client(2)
	await _harness.advance(40)
	_harness.remove_client(2)
	await _harness.advance(20)

	var snapshot := _harness.builder.build_for(1)
	assert_eq(snapshot.present_slots, 0, "a departed player is still declared present")


func test_churn_leaves_no_baselines_behind() -> void:
	# US-0037's property, extended to the one owner of per-peer state US-0031
	# added. ENet reuses peer ids: a baseline left behind would be delta-ed
	# against by whoever inherits the id, who never received it.
	for _cycle: int in 10:
		for peer: int in PEERS:
			_harness.add_client(peer)
		await _harness.advance(4)
		for peer: int in PEERS:
			_harness.remove_client(peer)
		await _harness.advance(2)

	assert_eq(_harness.builder.delta.tracked_peers(), 0, "churn left delta baselines behind")
