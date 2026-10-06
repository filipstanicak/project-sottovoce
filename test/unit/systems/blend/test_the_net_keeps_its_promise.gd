## **WHEREVER A STANDING NET IS DRAWN, THE SERVER GRANTS THE POCKET.** US-0107,
## review of #252.
##
## The second version drew a net under every knot of standing civilians, and round
## one granted pocket — four civilians, one in the middle and three 3.4 m out — it
## drew four nets, three of them where `BlendSystem.request` refused. A net is a
## promise. So this takes the server's own tags through the client's net
## calculation and stands a player at the centre and round the rim of every net it
## draws, asking the real blend entry point each time.
extends GutTest

const PEER := 6
const IDLE := NpcBrain.State.IDLE
const RIM_POINTS := 12


## The server's tags for these standing civilians, through the client's nets.
func _nets(points: Array) -> Array:
	var states := PackedInt32Array()
	var holds := PackedInt32Array()
	var drawn: Dictionary = {}
	for index: int in points.size():
		states.append(IDLE)
		holds.append(LeanSpots.VACANT)
		drawn[index] = points[index]
	var tags := CrowdGroups.tag_all(states, [], holds, points.size())
	return BlendCueRules.group_nets(tags, drawn)


## What the real entry point answers for a player standing at `at` among `points`.
func _blend_at(at: Vector3, points: Array) -> int:
	var ctx := MatchContext.new()
	ctx.crowd_hash.setup(AABB(Vector3(0, -20, 0), Vector3(120, 40, 120)), 32)
	ctx.crowd_hash.rebuild(PackedVector3Array(points), [], points.size())
	var pawn := PawnContext.new()
	pawn.peer_id = PEER
	pawn.reset_for_spawn(at, 0.0)
	pawn.state_id = PawnStateId.IDLE
	ctx.pawn_contexts[PEER] = pawn
	return BlendSystem.new().request(PEER, ctx)


## Every net drawn, asked at its centre and just inside its rim.
func _assert_every_net_is_kept(points: Array, nets: Array) -> void:
	for net: Array in nets:
		var centre: Vector3 = net[0]
		var reach := float(net[1]) * 0.98
		var spots: Array = [centre]
		for i: int in RIM_POINTS:
			var turn := TAU * i / RIM_POINTS
			spots.append(centre + Vector3(cos(turn), 0.0, sin(turn)) * reach)
		for at: Vector3 in spots:
			assert_eq(
				_blend_at(at, points),
				BlendKind.Kind.POCKET,
				"a net promised a pocket at %s that the server refused" % at
			)


func test_the_review_case_draws_no_net_where_the_server_refuses() -> void:
	var points := [
		Vector3(50, 0, 50), Vector3(53.4, 0, 50), Vector3(46.6, 0, 50), Vector3(50, 0, 53.4)
	]
	assert_eq(_blend_at(points[0], points), BlendKind.Kind.POCKET, "PREMISE: granted at the centre")
	assert_eq(_blend_at(points[1], points), BlendKind.Kind.NONE, "PREMISE: refused at the rim")
	var nets := _nets(points)
	assert_lte(nets.size(), 1, "a net for each member, three of them false")
	_assert_every_net_is_kept(points, nets)


func test_a_full_conversation_circle_has_a_net_and_it_holds_everywhere() -> void:
	var points: Array = []
	for i: int in 4:
		var turn := TAU * i / 4.0
		points.append(Vector3(60, 0, 60) + Vector3(cos(turn), 0.0, sin(turn)) * 0.9)
	var nets := _nets(points)
	assert_eq(nets.size(), 1, "a full circle is the pocket the net exists to show")
	_assert_every_net_is_kept(points, nets)


func test_two_circles_across_a_square_are_two_kept_nets() -> void:
	var points: Array = []
	for anchor: Vector3 in [Vector3(30, 0, 30), Vector3(38, 0, 30)]:
		for i: int in 4:
			var turn := TAU * i / 4.0
			points.append(anchor + Vector3(cos(turn), 0.0, sin(turn)) * 0.9)
	var nets := _nets(points)
	assert_eq(nets.size(), 2)
	_assert_every_net_is_kept(points, nets)


func test_a_loose_knot_draws_no_net_nobody_could_stand_in() -> void:
	# Four standing in a 3 m line: the pocket holds only near the middle, if at all.
	var points := [Vector3(70, 0, 20), Vector3(71, 0, 20), Vector3(72, 0, 20), Vector3(73.2, 0, 20)]
	_assert_every_net_is_kept(points, _nets(points))


## **A FULL CIRCLE STANDING LOOSE IS STILL ONE NET** (review of #252). Members 2 m
## from the centre, 2.8 m from each other — each 1.1 m from a real circle seat, inside
## the 1.2 m arrival — split into four singletons when the standing were partitioned
## at half a pocket radius, and the centre that guarantees 1.5 m was never tried.
func test_a_loosely_standing_full_circle_has_exactly_one_net_at_its_centre() -> void:
	var points := [Vector3(62, 0, 60), Vector3(60, 0, 62), Vector3(58, 0, 60), Vector3(60, 0, 58)]
	var nets := _nets(points)
	assert_eq(nets.size(), 1, "the circle's guaranteed pocket was not drawn, or drawn twice")
	if nets.size() == 1:
		var net: Array = nets[0]
		var centre: Vector3 = net[0]
		assert_almost_eq(Vector2(centre.x - 60, centre.z - 60).length(), 0.0, 0.001)
		assert_almost_eq(float(net[1]), Tuning.suspicion.blend_pocket_radius - 2.0, 0.001)
	_assert_every_net_is_kept(points, nets)
