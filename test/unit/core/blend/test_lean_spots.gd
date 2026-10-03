## **ONE FIGURE PER COUNTER, PLAYER OR NPC.** US-0103, `LeanSpots`.
extends GutTest

var _spots: LeanSpots


func before_each() -> void:
	_spots = LeanSpots.new()


func test_a_spot_held_by_an_npc_is_refused_to_a_player() -> void:
	assert_true(_spots.take_for_npc(5, 0))
	assert_false(_spots.take_for_player(21, 0), "a player leaned where a civilian already leans")
	assert_eq(_spots.npc_at(0), 5)


func test_a_spot_held_by_a_player_is_never_taken_by_an_npc() -> void:
	assert_true(_spots.take_for_player(21, 0))
	assert_false(_spots.take_for_npc(5, 0), "a civilian leaned into a player's counter")


func test_releasing_frees_the_spot_for_either() -> void:
	_spots.take_for_npc(5, 0)
	_spots.release_npc(5)
	assert_true(_spots.is_vacant(0))
	assert_true(_spots.take_for_player(21, 0))
	_spots.release_player(21)
	assert_true(_spots.take_for_npc(6, 0))


func test_moving_to_another_spot_gives_up_the_first() -> void:
	_spots.take_for_npc(5, 0)
	_spots.take_for_npc(5, 1)
	assert_true(_spots.is_vacant(0), "a civilian held two counters at once")
	_spots.take_for_player(21, 2)
	_spots.take_for_player(21, 3)
	assert_true(_spots.is_vacant(2), "a player held two counters at once")


func test_a_vacant_spot_is_drawn_only_from_the_vacant_ones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for spot: int in 4:
		if spot != 2:
			_spots.take_for_npc(10 + spot, spot)
	for _i: int in 20:
		assert_eq(_spots.a_vacant_spot(rng, 4), 2, "a held counter was offered")
	_spots.take_for_npc(99, 2)
	assert_eq(_spots.a_vacant_spot(rng, 4), LeanSpots.VACANT, "a full market offered a counter")
