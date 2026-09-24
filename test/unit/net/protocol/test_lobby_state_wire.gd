## `NET-S2C-LOBBY-STATE` as bytes. US-0101.
##
## The roster is what lets a client dress the players at all, so a payload read
## wrong is a district where one player wears somebody else's colour — or where one
## client draws a Lucerna the others draw as a Cantatrice.
extends GutTest


func test_a_roster_survives_the_wire() -> void:
	var sent := {1: Ids.PERSONA_LUCERNA, 2: Ids.PERSONA_VETRAIO, 5: Ids.PERSONA_LUCERNA}
	var got := LobbyStateWire.unpack(LobbyStateWire.pack(sent))
	assert_eq(got.size(), 1, "a well-formed roster was refused")
	assert_eq(got[0], sent, "the roster changed on the wire")


func test_an_undealt_seat_arrives_as_unknown() -> void:
	var got := LobbyStateWire.unpack(LobbyStateWire.pack({3: &""}))
	assert_eq(got[0], {3: &""}, "an undealt seat decoded as somebody's persona")


func test_an_empty_roster_is_a_roster() -> void:
	var got := LobbyStateWire.unpack(LobbyStateWire.pack({}))
	assert_eq(got, [{}], "an empty lobby was treated as a malformed packet")


## **A SHORT PACKET IS DROPPED WHOLE.** Read past its end, it would decode seat 0 as
## a Cantatrice — persona index 0 — and nobody would see anything wrong.
func test_a_payload_that_disagrees_with_its_count_is_dropped() -> void:
	var bytes := LobbyStateWire.pack({1: Ids.PERSONA_PESATORE, 2: Ids.PERSONA_CANTATRICE})
	assert_eq(LobbyStateWire.unpack(bytes.slice(0, bytes.size() - 1)), [], "a short roster")
	var long := bytes.duplicate()
	long.append(0)
	assert_eq(LobbyStateWire.unpack(long), [], "a long roster was read")
	assert_eq(LobbyStateWire.unpack(PackedByteArray()), [], "nothing at all was read")


func test_a_seat_that_cannot_be_a_slot_is_not_sent() -> void:
	var got := LobbyStateWire.unpack(LobbyStateWire.pack({0: Ids.PERSONA_LUCERNA, 300: &""}))
	assert_eq(got[0], {}, "slot 0 is nobody and 300 does not fit a byte")


## The payload is the row: two bytes a seat after a count, so six seats are 13.
func test_the_size_is_the_row() -> void:
	var six: Dictionary = {}
	for slot: int in range(1, 7):
		six[slot] = CrowdRoster.PLAYABLE[slot % CrowdRoster.PLAYABLE.size()]
	assert_eq(LobbyStateWire.pack(six).size(), 13, "a full lobby is not 13 bytes")
