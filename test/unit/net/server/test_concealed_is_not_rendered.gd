## **"NOT RENDERED AT ALL."** GDD-03 §4.1.4, US-0054's second criterion.
##
## A player inside a concealment prop leaves `present_slots` entirely, which is
## the one thing absence in this format still means: `RemotePawns` frees the body
## and the client stops drawing them.
##
## **OMITTING ONLY THE RECORD WOULD BE A WORSE LIE THAN NOT DRAWING THEM.** Delta
## encoding made absence mean *unchanged* (US-0031), so a concealed player left in
## the mask would be drawn, motionless, at the doorway of the prop they climbed
## into — which is exactly where a hunter would look.
extends GutTest

const MAP_DATA := "res://data/maps/map_vetraio.tres"
const WATCHER := 41
const HIDER := 42

var _ctx: MatchContext
var _host: PawnHost
var _builder: SnapshotBuilder


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.map = load(MAP_DATA) as MapData
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_host = PawnHost.new()
	add_child_autofree(_host)
	_host.setup(_ctx)
	_builder = SnapshotBuilder.new()
	add_child_autofree(_builder)
	_builder.setup(_ctx, _host, null)
	await get_tree().physics_frame
	_player_at(WATCHER, Vector3(20.0, 0.0, 20.0))
	_player_at(HIDER, Vector3(24.0, 0.0, 20.0))


func _player_at(peer: int, at: Vector3) -> void:
	_ctx.slots.assign(peer)
	_host.spawn(peer)
	_host.context_for(peer).position = at


func _slot_of(peer: int) -> int:
	return _ctx.slots.slot_of(peer)


func _sees(observer: int, subject: int) -> bool:
	var snapshot := _builder.build_for(observer)
	var slot := _slot_of(subject)
	return slot > 0 and (snapshot.present_slots & (1 << (slot - 1))) != 0


func test_a_player_standing_in_the_open_is_present() -> void:
	# **THE PREMISE.** The assertion below is satisfied by a builder that never
	# reports anybody, and this is what stops the file passing that way.
	assert_true(_sees(WATCHER, HIDER), "a player four metres away was not in the snapshot")


func test_a_concealed_player_leaves_the_mask_entirely() -> void:
	_host.context_for(HIDER).blend_state = BlendKind.Kind.PROP_CONCEAL
	assert_false(_sees(WATCHER, HIDER), "a player inside a hiding spot is still drawn")


func test_they_come_back_when_they_step_out() -> void:
	# Dropping out of the observer's record set also drops them from the delta's
	# baseline, so they are re-sent in full rather than withheld as already-held —
	# the same shape as the crowd's farewell (US-0045).
	_host.context_for(HIDER).blend_state = BlendKind.Kind.PROP_CONCEAL
	assert_false(_sees(WATCHER, HIDER))
	_host.context_for(HIDER).blend_state = BlendKind.Kind.NONE
	assert_true(_sees(WATCHER, HIDER), "the player never came back on screen")


func test_the_other_three_blends_stay_visible() -> void:
	# **BLEND IS ANONYMITY, NOT INVISIBILITY.** A player in a crowd pocket is
	# drawn exactly like everybody else — that is the whole mechanic, and hiding
	# them would replace *picking a person out of a crowd* with a rendering rule.
	for kind: int in [BlendKind.Kind.POCKET, BlendKind.Kind.GROUP, BlendKind.Kind.PROP_STATIC]:
		_host.context_for(HIDER).blend_state = kind
		assert_true(_sees(WATCHER, HIDER), "blend kind %d stopped being drawn" % kind)


func test_the_occupant_still_gets_their_own_snapshot() -> void:
	# Safe and blind is the price; safe and *disconnected* is a bug. The own block
	# is unaffected, and `blend_state` in it is how a widget will know to black the
	# screen out (US-0084).
	_host.context_for(HIDER).blend_state = BlendKind.Kind.PROP_CONCEAL
	var mine := _builder.build_for(HIDER)
	assert_eq(mine.own_position, _host.context_for(HIDER).position, "the occupant lost their pawn")
	assert_eq(mine.blend_state, BlendKind.Kind.PROP_CONCEAL, "the occupant is not told they hid")
