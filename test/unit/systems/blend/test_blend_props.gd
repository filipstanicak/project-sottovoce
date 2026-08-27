## **THE TWO PROP BLENDS, END TO END.** US-0054, GDD-03 §4.1.3 and §4.1.4.
##
## The pure occupancy rule is exercised in `test/unit/core/blend/`. What is here
## is the system: that a lean spot needs no crowd and breaks on any movement, that
## a hiding spot is claimed and released, that the refusal reaches a signal rather
## than vanishing, and that **the most specific thing you are standing at wins**.
extends GutTest

const FIRST := 21
const SECOND := 22

var _blend: BlendSystem
var _ctx: MatchContext
var _refused: Array = []


func before_each() -> void:
	_refused = []
	_blend = BlendSystem.new()
	_ctx = MatchContext.new()
	_ctx.tick = 100
	_ctx.crowd_hash.setup(AABB(Vector3(-40, -20, -40), Vector3(160, 40, 160)), 32)
	_ctx.map = _a_map()
	_blend.blend_refused.connect(func(p: int, w: int) -> void: _refused.append([p, w]))


## One hiding spot at the origin and one lean spot 50 m away, so a fixture can
## stand a player at exactly one of them.
func _a_map() -> MapData:
	var map := MapData.new()
	var conceal: Array[Vector3] = [Vector3.ZERO]
	var lean: Array[Vector3] = [Vector3(50.0, 0.0, 0.0)]
	map.blend_props = conceal
	map.static_props = lean
	return map


func _place(peer: int, at: Vector3) -> PawnContext:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn
	return pawn


## An empty district: no NPCs anywhere, so nothing here can be mistaken for a
## crowd pocket. **That is the point of the static prop** — GDD-03 §4.1.3:
## *"blending must be available where the crowd is not"*.
func _no_crowd() -> void:
	_ctx.crowd_hash.rebuild(PackedVector3Array(), [], 0)


func _resolve(times: int = 1) -> void:
	for _i: int in times:
		_ctx.tick += 1
		_blend.resolve(_ctx)


func _held(peer: int) -> int:
	return _blend.record_for(peer).wire_kind()


func _settle(peer: int) -> void:
	_resolve(maxi(Tuning.ticks(&"TUN-BLEND-ENTRY-TIME"), 1) + 1)
	assert_eq(
		_blend.record_for(peer).phase,
		BlendRecord.Phase.HELD,
		"the blend never reached HELD; every assertion after this is about nothing"
	)


# ----------------------------------------------------- the static prop ----


func test_a_lean_spot_needs_no_crowd_at_all() -> void:
	# **THE PREMISE, AND THE WHOLE REASON THIS BLEND EXISTS.** GDD-03 §4.1.3:
	# blending must be available where the crowd is not, or the map's quiet corners
	# become unusable and the playable area shrinks.
	_no_crowd()
	_place(FIRST, Vector3(50.0, 0.0, 0.0))
	assert_eq(
		_blend.request(FIRST, _ctx),
		BlendKind.Kind.PROP_STATIC,
		"a lean spot in an empty street was refused"
	)
	_settle(FIRST)
	assert_eq(_held(FIRST), BlendKind.Kind.PROP_STATIC)


func test_any_movement_breaks_a_lean() -> void:
	# **STRICTER THAN `TUN-BLEND-BREAK-ON-SPEED`**, which is what every other blend
	# uses: you may drift inside a crowd pocket and you may not shift on a bench.
	_no_crowd()
	var pawn := _place(FIRST, Vector3(50.0, 0.0, 0.0))
	_blend.request(FIRST, _ctx)
	_settle(FIRST)
	pawn.velocity = Vector3(Tuning.suspicion.stillness_speed_ceiling + 0.05, 0.0, 0.0)
	_resolve()
	assert_eq(_held(FIRST), BlendKind.Kind.NONE, "a lean survived the player moving")


func test_a_lean_survives_standing_perfectly_still() -> void:
	# The counterfactual for the test above. A break rule that fired on a grounded
	# body's floor-snap velocity would make the bench unusable, and the symptom
	# would read as "the blend does not work" rather than as an axis mistake — the
	# defect `PASV-STILLNESS` was nearly born with (US-0052).
	_no_crowd()
	var pawn := _place(FIRST, Vector3(50.0, 0.0, 0.0))
	pawn.velocity = Vector3(0.0, -0.08, 0.0)
	_blend.request(FIRST, _ctx)
	_settle(FIRST)
	_resolve(20)
	assert_eq(_held(FIRST), BlendKind.Kind.PROP_STATIC, "a motionless player fell off the bench")


# ------------------------------------------------- the concealment prop ---


func test_the_first_player_takes_the_hiding_spot() -> void:
	_no_crowd()
	_place(FIRST, Vector3.ZERO)
	assert_eq(_blend.request(FIRST, _ctx), BlendKind.Kind.PROP_CONCEAL)
	assert_eq(_blend.props.holder_of(0), FIRST, "occupancy is not server-owned state")


func test_a_second_player_is_refused_with_a_reason_rather_than_silence() -> void:
	# US-0054's third criterion, at the system level: the refusal reaches a signal.
	_no_crowd()
	_place(FIRST, Vector3.ZERO)
	_place(SECOND, Vector3(0.5, 0.0, 0.0))
	_blend.request(FIRST, _ctx)
	assert_eq(_blend.request(SECOND, _ctx), BlendKind.Kind.NONE, "two players in one prop")
	assert_eq(_refused.size(), 1, "the second player got silence")
	assert_eq(int(_refused[0][1]), BlendRefusal.Why.PROP_OCCUPIED, "the wrong reason")


func test_a_press_at_nothing_is_also_answered() -> void:
	# **THE COMMONEST PRESS IN THE GAME** — a player mashing blend while crossing a
	# street. Answering it with silence is what teaches them the button is
	# unreliable, which is the same lesson the occupied prop teaches.
	_no_crowd()
	_place(FIRST, Vector3(500.0, 0.0, 500.0))
	assert_eq(_blend.request(FIRST, _ctx), BlendKind.Kind.NONE)
	assert_eq(_refused.size(), 1, "an empty press produced no feedback")
	assert_eq(int(_refused[0][1]), BlendRefusal.Why.NOTHING_HERE)


func test_leaving_frees_the_prop_and_locks_the_leaver_out() -> void:
	_no_crowd()
	_place(FIRST, Vector3.ZERO)
	_blend.request(FIRST, _ctx)
	_settle(FIRST)
	_blend.request(FIRST, _ctx)
	_resolve(maxi(Tuning.ticks(&"TUN-BLEND-EXIT-TIME"), 1) + 1)
	assert_eq(_held(FIRST), BlendKind.Kind.NONE, "the player never got out")
	assert_eq(_blend.props.occupied_count(), 0, "the prop is still held")
	assert_eq(
		_blend.props.may_enter(FIRST, 0, _ctx.tick),
		BlendRefusal.Why.PROP_TOO_SOON,
		"door-flickering is still available"
	)


func test_a_departing_peer_does_not_take_the_hiding_spot_with_them() -> void:
	_no_crowd()
	_place(FIRST, Vector3.ZERO)
	_blend.request(FIRST, _ctx)
	_ctx.pawn_contexts.erase(FIRST)
	_blend.forget(FIRST, _ctx)
	assert_eq(_blend.props.occupied_count(), 0, "a hiding spot vanished from the map")


# ------------------------------------------------------- the ordering ----


func test_the_most_specific_thing_you_are_standing_at_wins() -> void:
	# **A HAY CART IN A MARKET IS INSIDE A CROWD POCKET AND BESIDE A COUNTER AT
	# ONCE.** GDD-03 §4.1 gives no ordering and one is needed: a press at a
	# concealment prop that silently took the pocket instead would spend a walk the
	# player made deliberately, and they would not find out until a hunter looked.
	var crowd := PackedVector3Array()
	for i: int in int(Tuning.suspicion.blend_pocket_min_npc) + 2:
		crowd.append(Vector3(cos(float(i)), 0.0, sin(float(i))))
	_ctx.crowd_hash.rebuild(crowd, [], crowd.size())
	_place(FIRST, Vector3.ZERO)
	assert_eq(
		_blend.request(FIRST, _ctx),
		BlendKind.Kind.PROP_CONCEAL,
		"the pocket beat the hiding spot the player walked to"
	)


func test_a_pocket_still_wins_where_there_is_no_prop() -> void:
	# The counterfactual: the ordering must not have deleted the pocket.
	var crowd := PackedVector3Array()
	for i: int in int(Tuning.suspicion.blend_pocket_min_npc) + 2:
		crowd.append(Vector3(300.0 + cos(float(i)), 0.0, 300.0 + sin(float(i))))
	_ctx.crowd_hash.rebuild(crowd, [], crowd.size())
	_place(FIRST, Vector3(300.0, 0.0, 300.0))
	assert_eq(_blend.request(FIRST, _ctx), BlendKind.Kind.POCKET, "the pocket stopped working")
