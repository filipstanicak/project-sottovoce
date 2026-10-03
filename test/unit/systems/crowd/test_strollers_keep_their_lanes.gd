## **THE LANE REACHES THE CROWD AND THE BOTS.** US-0103.
##
## `test_crowd_lane.gd` holds the arithmetic; these hold the hops: every figure is
## dealt its lane from the match seed, a stroller is sent on a route moved onto it and
## nobody else is, the walk ends at the end of that route — which is also how a
## stroller sent to an unreachable anchor finally stops — and the civilian test bot
## walks by the same rule, or it is the one figure left on the centre line.
extends GutTest

const SEED := 20261004
const CROWD := 12

var _pool: NpcPool
var _steering: Steering
var _route: StrollRoute


func before_each() -> void:
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, 6)
	_steering = Steering.new()
	_route = StrollRoute.new()
	_route.setup(_pool, _steering, SEED)
	# A straight street along +Z, and a navmesh that is everything with x in ±2.
	_route.inject(
		func(from: Vector3, to: Vector3) -> PackedVector3Array:
			return PackedVector3Array([from, to]),
		func(point: Vector3) -> Vector3: return Vector3(clampf(point.x, -2.0, 2.0), 0.0, point.z)
	)
	for index: int in CROWD:
		_pool.set_position(index, Vector3.ZERO)


func _a_figure_with_a_lane() -> int:
	for index: int in CROWD:
		if absf(_route.lane_of(index)) > 0.3:
			return index
	return -1


func test_every_figure_is_dealt_its_lane_from_the_match_seed() -> void:
	var sides := {}
	for index: int in CROWD:
		assert_almost_eq(
			_route.lane_of(index),
			CrowdLane.lateral_for(SEED, index, Tuning.crowd.lane_spread),
			0.0001,
			"figure %d was not dealt the rule's lane" % index
		)
		sides[signf(_route.lane_of(index))] = true
	assert_true(sides.has(1.0) and sides.has(-1.0), "every figure was dealt the same side")


func test_a_stroller_walks_its_lane_and_arrives_where_it_was_going() -> void:
	var index := _a_figure_with_a_lane()
	assert_gt(index, -1, "the premise: no figure in the fixture has a lane")
	_route.aim(index, Vector3(0, 0, 20), true)
	assert_false(_route.arrived(index), "a stroller arrived before it set off")
	_pool.set_position(index, Vector3(0, 0, 10))
	_route.drive(index, Tuning.crowd.npc_speed_stroll)
	_pool.set_position(index, Vector3(0, 0, 19.5))
	_route.drive(index, Tuning.crowd.npc_speed_stroll)
	assert_true(_route.arrived(index), "a stroller at the end of its route did not arrive")


func test_a_figure_that_is_not_strolling_keeps_the_agents_own_path() -> void:
	var index := _a_figure_with_a_lane()
	_route.aim(index, Vector3(0, 0, 20), false)
	assert_eq(
		_pool.agent_of(index).target_position,
		Vector3(0, 0, 20),
		"a figure off its lane was not handed to the agent's own path"
	)


func test_the_route_is_the_lane_route_snapped_onto_the_street() -> void:
	var index := _a_figure_with_a_lane()
	var lane := _route.lane_of(index)
	_route.aim(index, Vector3(0, 0, 20), true)
	var expected := CrowdLane.offset_path(
		PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 20)]),
		lane,
		func(p: Vector3) -> Vector3: return Vector3(clampf(p.x, -2.0, 2.0), 0.0, p.z)
	)
	assert_eq(_route._routes[index], expected, "the stroller was not sent on its lane")
	# An agent that has arrived stops avoiding and is moved by nobody: the goal must be
	# its target even though the route is what is walked.
	assert_eq(
		_pool.agent_of(index).target_position,
		Vector3(0, 0, 20),
		"a stroller on its lane holds a target it already reached, and stands"
	)


func test_the_civilian_bot_is_given_its_lane_by_the_crowds_rule() -> void:
	var source := FileAccess.get_file_as_string("res://tools/bot_client.gd")
	assert_true(
		source.contains("CrowdLane.lateral_for(_index, 0, Tuning.crowd.lane_spread)"),
		"the civilian bot no longer walks a lane by the crowd's rule"
	)
	var brain := FileAccess.get_file_as_string("res://tools/bot_civilian.gd")
	assert_true(brain.contains("CrowdLane.offset_path("), "the bot's route ignores its lane")
