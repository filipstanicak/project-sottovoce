## **EVERY CLIENT IS TOLD WHAT EVERY SEAT WEARS, WHENEVER THAT CHANGES.** US-0101.
##
## `NET-S2C-LOBBY-STATE` is what lets a client dress the players beside the crowd.
## A roster that missed a change leaves one figure in the wrong colour — or grey in
## a coloured district, which names them to everybody.
extends GutTest

const SEED := 440022
const PLAYERS := [61, 62, 63, 64]

var _ctx: MatchContext
var _consequences: MatchConsequences
var _announcer: MatchAnnouncer


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	_ctx.phase = MatchPhase.Phase.WARMUP
	for peer: int in PLAYERS:
		_join(peer)
	_announcer = MatchAnnouncer.new(_ctx)
	_consequences = MatchConsequences.new(_ctx)
	_consequences.announcer = _announcer


func _join(peer: int) -> void:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	_ctx.pawn_contexts[peer] = pawn
	_ctx.slots.assign(peer)


func test_the_countdown_tells_everybody_what_was_dealt() -> void:
	_consequences.countdown_opened(PackedInt32Array(PLAYERS), _ctx)
	assert_eq(_announcer.lobby_states_sent, 1, "the deal was never announced")
	var roster := _announcer.personas_by_slot()
	assert_eq(roster.size(), PLAYERS.size(), "a seat is missing from the roster")
	for peer: int in PLAYERS:
		var persona: StringName = roster[_ctx.slots.slot_of(peer)]
		assert_true(CrowdRoster.PLAYABLE.has(persona), "peer %d's seat is undealt" % peer)
		assert_eq(persona, _ctx.pawn_contexts[peer].persona, "seat and pawn disagree")


func test_a_late_join_is_announced_with_its_deal() -> void:
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_join(65)
	_consequences.peer_joined(65)
	assert_eq(_announcer.lobby_states_sent, 1, "a late joiner's persona reached nobody")
	var persona: StringName = _announcer.personas_by_slot()[_ctx.slots.slot_of(65)]
	assert_true(CrowdRoster.PLAYABLE.has(persona), "the late joiner was announced undealt")


## A lobby join is told too, as an undealt seat — which is true, and which a client
## draws undressed like everybody else in a lobby.
func test_a_lobby_join_is_announced_undealt() -> void:
	_ctx.phase = MatchPhase.Phase.LOBBY
	_join(66)
	_consequences.peer_joined(66)
	assert_eq(_announcer.lobby_states_sent, 1, "a lobby join was not announced")
	assert_eq(_announcer.personas_by_slot()[_ctx.slots.slot_of(66)], &"", "dealt in a lobby")


## **A DEPARTED SEAT LEAVES THE ROSTER.** Left in, a client would keep the seat's
## colour on file for a figure that no longer exists — harmless today, and the
## first thing to go wrong the day a slot is reused mid-match.
func test_a_departure_is_announced_without_the_seat() -> void:
	_consequences.countdown_opened(PackedInt32Array(PLAYERS), _ctx)
	var gone: int = PLAYERS[1]
	var slot := _ctx.slots.slot_of(gone)
	_ctx.pawn_contexts.erase(gone)
	_consequences.peer_left(_ctx)
	assert_eq(_announcer.lobby_states_sent, 2, "a departure was not announced")
	assert_false(_announcer.personas_by_slot().has(slot), "the departed seat is still drawn")


## The roster round-trips as the client will read it.
func test_the_roster_is_what_the_wire_carries() -> void:
	_consequences.countdown_opened(PackedInt32Array(PLAYERS), _ctx)
	var sent := _announcer.personas_by_slot()
	var got := LobbyStateWire.unpack(LobbyStateWire.pack(sent))
	assert_eq(got, [sent], "the client would read a different roster from the one sent")
