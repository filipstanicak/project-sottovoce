## **NOBODY IS DRESSED UNTIL EVERYBODY CAN BE.** US-0101.
##
## The seed arrives at `ACTIVE` and the roster at the countdown. Between them, a
## client that dressed whatever it could would draw coloured players among a grey
## crowd, or a coloured crowd around grey players — every player named at once, on
## a screen that looks like a game still loading its colours. These tests hold the
## gate from both sides, and the pass that follows it.
extends GutTest

const SEED := 90210
const CROWD := 78
const DRAWN := 24
const OWN_SLOT := 1
const OTHER_SLOT := 2

var _npcs: NpcView
var _remotes: RemotePawns
var _local: PersonaBody
var _wardrobe: Wardrobe


func before_each() -> void:
	GameState.clear()
	GameState.replace(OWN_SLOT, GameState.Phase.ACTIVE, {})
	_npcs = NpcView.new()
	add_child_autofree(_npcs)
	_remotes = RemotePawns.new()
	add_child_autofree(_remotes)
	_remotes.set_own_slot(OWN_SLOT)
	_local = PersonaBody.new()
	add_child_autofree(_local)
	_wardrobe = Wardrobe.new()
	add_child_autofree(_wardrobe)
	_wardrobe.bind(_npcs, _remotes, _local)
	var snap := Snapshot.new()
	snap.server_tick = 1
	for index: int in DRAWN:
		snap.add_npc(index, Vector3(4.0, 0.0, float(index)), 0.0, 1, 0)
	snap.add_remote(OTHER_SLOT, Vector3(2.0, 0.0, 0.0), 0.0, &"Idle", 0, 0)
	_npcs.apply_snapshot(snap)
	_remotes.apply_snapshot(snap)


func after_each() -> void:
	GameState.clear()


func _roster() -> Dictionary:
	return {OWN_SLOT: Ids.PERSONA_LUCERNA, OTHER_SLOT: Ids.PERSONA_CANTATRICE}


func _remote_body() -> PersonaBody:
	return _remotes.pawn_of(OTHER_SLOT).get_node("PersonaVisuals") as PersonaBody


func _dressed_npcs() -> int:
	var dressed := 0
	for index: int in _npcs.indices():
		if _npcs.body_of(index).is_dressed():
			dressed += 1
	return dressed


func _assert_nobody_dressed(why: String) -> void:
	assert_eq(_npcs.count(), DRAWN, "the fixture drew no crowd, so nothing was proven")
	assert_eq(_dressed_npcs(), 0, "a clone was dressed %s" % why)
	assert_false(_remote_body().is_dressed(), "another player was dressed %s" % why)
	assert_false(_local.is_dressed(), "this player was dressed %s" % why)


func test_the_seed_alone_dresses_nobody() -> void:
	GameState.adopt_match(SEED, 0, CROWD)
	_assert_nobody_dressed("with the seed and no roster: every grey figure is a player")


func test_the_roster_alone_dresses_nobody() -> void:
	GameState.adopt_personas(_roster())
	_assert_nobody_dressed("with the roster and no seed: every coloured figure is a player")


func test_both_halves_dress_everybody_at_once() -> void:
	GameState.adopt_personas(_roster())
	GameState.adopt_match(SEED, 0, CROWD)
	var crowd := Wardrobe.crowd_personas(SEED, CROWD)
	assert_gt(_dressed_npcs(), 0, "no clone was dressed, so the crowd check is vacuous")
	for index: int in _npcs.indices():
		assert_eq(
			_npcs.body_of(index).persona, crowd[index], "NPC %d wears the wrong persona" % index
		)
	assert_eq(_remote_body().persona, Ids.PERSONA_CANTATRICE, "the other player is misdressed")
	assert_eq(_local.persona, Ids.PERSONA_LUCERNA, "this player is not wearing their own deal")


## Filler archetypes are nobody a player can be, so they stay undressed — and the
## crowd has some, or a district of nothing but clones would be its own tell.
func test_filler_stays_undressed() -> void:
	var crowd := Wardrobe.crowd_personas(SEED, CROWD)
	assert_true(crowd.has(&""), "the derived crowd has no filler at all")
	for persona: StringName in CrowdRoster.PLAYABLE:
		assert_true(crowd.has(persona), "%s has no clones in the derived crowd" % persona)


func test_a_body_that_arrives_later_is_dressed_on_arrival() -> void:
	GameState.adopt_personas(_roster())
	GameState.adopt_match(SEED, 0, CROWD)
	var snap := Snapshot.new()
	snap.server_tick = 2
	var late := CROWD - 1
	snap.add_npc(late, Vector3(5.0, 0.0, 0.0), 0.0, 1, 0)
	_npcs.apply_snapshot(snap)
	assert_eq(
		_npcs.body_of(late).persona,
		Wardrobe.crowd_personas(SEED, CROWD)[late],
		"an NPC admitted after the dressing wears nothing, or the wrong thing"
	)


func test_a_lost_session_undresses_everybody() -> void:
	GameState.adopt_personas(_roster())
	GameState.adopt_match(SEED, 0, CROWD)
	GameState.clear()
	GameState.replace(OWN_SLOT, GameState.Phase.LOBBY, {})
	_assert_nobody_dressed("after the session that dressed them was cleared")


## **THE CLIENT DERIVES THE CROWD WITH THE SERVER'S OWN ARGUMENTS.** The server
## stands its pool up over `CrowdRoster.PLAYABLE` and `TUN-LOBBY-MAX-PLAYERS`, not
## over the dealt set; a wardrobe that used the dealt personas would dress a
## different district from the one the server placed, with nothing looking wrong.
func test_the_crowd_is_the_one_the_server_stood_up() -> void:
	var seats: int = Tuning.match_rules.max_players
	var server := CrowdRoster.derive(CROWD, SEED, CrowdRoster.PLAYABLE, seats)
	var client := Wardrobe.crowd_personas(SEED, CROWD)
	for index: int in CROWD:
		var expected: StringName = server[index] if CrowdRoster.PLAYABLE.has(server[index]) else &""
		assert_eq(client[index], expected, "index %d is dressed differently" % index)
	var root := FileAccess.get_file_as_string("res://scripts/server/server_root.gd")
	assert_true(
		root.contains("var players: int = Tuning.match_rules.max_players"),
		"the server no longer stands the crowd up for a full lobby; re-check the wardrobe"
	)
	assert_true(
		root.contains("director.ctx.match_seed, CrowdRoster.PLAYABLE, players)"),
		"the server no longer stands the crowd up over every persona; re-check the wardrobe"
	)
