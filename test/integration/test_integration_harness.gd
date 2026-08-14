## **THREE REAL CLIENTS AND A REAL SERVER, AT FOUR LATENCIES.** US-0036.
##
## Everything the harness stands up is the shipping object — the real client
## scene with its real driver and reconciler, a real `PawnHost` driving
## `pawn_server.tscn`, real `Snapshot` bytes on the wire. Only the wire itself is
## synthetic, because `Net` is an autoload and one process holds one of it.
##
## **THIS IS THE FILE THAT RETIRES "VERIFIED BY HAND."** US-0025, US-0028 and
## US-0030 were each proven by launching processes and reading their logs. What
## a log cannot do is fail a pull request.
extends GutTest

const PEERS: Array[int] = [1, 2, 3]

var _harness: IntegrationHarness


func before_each() -> void:
	IntegrationHarness.release_everything()
	_harness = IntegrationHarness.new()


func after_each() -> void:
	_harness.tear_down()


## Stand up a match at `profile` and walk everybody forward for `frames`.
func _walk_together(profile: StringName, frames: int) -> void:
	_harness.start(get_tree(), self, profile)
	for peer: int in PEERS:
		_harness.add_client(peer)
	await get_tree().physics_frame
	await _harness.drive(&"input_move_forward", frames)
	await _harness.advance(20)


## **THE RECONCILIATION ERROR, NOT THE PREDICTION LEAD.** These read
## `disagreement()` until US-0035 — the live distance between the client's pawn
## and the server's, which in a predicting architecture is *never* zero and is
## not an error. Measured, that lead is exactly 2.00 commands at every speed:
## 0.0733 m at stroll, **0.1500 m at run against a 0.10 m threshold**. The
## assertions passed because the harness only ever walks.
func _assert_all_peers_agree(profile: StringName) -> void:
	for peer: int in PEERS:
		assert_lt(
			_harness.reconciliation_error(peer),
			Tuning.net.reconcile_threshold,
			"peer %d left the server behind at %s" % [peer, profile]
		)


# --------------------------------------------------------- the latency matrix --


func test_three_clients_agree_on_a_lan() -> void:
	await _walk_together(&"LAN", 60)
	_assert_all_peers_agree(&"LAN")


func test_three_clients_agree_on_a_good_connection() -> void:
	await _walk_together(&"GOOD", 60)
	_assert_all_peers_agree(&"GOOD")


func test_three_clients_agree_on_a_typical_connection() -> void:
	await _walk_together(&"TYPICAL", 60)
	_assert_all_peers_agree(&"TYPICAL")


func test_three_clients_agree_on_a_poor_connection() -> void:
	# **CONVERGES, NEVER COMPOUNDS**, and the claim is the same at every profile:
	# reconciliation is not supposed to get worse with distance, only busier.
	await _walk_together(&"POOR", 60)
	_assert_all_peers_agree(&"POOR")


# ------------------------------------------------------- what the matrix means --


func test_every_profile_is_covered() -> void:
	# Guards the matrix itself. A profile added to the harness and not walked
	# above is a latency nobody tests, and the file above would look complete.
	assert_eq(IntegrationHarness.PROFILES.size(), 4)
	for profile: StringName in IntegrationHarness.PROFILES:
		assert_true(IntegrationHarness.LATENCY.has(profile), "%s has no delay" % profile)


func test_the_profiles_are_ordered_from_best_to_worst() -> void:
	# The matrix reads as a progression, and a test that failed at GOOD but passed
	# at POOR would be saying something about the harness rather than the netcode.
	var previous := 0
	for profile: StringName in IntegrationHarness.PROFILES:
		var frames: int = IntegrationHarness.LATENCY[profile]
		assert_gt(frames, previous, "%s is not worse than the profile before it" % profile)
		previous = frames


func test_three_clients_are_three_pawns() -> void:
	# The premise. Three clients sharing one server pawn would agree perfectly and
	# prove nothing at all.
	await _walk_together(&"LAN", 30)
	assert_eq(_harness.client_count(), 3)
	assert_eq(_harness.ctx.pawns.size(), 3, "the server does not have three pawns")
	var seen: Dictionary = {}
	for peer: int in PEERS:
		var slot: int = _harness.ctx.slots.slot_of(peer)
		assert_false(seen.has(slot), "two peers share wire slot %d" % slot)
		seen[slot] = true


func test_the_clients_actually_moved() -> void:
	# **WITHOUT THIS EVERY AGREEMENT ABOVE IS VACUOUS.** Three pawns standing
	# still agree perfectly with three server pawns standing still.
	_harness.start(get_tree(), self, &"TYPICAL")
	for peer: int in PEERS:
		_harness.add_client(peer)
	await get_tree().physics_frame
	var start: Dictionary = {}
	for peer: int in PEERS:
		start[peer] = _harness.driver_for(peer).ctx.position

	await _harness.drive(&"input_move_forward", 60)
	await _harness.advance(20)
	for peer: int in PEERS:
		assert_gt(
			_harness.driver_for(peer).ctx.position.distance_to(start[peer] as Vector3),
			1.0,
			"peer %d never went anywhere" % peer
		)


func test_latency_alone_costs_no_corrections_at_all() -> void:
	# **MEASURED, AND IT CORRECTED THE COMMENT THAT WAS HERE FIRST.** That comment
	# said a poor profile ought to produce more replays, or the latency dial was
	# not connected to anything. It produces **zero**, at every profile, and that
	# is the right answer: the client and the server run identical code from
	# identical commands, so being late is not the same as being wrong.
	#
	# What latency actually costs is how STALE a correction is when one is needed
	# — the buffer is longer and the replay is deeper. It does not manufacture
	# error, which is exactly what `test_a_forced_divergence_snaps_the_simulation_
	# exactly` in the reconciliation suite is for.
	await _walk_together(&"POOR", 90)
	var replays := 0
	for peer: int in PEERS:
		replays += _harness.reconciler_for(peer).replays
	_assert_all_peers_agree(&"POOR")
	assert_eq(replays, 0, "latency alone produced a correction — the two peers disagree")
