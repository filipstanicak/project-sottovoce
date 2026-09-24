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


## **THROUGH THE PATH A REAL DISCONNECT TAKES, NOT THROUGH `GameState.clear()`.**
## This test called `clear()` directly until review of #232 — and `clear()` had no
## caller under `scripts/` at all, so the test proved a function nobody ran. The
## signal below is the one ENet raises; `Net` answers it with `stop()`.
func test_a_lost_server_undresses_everybody() -> void:
	GameState.adopt_personas(_roster())
	GameState.adopt_match(SEED, 0, CROWD)
	assert_true(Wardrobe.can_dress(), "the fixture never dressed anybody, so nothing was proven")
	Net.multiplayer.server_disconnected.emit()
	assert_false(Wardrobe.can_dress(), "a lost server left both halves of the gate standing")
	_assert_nobody_dressed("after the server that dressed them was lost")


## **THE INTERLEAVING THE REVIEW NAMED.** With the last match's seed surviving, the
## next lobby's roster — every seat undealt, and not empty — reopens the gate: the
## crowd is dressed from the old seed and every player stands undressed among it.
func test_the_next_lobby_is_not_dressed_from_the_last_match() -> void:
	GameState.adopt_personas(_roster())
	GameState.adopt_match(SEED, 0, CROWD)
	Net.multiplayer.server_disconnected.emit()
	GameState.replace(OWN_SLOT, GameState.Phase.LOBBY, {})
	GameState.adopt_personas({OWN_SLOT: &"", OTHER_SLOT: &""})
	_assert_nobody_dressed("in a new lobby, from the seed of the match before it")


func test_a_failed_connection_clears_the_gate_too() -> void:
	GameState.adopt_personas(_roster())
	GameState.adopt_match(SEED, 0, CROWD)
	Net.multiplayer.connection_failed.emit()
	assert_push_error_count(1, "a failed connection is logged loudly, and that is not the defect")
	assert_false(Wardrobe.can_dress(), "a failed connection left the gate open")


## **ONE PALETTE COLOURS THE PORTRAIT AND THE DISTRICT, WHATEVER IT SAYS.** Review
## of #235: the first version let the portrait read a palette while the bodies read
## the resource, so a colourblind palette would have moved one and not the other —
## the very disagreement #235 fixes, returning under every palette but the default.
## An override no persona resource holds is the proof: both must draw exactly it.
func test_the_portrait_and_the_figures_follow_one_palette() -> void:
	var odd := Palette.new()
	odd.persona_hues[Ids.PERSONA_CANTATRICE] = Color(0.1, 0.9, 0.2)
	_wardrobe.palette = odd
	GameState.adopt_personas(_roster())
	GameState.adopt_match(SEED, 0, CROWD)
	var portrait := PortraitWidget.new()
	portrait.palette = odd
	add_child_autofree(portrait)
	EventBus.contract_assigned.emit(0, Ids.PERSONA_CANTATRICE)
	var body := _remote_body()
	assert_eq(body.persona, Ids.PERSONA_CANTATRICE, "the fixture did not dress a Cantatrice")
	var worn := (body.get_node("Body") as MeshInstance3D).mesh.material as StandardMaterial3D
	assert_eq(worn.albedo_color, Color(0.1, 0.9, 0.2), "the figure ignored the palette")
	assert_eq(portrait.bust_colour(), Color(0.1, 0.9, 0.2), "the portrait ignored the palette")


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
