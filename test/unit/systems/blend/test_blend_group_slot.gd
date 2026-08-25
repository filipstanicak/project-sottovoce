## **THE FIFTH SLOT US-0043 RESERVED, CLAIMED AT LAST.** US-0053, GDD-03 §4.1.2.
##
## Every walking group carries `TUN-CROWD-GROUP-SIZE` NPCs and one more slot that
## no NPC may take. It has been empty since M3, and `CrowdFormations.joinable_group`
## has carried the comment *"what `SYS-BLEND` will call"* the whole time.
##
## **THE GROUP BLEND IS THE ONLY WAY TO TRAVEL WHILE GAINING ANONYMITY RATHER THAN
## SPENDING IT.** Everything else in the game charges for movement. This one pays —
## at 1.4 m/s, on a route the player did not choose, and that trade of mobility for
## agency is what stops it being dominant.
##
## The map's real circuits are used rather than an invented one: the tolerance is
## 0.8 m against slots that genuinely walk, and a straight-line stand-in would
## never test the case the tolerance exists for.
extends GutTest

const PEER := 2
const RIVAL := 8

var _blend: BlendSystem
var _ctx: MatchContext
var _pawn: PawnContext
var _t: SuspicionTuning


func before_each() -> void:
	_t = Tuning.suspicion
	_blend = BlendSystem.new()
	_ctx = MatchContext.new()
	_ctx.map = load("res://data/maps/map_vetraio.tres") as MapData
	_ctx.crowd_hash.setup(AABB(Vector3(-20, -20, -20), Vector3(160, 40, 160)), 32)
	_ctx.formations = CrowdFormations.new()
	_ctx.formations.setup(_ctx.map)
	_pawn = _spawn(PEER)
	# **NO POCKET ANYWHERE**, so nothing below can pass by accidentally taking the
	# other crowd-dependent blend — `request()` prefers the group and falls through.
	_ctx.crowd_hash.rebuild(PackedVector3Array(), [], 0)


func _spawn(peer: int) -> PawnContext:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(Vector3.ZERO, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn
	return pawn


func _resolve(times: int) -> void:
	for _i: int in times:
		_ctx.tick += 1
		_blend.resolve(_ctx)


## Stand `pawn` in the first group's joinable slot.
func _stand_in_the_slot(pawn: PawnContext) -> Vector3:
	var group := _ctx.formations.groups[0]
	var at := group.slot_position(group.joinable_slot())
	pawn.position = at
	return at


func test_the_map_actually_declares_circuits() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** `CrowdFormations.setup()` invents nothing: a
	# map with no circuits yields no groups, and every assertion below would then be
	# testing the refusal path while claiming to test the blend.
	assert_gt(_ctx.formations.groups.size(), 0, "MAP-VETRAIO declares no circuits")
	var group := _ctx.formations.groups[0]
	assert_gt(group.slot_count(), int(Tuning.crowd.group_size), "no slot is reserved for a player")


func test_standing_in_the_slot_claims_it_and_standing_away_does_not() -> void:
	_pawn.position = Vector3(500.0, 0.0, 500.0)
	assert_eq(_blend.request(PEER, _ctx), BlendKind.Kind.NONE, "a group was joined from 500 m away")
	_stand_in_the_slot(_pawn)
	assert_eq(
		_blend.request(PEER, _ctx), BlendKind.Kind.GROUP, "the reserved slot refused a player"
	)
	assert_eq(_ctx.formations.group_of_peer(PEER), 0, "the claim never reached the formation")


func test_a_claimed_slot_cannot_be_stolen() -> void:
	# A blend that could be taken from you by another player is a blend nobody can
	# rely on — and unlike the crowd breaking it, there would be nothing to read.
	_stand_in_the_slot(_pawn)
	assert_eq(_blend.request(PEER, _ctx), BlendKind.Kind.GROUP)
	var rival := _spawn(RIVAL)
	_stand_in_the_slot(rival)
	assert_eq(_blend.request(RIVAL, _ctx), BlendKind.Kind.NONE, "a second player took a held slot")
	assert_eq(_ctx.formations.group_of_peer(PEER), 0, "the original holder was evicted")


func test_drifting_beyond_the_tolerance_breaks_it() -> void:
	_stand_in_the_slot(_pawn)
	_blend.request(PEER, _ctx)
	_resolve(maxi(Tuning.ticks(&"TUN-BLEND-ENTRY-TIME"), 1))
	assert_true(_blend.is_crushing(PEER), "the group blend never reached HELD")
	_pawn.position += Vector3(_t.blend_group_slot_tolerance + 0.5, 0.0, 0.0)
	_resolve(1)
	assert_false(_blend.is_crushing(PEER), "a player 1.3 m from their slot stayed blended")
	assert_eq(_ctx.formations.group_of_peer(PEER), -1, "a broken blend kept the slot claimed")


func test_staying_inside_the_tolerance_does_not() -> void:
	# The counterfactual: an implementation that broke the blend on any movement
	# would satisfy the test above.
	_stand_in_the_slot(_pawn)
	_blend.request(PEER, _ctx)
	_resolve(maxi(Tuning.ticks(&"TUN-BLEND-ENTRY-TIME"), 1))
	_pawn.position += Vector3(_t.blend_group_slot_tolerance * 0.5, 0.0, 0.0)
	_resolve(10)
	assert_true(_blend.is_crushing(PEER), "a player inside the tolerance lost the blend")


func test_the_blend_never_moves_the_pawn() -> void:
	# **THE SLOT WALKS AND THE PLAYER KEEPS UP.** Driving a blended pawn toward its
	# slot would put the server in charge of a position the client predicts, and
	# every tick of the blend would be a reconciliation. It would also take the
	# agency GDD-03 §4.1.2 trades for mobility without charging for it.
	var at := _stand_in_the_slot(_pawn)
	_blend.request(PEER, _ctx)
	_resolve(20)
	assert_eq(_pawn.position, at, "SYS-BLEND moved the pawn")
	assert_eq(_pawn.velocity, Vector3.ZERO, "SYS-BLEND wrote a velocity")


func test_a_departed_peer_releases_its_slot() -> void:
	# **ENET REUSES PEER IDS** — US-0037. `CrowdFormations.claim()` refuses a taken
	# slot rather than evicting, so a slot left held is one nobody can ever join
	# again for the rest of the match.
	_stand_in_the_slot(_pawn)
	assert_eq(_blend.request(PEER, _ctx), BlendKind.Kind.GROUP)
	_ctx.pawn_contexts.erase(PEER)
	_resolve(1)
	assert_eq(_ctx.formations.group_of_peer(PEER), -1, "a departed peer kept its formation slot")
	var rejoiner := _spawn(PEER)
	_stand_in_the_slot(rejoiner)
	assert_eq(
		_blend.request(PEER, _ctx), BlendKind.Kind.GROUP, "the slot was unjoinable afterwards"
	)


func test_leaving_deliberately_releases_the_slot_too() -> void:
	_stand_in_the_slot(_pawn)
	_blend.request(PEER, _ctx)
	_resolve(maxi(Tuning.ticks(&"TUN-BLEND-ENTRY-TIME"), 1))
	_blend.request(PEER, _ctx)
	_resolve(maxi(Tuning.ticks(&"TUN-BLEND-EXIT-TIME"), 1))
	assert_eq(_ctx.formations.group_of_peer(PEER), -1, "a player who left kept the slot")
