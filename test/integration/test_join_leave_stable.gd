## **CHURN LEAVES NOTHING BEHIND.** US-0037, TDD-04 §3.
##
## Every owner of per-peer state has cleanup code — `SlotTable`, `PeerRegistry`,
## `PawnHost`, `RpcRouter`, `SnapshotBuilder`, `RemotePawns` — and until this
## file none of it had ever run under churn. **Cleanup is the code most likely to
## look correct and never have executed**: it is written once, beside the thing
## it cleans up, and the happy path never reaches it.
##
## **THE FAILURE IT LOOKS FOR IS INHERITANCE, NOT LEAKAGE.** ENet reuses peer
## ids. Anything left behind is not merely wasted memory — it is handed to the
## next joiner, who is then named as somebody else in every message that names
## anybody.
##
## Contract-cycle repair on disconnect is M4's; at M2 there is no cycle to
## repair, and this covers transport-level lifecycle only.
extends GutTest

const PEERS: Array[int] = [1, 2, 3]

## Join-and-leave cycles per churn test. **NOT FIVE MINUTES OF WALL CLOCK.**
## US-0037 asks for five minutes of churn; 18 000 physics frames would take
## longer than the 180 s the whole integration suite is allowed. What five
## minutes buys is *repetition*, and repetition is what this counts — 40 cycles
## against three peers is 120 joins and 120 departures, each with its own
## snapshot stream. The deviation is recorded in the story rather than rounded up.
const CYCLES := 40

var _harness: IntegrationHarness


func before_each() -> void:
	IntegrationHarness.release_everything()
	_harness = IntegrationHarness.new()
	_harness.start(get_tree(), self, &"TYPICAL")


func after_each() -> void:
	_harness.tear_down()


func _baseline() -> Dictionary:
	return {
		"pawns": _harness.host.pawn_count(),
		"ctx_pawns": _harness.ctx.pawns.size(),
		"slots": _harness.ctx.slots.count(),
		"clients": _harness.client_count(),
		"in_flight": _harness.in_flight(),
	}


func _assert_matches(before: Dictionary, after: Dictionary, what: String) -> void:
	for key: String in before:
		assert_eq(after[key], before[key], "%s: `%s` did not return to baseline" % [what, key])


func test_a_peer_that_joins_gets_a_pawn_a_slot_and_a_snapshot() -> void:
	_harness.add_client(1)
	await _harness.advance(20)
	assert_true(_harness.host.has_pawn(1), "the joiner has no pawn")
	assert_ne(_harness.ctx.slots.slot_of(1), SlotTable.NO_SLOT, "the joiner has no wire slot")
	assert_gt(_harness.builder.build_for(1).server_tick, -1, "the joiner cannot be sent a snapshot")


func test_a_peer_that_leaves_takes_everything_with_it() -> void:
	var empty := _baseline()
	_harness.add_client(1)
	await _harness.advance(20)
	_harness.remove_client(1)
	await _harness.advance(5)
	_assert_matches(empty, _baseline(), "one join and one leave")


func test_a_departed_slot_is_reused_rather_than_burned() -> void:
	# **THE BYTE IS SMALL AND THE MATCH IS LONG.** A slot table that only counted
	# up would exhaust `u8` after 255 joins and hand the 256th player slot 0,
	# which means nobody.
	_harness.add_client(1)
	var first := _harness.ctx.slots.slot_of(1)
	_harness.remove_client(1)
	_harness.add_client(2)
	assert_eq(_harness.ctx.slots.slot_of(2), first, "the freed slot was not reused")


func test_a_rejoining_peer_does_not_inherit_its_own_past() -> void:
	# The same peer id twice is the ordinary case for a reconnect, and the one
	# where stale bookkeeping is hardest to see: everything it inherits is its own.
	_harness.add_client(1)
	# **DRIVEN, NOT MERELY WAITED ON.** The first version let the pawn stand still
	# for 30 frames and then asserted the rejoining one did not resume from where
	# it stopped — which it trivially did not, because it had not gone anywhere.
	# The assertion was true of the wrong thing; trap 4, in a test about cleanup.
	await _harness.drive(&"input_move_forward", 30)
	var moved := _harness.driver_for(1).ctx.position
	_harness.remove_client(1)
	await _harness.advance(5)

	_harness.add_client(1)
	await _harness.advance(5)
	assert_eq(_harness.host.pawn_count(), 1, "the rejoin left two pawns")
	assert_gt(
		_harness.host.context_for(1).position.distance_to(moved),
		0.0,
		"the rejoining peer resumed from where the old one stopped"
	)


func test_the_others_keep_agreeing_while_someone_joins() -> void:
	# **NO STUTTER FOR THE INCUMBENTS.** A joiner spawning, taking a slot and
	# entering everyone's snapshot must not disturb anybody else's prediction.
	_harness.add_client(1)
	_harness.add_client(2)
	await _harness.drive(&"input_move_forward", 30)
	_harness.add_client(3)
	await _harness.drive(&"input_move_forward", 30)
	await _harness.advance(20)
	for peer: int in PEERS:
		assert_lt(
			_harness.reconciliation_error(peer),
			Tuning.net.reconcile_threshold,
			"peer %d was disturbed by the churn" % peer
		)


func test_churn_returns_everything_to_baseline() -> void:
	# **THE ASSERTION THE FILE IS FOR.** Everything above tests one cycle; this
	# tests that a cycle leaves no residue, forty times over.
	var empty := _baseline()
	for _cycle: int in CYCLES:
		for peer: int in PEERS:
			_harness.add_client(peer)
		await _harness.advance(3)
		for peer: int in PEERS:
			_harness.remove_client(peer)
		await _harness.advance(2)
	_assert_matches(empty, _baseline(), "%d cycles of three peers" % CYCLES)


func test_churn_never_runs_out_of_slots() -> void:
	# 120 joins against a table that holds six. If a departure failed to release,
	# this is where it shows — as a joiner with no slot, which is a player who
	# cannot be named in any message.
	for cycle: int in CYCLES:
		for peer: int in PEERS:
			_harness.add_client(peer)
			assert_ne(
				_harness.ctx.slots.slot_of(peer),
				SlotTable.NO_SLOT,
				"cycle %d: peer %d was refused a slot" % [cycle, peer]
			)
		await _harness.advance(2)
		for peer: int in PEERS:
			_harness.remove_client(peer)


func test_a_survivor_still_agrees_after_the_churn() -> void:
	# One client stays for the whole storm. If churn corrupted anything shared —
	# the slot table, the snapshot builder's view of who exists — the survivor is
	# where it would surface.
	_harness.add_client(1)
	await _harness.advance(10)
	for _cycle: int in 20:
		_harness.add_client(2)
		await _harness.advance(3)
		_harness.remove_client(2)
		await _harness.advance(2)
	await _harness.drive(&"input_move_forward", 30)
	await _harness.advance(20)
	assert_true(_harness.has_client(1), "the survivor was removed by somebody else's churn")
	assert_lt(
		_harness.reconciliation_error(1),
		Tuning.net.reconcile_threshold,
		"the survivor drifted from the server across the churn"
	)
