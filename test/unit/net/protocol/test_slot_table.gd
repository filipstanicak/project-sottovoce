## Peer ids never reach the wire. US-0029.
##
## Godot hands out a random 32-bit id per peer — a real one from a two-process
## run was **1 526 710 570** — and the catalogue declares `peer_id:u8` in seven
## places. A match holds at most six players, so the byte is right and the engine
## is the anomaly; this is the mapping that reconciles them.
extends GutTest

## Deliberately the shape Godot really produces, not 1 and 2.
const A := 1526710570
const B := 48400797
const C := 1414339443

var _slots: SlotTable


func before_each() -> void:
	_slots = SlotTable.new()


func test_a_peer_gets_a_slot_that_fits_a_byte() -> void:
	var slot := _slots.assign(A)
	assert_between(slot, SlotTable.FIRST_SLOT, 255, "the slot does not fit the wire field")


func test_slot_zero_means_nobody() -> void:
	# **THE RESERVATION IS LOAD-BEARING.** A record that was never filled in
	# decodes as absent rather than as player one — which is the difference
	# between a bug that shows and a bug that names the wrong killer.
	assert_eq(_slots.slot_of(A), SlotTable.NO_SLOT, "an unknown peer has a slot")
	assert_ne(_slots.assign(A), SlotTable.NO_SLOT, "a real peer was given the nobody slot")


func test_the_mapping_goes_both_ways() -> void:
	var slot := _slots.assign(A)
	assert_eq(_slots.peer_of(slot), A, "the slot does not lead back to the peer")
	assert_eq(_slots.slot_of(A), slot)


func test_assigning_twice_returns_the_same_slot() -> void:
	# A peer that reconnects inside one match must not consume two, or six
	# players and two reconnects exhaust a lobby that holds six.
	assert_eq(_slots.assign(A), _slots.assign(A))
	assert_eq(_slots.count(), 1)


func test_two_peers_never_share_a_slot() -> void:
	# The whole point: two players sharing a slot is two players sharing an
	# identity in every message that names one.
	assert_ne(_slots.assign(A), _slots.assign(B))


func test_a_released_slot_is_reused() -> void:
	# **THE LOWEST FREE SLOT, NOT THE NEXT ONE.** A counter that only counted up
	# would exhaust the byte after 255 joins on a long-lived server, and would do
	# it silently: the 256th player would be slot 0, which means nobody.
	var first := _slots.assign(A)
	_slots.release(A)
	assert_eq(_slots.assign(B), first, "the freed slot was not reused")


func test_releasing_clears_both_directions() -> void:
	var slot := _slots.assign(A)
	_slots.release(A)
	assert_eq(_slots.slot_of(A), SlotTable.NO_SLOT)
	assert_eq(_slots.peer_of(slot), 0, "the slot still leads back to a peer that left")
	assert_false(_slots.has_peer(A))


func test_releasing_an_unknown_peer_is_harmless() -> void:
	# Disconnect arrives for peers that never completed a handshake.
	_slots.release(9999)
	assert_eq(_slots.count(), 0)


func test_the_table_refuses_more_than_the_lobby_holds() -> void:
	# `TUN-LOBBY-MAX-PLAYERS` is the ceiling. Refusing is right: a seventh player
	# with no slot cannot be named in any message, so admitting them would produce
	# a pawn nobody could be told about.
	var ceiling: int = Tuning.match_rules.max_players
	for i: int in ceiling:
		assert_ne(_slots.assign(1000 + i), SlotTable.NO_SLOT, "peer %d was refused a slot" % i)
	assert_eq(_slots.assign(C), SlotTable.NO_SLOT, "a seventh player was given a slot")
	assert_eq(_slots.count(), ceiling)


func test_clearing_starts_the_next_match_clean() -> void:
	_slots.assign(A)
	_slots.clear()
	assert_eq(_slots.count(), 0)
	assert_eq(_slots.assign(B), SlotTable.FIRST_SLOT, "the next match did not start at slot one")
