## **A ROUTE PARAMETRISED BY DISTANCE, NOT BY TIME.** US-0043, GDD-05 §5.2.
##
## Pure geometry, so every claim is asked directly. The one that matters is the
## last: a lap of a `MAP-VETRAIO` circuit at `TUN-CROWD-NPC-SPEED-STROLL` takes
## far longer than the period the map declares, and this is where that is
## measured rather than assumed.
extends GutTest

## A 20 × 20 m square: perimeter 80 m, and every corner is a number a reader can
## check without trusting the code under test.
const SQUARE := [
	Vector3(0.0, 0.0, 0.0),
	Vector3(20.0, 0.0, 0.0),
	Vector3(20.0, 0.0, 20.0),
	Vector3(0.0, 0.0, 20.0),
]

var _circuit: CrowdCircuit


func before_each() -> void:
	_circuit = CrowdCircuit.new()
	_circuit.setup(PackedVector3Array(SQUARE))


func test_the_loop_closes() -> void:
	# 80, not 60: the last waypoint joins back to the first, and a circuit that
	# forgot the closing segment would be a route with an invisible teleport in it.
	assert_almost_eq(_circuit.length(), 80.0, 0.001, "the closing segment is missing")


func test_a_point_lands_where_the_arithmetic_says() -> void:
	assert_almost_eq(_circuit.point_at(0.0), Vector3.ZERO, Vector3.ONE * 0.001)
	assert_almost_eq(_circuit.point_at(10.0), Vector3(10.0, 0.0, 0.0), Vector3.ONE * 0.001)
	assert_almost_eq(_circuit.point_at(30.0), Vector3(20.0, 0.0, 10.0), Vector3.ONE * 0.001)
	assert_almost_eq(_circuit.point_at(70.0), Vector3(0.0, 0.0, 10.0), Vector3.ONE * 0.001)


func test_it_wraps_rather_than_stopping_at_the_end() -> void:
	# A closed circuit that clamped would park every group on its last waypoint
	# after one lap — four permanent crowds and no walking groups at all.
	assert_almost_eq(_circuit.point_at(80.0), Vector3.ZERO, Vector3.ONE * 0.001)
	assert_almost_eq(_circuit.point_at(90.0), Vector3(10.0, 0.0, 0.0), Vector3.ONE * 0.001)
	assert_almost_eq(_circuit.point_at(-10.0), Vector3(0.0, 0.0, 10.0), Vector3.ONE * 0.001)


func test_the_heading_is_flat_and_normalised() -> void:
	# The formation is laid out across the ground from this vector; an unnormalised
	# one would scale the whole slot grid with the segment length.
	for along: float in [0.0, 15.0, 35.0, 55.0, 75.0]:
		var heading := _circuit.heading_at(along)
		assert_almost_eq(heading.length(), 1.0, 0.001, "heading is not unit at %.0f" % along)
		assert_almost_eq(heading.y, 0.0, 0.0001, "heading is not flat at %.0f" % along)


func test_the_heading_turns_the_corner() -> void:
	assert_almost_eq(_circuit.heading_at(5.0), Vector3(1.0, 0.0, 0.0), Vector3.ONE * 0.001)
	assert_almost_eq(_circuit.heading_at(25.0), Vector3(0.0, 0.0, 1.0), Vector3.ONE * 0.001)
	assert_almost_eq(_circuit.heading_at(45.0), Vector3(-1.0, 0.0, 0.0), Vector3.ONE * 0.001)


func test_walking_it_at_a_speed_returns_to_the_start() -> void:
	# **THE PROPERTY A GROUP DEPENDS ON.** Advancing by `speed * dt` for exactly one
	# period must land back where it started, or a formation would drift off its
	# own route over a match.
	var speed := Tuning.crowd.npc_speed_stroll
	var period := _circuit.period_at(speed)
	assert_almost_eq(period, 80.0 / speed, 0.001)
	# **METRES, NOT SECONDS.** The first version of this loop accumulated *distance*
	# and compared it against a *period*, which is a units error that reads as a
	# working test: it stopped after 57 m of an 80 m lap and reported the circuit
	# had failed to close. Trap 4's family — the assertion was fine and the
	# quantity was not.
	var dt := MatchContext.net_dt()
	var step := speed * dt
	var walked := ceilf(_circuit.length() / step) * step
	assert_almost_eq(
		_circuit.point_at(walked).distance_to(Vector3.ZERO), 0.0, step, "a full lap did not close"
	)


func test_a_degenerate_route_answers_rather_than_crashing() -> void:
	# A map with a one-waypoint circuit is a level defect, not a server that will
	# not start.
	var lonely := CrowdCircuit.new()
	lonely.setup(PackedVector3Array([Vector3(5.0, 0.0, 5.0)]))
	assert_eq(lonely.point_at(37.0), Vector3(5.0, 0.0, 5.0))
	var nothing := CrowdCircuit.new()
	nothing.setup(PackedVector3Array())
	assert_eq(nothing.length(), 0.0)
	assert_eq(nothing.point_at(1.0), Vector3.ZERO)


func test_the_shipped_circuits_take_far_longer_than_their_declared_period() -> void:
	# **US-0043's FIRST FINDING, MEASURED HERE SO IT CANNOT BE FORGOTTEN.**
	# `MapData.circuit_periods` declares 55–75 s per GDD-05 §5.2, and the routes in
	# `VetraioLayout.CIRCUITS` are 150–237 m long. At `TUN-CROWD-NPC-SPEED-STROLL`
	# a lap takes 107–169 s; at the declared period a group would walk at 2.6–3.2
	# m/s, which is faster than `TUN-SPEED-RUN`.
	#
	# The walking group is the **only** blend that lets a player travel while
	# gaining anonymity (GDD-03 §4.1.2). At twice blend-walk it would be a speed
	# cheat wearing a crowd, so the speed is what the implementation honours and
	# this is the record of what that costs.
	var map: MapData = load("res://data/maps/map_vetraio.tres")
	assert_gt(map.circuits.size(), 0, "the map declares no circuits — the check is vacuous")
	var speed := Tuning.crowd.npc_speed_stroll
	for index: int in map.circuits.size():
		var circuit := CrowdCircuit.new()
		circuit.setup(map.circuits[index])
		var declared: float = map.circuit_periods[index]
		gut.p(
			(
				"circuit %d: %.1f m, declared %.0f s (%.2f m/s), at stroll %.0f s"
				% [
					index,
					circuit.length(),
					declared,
					circuit.length() / declared,
					circuit.period_at(speed)
				]
			)
		)
		assert_gt(
			circuit.length() / declared,
			speed,
			"circuit %d now fits its declared period — retick US-0043's first criterion" % index
		)
