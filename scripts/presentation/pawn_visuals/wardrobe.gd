## **WHO WEARS WHAT ON THIS CLIENT — AND NOBODY UNTIL EVERYBODY.** US-0101.
## CLIENT ONLY.
##
## Every figure in the district is a `PersonaBody`, and this is the one place that
## decides what each one wears: the crowd from `CrowdRoster.derive` over the seed
## `NET-S2C-MATCH-START` carries, the players from `NET-S2C-LOBBY-STATE`, the local
## pawn from the same roster by its own slot.
##
## **THE GATE IS THE WHOLE CORRECTNESS.** The two halves arrive in two messages at
## two moments — the roster at the countdown, the seed at `ACTIVE`. Dress the crowd
## first and every grey figure left is a player; dress the players first and every
## coloured one is. Either is the entire anonymity model gone for the length of the
## gap, looking exactly like a game that is still loading its colours. So nobody is
## dressed until both are held, and then everybody is, in one pass.
##
## **THE CROWD IS DERIVED WITH THE SERVER'S OWN ARGUMENTS** — `CrowdRoster.PLAYABLE`
## as the personas in use and `TUN-LOBBY-MAX-PLAYERS` as the seats — because
## `server_root._stand_the_crowd_up` stands the pool up with exactly those. The dealt
## personas narrow only the 2 s clone pass (US-0100), never the roster, so a client
## that derived from the dealt set would dress a different district.
class_name Wardrobe
extends Node

## The palette every body is dressed from — the HUD's, set by the client root, so
## the portrait and the district cannot disagree about a colour under any palette.
var palette: Palette = null

var _npcs: NpcView
var _remotes: RemotePawns
var _local: PersonaBody

## Persona or `&""` per NPC index, for the seed and count it was derived from.
var _crowd: Array = []
## **Two ints, not a `Vector2i`**: that is 32-bit, and a seed is 64 — two seeds
## differing only in the top half would have kept the last match's crowd.
var _derived_seed: int = 0
var _derived_count: int = -1
var _dressing := false


## Wire the three things that draw figures. Any of them may be null, which is what
## a probe or a unit fixture with part of the client looks like.
func bind(npcs: NpcView, remotes: RemotePawns, local: PersonaBody) -> void:
	_npcs = npcs
	_remotes = remotes
	_local = local
	if npcs != null:
		npcs.npc_appeared.connect(_on_npc_appeared)
	if remotes != null:
		remotes.remote_appeared.connect(_on_remote_appeared)
	GameState.state_replaced.connect(refresh)
	refresh()


## Both halves held? **The seed flag and a non-empty roster**, never the seed's
## value — zero is a legal seed.
static func can_dress() -> bool:
	return GameState.has_match() and not GameState.personas.is_empty()


## The crowd a seed produces: a persona for each clone and `&""` for each filler
## archetype, which nobody can be and which therefore stays undressed.
static func crowd_personas(match_seed: int, count: int) -> Array:
	var seats: int = Tuning.match_rules.max_players
	var roster := CrowdRoster.derive(count, match_seed, CrowdRoster.PLAYABLE, seats)
	return roster.map(
		func(id: StringName) -> StringName: return id if CrowdRoster.PLAYABLE.has(id) else &""
	)


func is_dressing() -> bool:
	return _dressing


func npc_persona(index: int) -> StringName:
	if not _dressing or index < 0 or index >= _crowd.size():
		return &""
	return _crowd[index]


func player_persona(slot: int) -> StringName:
	return GameState.personas.get(slot, &"") if _dressing else &""


## Re-read both halves and re-dress every figure. Cheap when nothing changed:
## `PersonaBody.dress` rebuilds only a body whose persona moved.
func refresh() -> void:
	_dressing = can_dress()
	var fresh := GameState.match_seed != _derived_seed or GameState.crowd_count != _derived_count
	if _dressing and fresh:
		_crowd = crowd_personas(GameState.match_seed, GameState.crowd_count)
		_derived_seed = GameState.match_seed
		_derived_count = GameState.crowd_count
	if _npcs != null:
		for index: int in _npcs.indices():
			_on_npc_appeared(index)
	if _remotes != null:
		for slot: int in _remotes.slots():
			_on_remote_appeared(slot)
	if _local != null:
		_local.palette = palette
		_local.dress(player_persona(GameState.local_peer_id))


func _on_npc_appeared(index: int) -> void:
	var body := _npcs.body_of(index)
	if body != null:
		body.palette = palette
		body.dress(npc_persona(index))


func _on_remote_appeared(slot: int) -> void:
	var pawn := _remotes.pawn_of(slot)
	var body := null if pawn == null else pawn.get_node_or_null("PersonaVisuals") as PersonaBody
	if body != null:
		body.palette = palette
		body.dress(player_persona(slot))
