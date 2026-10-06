## **EVERY PLAYER HEARS THE WHOLE TABLE ONCE, THEN ONLY THE CHANGES.** US-0107.
extends GutTest

var _announcer: CrowdGroupAnnouncer


func before_each() -> void:
	_announcer = CrowdGroupAnnouncer.new()
	_announcer.groups.apply(PackedByteArray([0, 2, 1]))


func test_a_new_player_is_sent_the_whole_table() -> void:
	_announcer.announce([7], PackedByteArray())
	assert_eq(_announcer.sent.size(), 1)
	assert_eq(_announcer.sent[0], [7, true, PackedByteArray([1, 2, 2, 1])])


func test_a_known_player_is_sent_only_the_change_and_only_if_there_is_one() -> void:
	_announcer.announce([7], PackedByteArray())
	_announcer.announce([7], PackedByteArray())
	assert_eq(_announcer.sent.size(), 1, "a still crowd costs nothing")
	_announcer.announce([7], PackedByteArray([1, 0]))
	assert_eq(_announcer.sent[1], [7, false, PackedByteArray([1, 0])])


func test_everybody_is_told_the_same_change() -> void:
	_announcer.announce([7, 9], PackedByteArray())
	_announcer.announce([7, 9], PackedByteArray([2, 0]))
	assert_eq(_announcer.sent[2][2], _announcer.sent[3][2])


func test_a_peer_id_reused_after_a_departure_gets_a_fresh_table() -> void:
	_announcer.announce([7], PackedByteArray())
	_announcer.announce([], PackedByteArray())
	_announcer.announce([7], PackedByteArray([1, 0]))
	assert_eq(_announcer.sent[1][1], true, "the newcomer was sent a change to a table it never had")
