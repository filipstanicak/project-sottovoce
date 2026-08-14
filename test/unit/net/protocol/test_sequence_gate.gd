## Stale and replayed input is dropped. US-0026.
##
## **THE WRAP IS THE WHOLE TEST.** `seq` is a `u16` sent 60 times a second, so it
## wraps about every 18 minutes — inside a single match. A gate written as
## `seq > last` passes every ordinary case, passes every test anyone would think
## to write, and then rejects **every input for eighteen minutes** the first time
## the counter rolls over. Half these cases exist for that one boundary.
extends GutTest

const PEER := 3

var _gate: SequenceGate


func before_each() -> void:
	_gate = SequenceGate.new()


func test_the_first_command_from_a_peer_is_accepted() -> void:
	assert_true(_gate.accept(PEER, 500), "a peer's first input was dropped")


func test_a_newer_sequence_is_accepted() -> void:
	_gate.accept(PEER, 10)
	assert_true(_gate.accept(PEER, 11))


func test_a_replay_is_dropped() -> void:
	# The same packet twice is a repeated action, which is a client asserting an
	# outcome by saying it a second time.
	_gate.accept(PEER, 10)
	assert_false(_gate.accept(PEER, 10), "the same sequence was accepted twice")


func test_a_reordered_packet_is_dropped() -> void:
	# UDP reorders; this is the transport working as designed. Applying the older
	# one on top of the newer reads as the pawn twitching backwards.
	_gate.accept(PEER, 20)
	assert_false(_gate.accept(PEER, 19))
	assert_false(_gate.accept(PEER, 5))


func test_a_gap_is_accepted_because_udp_loses_packets() -> void:
	# Not every missing sequence is an attack. Requiring seq == last + 1 would
	# stall the pawn on the first dropped packet and never recover.
	_gate.accept(PEER, 10)
	assert_true(_gate.accept(PEER, 40), "a lost packet stalled the gate")


func test_it_survives_the_wrap() -> void:
	# **THE CASE THAT COSTS EIGHTEEN MINUTES OF UNRESPONSIVE PAWN.** 0 is not
	# greater than 65535, and a naive gate refuses it forever.
	_gate.accept(PEER, 65535)
	assert_true(_gate.accept(PEER, 0), "the gate closed at the wrap")
	assert_true(_gate.accept(PEER, 1))


func test_an_old_sequence_across_the_wrap_is_still_old() -> void:
	# The other half. Having wrapped, 65530 must read as the past — not as a
	# number so much larger that it looks like the future.
	_gate.accept(PEER, 65535)
	_gate.accept(PEER, 3)
	assert_false(_gate.accept(PEER, 65530), "a pre-wrap sequence was treated as newer")


func test_newness_is_a_signed_distance_at_the_boundary() -> void:
	# Stated directly on the arithmetic, so the property is visible without a
	# peer: half the range ahead is newer, half behind is older, symmetrically.
	assert_true(SequenceGate.is_newer(1, 0))
	assert_false(SequenceGate.is_newer(0, 1))
	assert_true(SequenceGate.is_newer(0, 65535), "the wrap did not read as forward")
	assert_false(SequenceGate.is_newer(65535, 0), "the wrap read as backward")
	assert_true(SequenceGate.is_newer(SequenceGate.HALF - 1, 0), "just inside the window")
	assert_false(SequenceGate.is_newer(SequenceGate.HALF + 1, 0), "just outside the window")
	assert_false(SequenceGate.is_newer(5, 5), "a repeat read as newer")


func test_peers_do_not_share_a_sequence() -> void:
	_gate.accept(PEER, 900)
	assert_true(_gate.accept(4, 2), "one peer's sequence gated another's")


func test_a_departed_peer_is_forgotten() -> void:
	# ENet reuses peer ids. A stale entry would make the next joiner's first
	# eighteen minutes of input arrive "in the past" — a pawn that never moves,
	# on a server logging nothing.
	_gate.accept(PEER, 40000)
	_gate.forget(PEER)
	assert_true(_gate.accept(PEER, 1), "a recycled peer id inherited the last one's sequence")


func test_the_last_accepted_sequence_is_readable_for_the_snapshot_header() -> void:
	assert_eq(_gate.last_seen(PEER), -1, "an unheard peer did not read as unknown")
	_gate.accept(PEER, 77)
	assert_eq(_gate.last_seen(PEER), 77)
	_gate.accept(PEER, 70)
	assert_eq(_gate.last_seen(PEER), 77, "a dropped packet moved the ack")
