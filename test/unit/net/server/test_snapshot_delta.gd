## **WHAT A DELTA OMITS, AND WHAT IT MUST NEVER OMIT.** US-0031, TDD-04 §7.2.
##
## The baseline is what the client **acknowledged**, never what was last sent.
## Snapshots ride the unreliable `STATE` channel, so "sent" says nothing about
## "arrived" — and delta-ing against the last sent snapshot is the classic
## version of this bug: perfect until one packet drops, then every subsequent
## delta is applied to a baseline the client does not have. It does not reproduce
## on a LAN, and the symptom is a remote player frozen on a connection that looks
## healthy.
extends GutTest

const PEER := 4
const OTHER := 5

var _delta: SnapshotDelta


func before_each() -> void:
	_delta = SnapshotDelta.new()


func _record(slot: int, z: float, yaw: float = 0.0) -> Array:
	return [slot, Vector3(0.0, 0.0, z), yaw, PawnStateId.STROLL, 0, 0]


func test_with_no_ack_at_all_everything_is_sent() -> void:
	# A client that has acknowledged nothing has nothing to delta against, and
	# the only safe answer is the whole world.
	var records := [_record(1, 1.0), _record(2, 2.0)]
	assert_eq(_delta.baseline_age(PEER, 10), Snapshot.FULL, "a peer with no ack got a delta")
	assert_eq(_delta.changed(PEER, 10, records).size(), 2, "a full send dropped a record")


func test_an_unchanged_record_is_omitted() -> void:
	# **THE SAVING, AND THE WHOLE POINT OF THE STORY.**
	var records := [_record(1, 1.0), _record(2, 2.0)]
	_delta.remember(PEER, 10, records)
	_delta.note_ack(PEER, 10)

	assert_eq(_delta.baseline_age(PEER, 11), 1, "the baseline is not one tick back")
	assert_eq(_delta.changed(PEER, 11, records).size(), 0, "nothing changed and something was sent")


func test_a_changed_record_is_sent_and_the_others_are_not() -> void:
	_delta.remember(PEER, 10, [_record(1, 1.0), _record(2, 2.0)])
	_delta.note_ack(PEER, 10)

	var moved := [_record(1, 1.0), _record(2, 9.0)]
	var out := _delta.changed(PEER, 11, moved)
	assert_eq(out.size(), 1, "exactly one record moved and the delta is not one record")
	assert_eq(int(out[0][0]), 2, "the wrong record was sent")


func test_a_new_slot_is_always_sent() -> void:
	# A slot the baseline never held cannot be inherited from it.
	_delta.remember(PEER, 10, [_record(1, 1.0)])
	_delta.note_ack(PEER, 10)
	var out := _delta.changed(PEER, 11, [_record(1, 1.0), _record(2, 2.0)])
	assert_eq(out.size(), 1, "a newly appearing slot was omitted")
	assert_eq(int(out[0][0]), 2, "the wrong record was treated as new")


func test_the_comparison_is_quantised_not_exact() -> void:
	# **§7.2 SAYS "QUANTISED STATE", AND IT MATTERS IN BOTH DIRECTIONS.** A
	# position 3 mm away rounds to the same centimetre and its bytes are
	# identical, so sending it would spend bandwidth on a change no client could
	# represent. Comparing the `Vector3`s instead would send it every tick.
	_delta.remember(PEER, 10, [_record(1, 1.0)])
	_delta.note_ack(PEER, 10)
	var nudged := [[1, Vector3(0.0, 0.0, 1.003), 0.0, PawnStateId.STROLL, 0, 0]]
	assert_eq(
		_delta.changed(PEER, 11, nudged).size(),
		0,
		"a 3 mm move was sent as a change — the comparison is not quantised"
	)


func test_a_move_larger_than_a_step_is_sent() -> void:
	# The other half of the test above. If the quantised comparison also swallowed
	# real movement, every assertion here would pass over a delta that sent
	# nothing ever.
	_delta.remember(PEER, 10, [_record(1, 1.0)])
	_delta.note_ack(PEER, 10)
	var moved := [[1, Vector3(0.0, 0.0, 1.05), 0.0, PawnStateId.STROLL, 0, 0]]
	assert_eq(_delta.changed(PEER, 11, moved).size(), 1, "a 5 cm move was omitted as unchanged")


func test_equal_fingerprints_really_do_serialise_identically() -> void:
	# **THE FINGERPRINT IS ONLY WORTH HAVING IF IT MATCHES THE WRITER.** If the two
	# ever come apart, a record is omitted as unchanged while its bytes differ,
	# and the client renders a player at a position the server never had.
	var a := _record(3, 1.0, 0.5)
	var b := [3, Vector3(0.0, 0.0, 1.004), 0.502, PawnStateId.STROLL, 0, 0]
	assert_eq(
		Snapshot.remote_fingerprint(a),
		Snapshot.remote_fingerprint(b),
		"the probe is not comparing equal records"
	)

	var first := Snapshot.new()
	first.remote_pawns = [a]
	var second := Snapshot.new()
	second.remote_pawns = [b]
	assert_eq(first.serialise(), second.serialise(), "equal fingerprints produced different bytes")


func test_a_lost_ack_grows_the_delta_and_never_corrupts_it() -> void:
	# **US-0031's FOURTH CRITERION.** The client stops acknowledging. The baseline
	# must stay at the last tick it *did* acknowledge — which it demonstrably
	# holds — so the deltas get larger and stay appliable.
	_delta.remember(PEER, 10, [_record(1, 1.0)])
	_delta.note_ack(PEER, 10)
	for tick: int in range(11, 20):
		_delta.remember(PEER, tick, [_record(1, float(tick))])

	assert_eq(_delta.baseline_age(PEER, 20), 10, "the baseline moved past the client's last ack")
	assert_eq(
		_delta.changed(PEER, 20, [_record(1, 20.0)]).size(), 1, "the moved record was omitted"
	)


func test_a_baseline_older_than_the_byte_can_express_is_a_full_send() -> void:
	_delta.remember(PEER, 1, [_record(1, 1.0)])
	_delta.note_ack(PEER, 1)
	var far := 1 + Snapshot.MAX_BASELINE_AGE + 1
	assert_eq(_delta.baseline_age(PEER, far), Snapshot.FULL, "an unrepresentable age was not full")


func test_a_baseline_the_server_has_discarded_is_a_full_send() -> void:
	# The client acknowledges a tick, then says nothing for longer than the
	# server's own history. Falling back to full is the only correct answer, and
	# it is why `baseline_age` consults the stored frame rather than only the
	# arithmetic.
	_delta.remember(PEER, 1, [_record(1, 1.0)])
	_delta.note_ack(PEER, 1)
	for tick: int in range(2, SnapshotDelta.HISTORY + 5):
		_delta.remember(PEER, tick, [_record(1, float(tick))])
	assert_eq(
		_delta.baseline_age(PEER, SnapshotDelta.HISTORY + 4),
		Snapshot.FULL,
		"a discarded baseline was still offered as a delta"
	)


func test_the_ack_never_walks_backwards() -> void:
	# Input arrives unordered on an unreliable channel, so a stale command
	# carrying a stale ack must not undo a newer one.
	_delta.note_ack(PEER, 20)
	_delta.note_ack(PEER, 5)
	assert_eq(_delta.acked_tick(PEER), 20, "a stale ack walked the baseline backwards")


func test_peers_do_not_share_a_baseline() -> void:
	# Each client acknowledges on its own schedule. A shared baseline would send
	# one client a delta against a snapshot only the other received.
	_delta.remember(PEER, 10, [_record(1, 1.0)])
	_delta.note_ack(PEER, 10)
	assert_eq(_delta.baseline_age(OTHER, 11), Snapshot.FULL, "a peer inherited another's baseline")


func test_a_departed_peer_leaves_no_baseline_behind() -> void:
	# **ENet REUSES PEER IDS**, US-0037. A baseline left behind would be
	# delta-ed against by whoever inherits the id — who never received it.
	_delta.remember(PEER, 10, [_record(1, 1.0)])
	_delta.note_ack(PEER, 10)
	_delta.forget(PEER)
	assert_eq(_delta.tracked_peers(), 0, "a departed peer kept its bookkeeping")
	assert_eq(_delta.baseline_age(PEER, 11), Snapshot.FULL, "a rejoining peer inherited a baseline")
