## **THE RING, FILLED BY A REAL SERVER.** US-0035, TDD-04 §8.
##
## `test_lag_comp_history.gd` proves the ring's arithmetic against arrays a test
## chose. This proves the other half: that a real `MatchDirector` driving a real
## `PawnHost` over the district's real collision actually puts pawn transforms
## into it, on the tick they belong to.
##
## An integration test because the thing being asserted is the **wiring** — that
## `tick_completed` reaches `LagCompRecorder`, that the recorder can see a pawn,
## and that what lands in the ring is the position the tick ended at. A double
## for any of those would pass while nothing recorded at all, which is trap 4 and
## how three camera stories were built around a pawn that did not render.
extends GutTest

const MAP_COLLISION := "res://scenes/map/map_vetraio_collision.tscn"
const MAP := "res://data/maps/map_vetraio.tres"
const PEER := 21
const OTHER := 22

var _director: MatchDirector
var _host: PawnHost
var _recorder: LagCompRecorder


func before_each() -> void:
	add_child_autofree((load(MAP_COLLISION) as PackedScene).instantiate())

	_director = MatchDirector.new()
	add_child_autofree(_director)
	_director.ctx.map = load(MAP) as MapData
	_director.ctx.phase = MatchPhase.Phase.ACTIVE

	_host = PawnHost.new()
	add_child_autofree(_host)
	_host.setup(_director.ctx)
	_director.input_applied.connect(_host.apply_input)

	_recorder = LagCompRecorder.new()
	add_child_autofree(_recorder)
	_recorder.setup(_director.ctx, _host)
	_director.tick_completed.connect(_recorder.record)

	await get_tree().physics_frame


func _run_ticks(count: int) -> void:
	for _i: int in count * 2:
		_director._physics_process(1.0 / Tuning.net.client_input_rate)


## A command that walks the pawn forward.
func _forward(seq: int) -> InputCommand:
	var command := InputCommand.new()
	command.seq = seq
	command.move = Vector2(0.0, 1.0)
	return command


func _walk(peer: int, ticks: int) -> void:
	for i: int in ticks:
		_director.enqueue_input(peer, _forward(i * 2 + 1))
		_director.enqueue_input(peer, _forward(i * 2 + 2))
		_run_ticks(1)


func test_the_ring_is_empty_before_anything_happens() -> void:
	assert_eq(_director.ctx.lag_comp.size(), 0, "the history had content before the match ran")


func test_a_pawn_is_recorded_every_tick() -> void:
	_host.spawn(PEER)
	_run_ticks(5)
	var history := _director.ctx.lag_comp
	assert_eq(history.size(), 5, "five ticks did not produce five recorded frames")
	assert_eq(history.newest_tick(), _director.ctx.tick, "the newest frame is not this tick")


func test_it_records_where_the_tick_ended_not_where_it_began() -> void:
	# **THE PROPERTY THE STORY TURNS ON.** The recorder is driven by
	# `tick_completed`; connecting it to `net_ticked` instead would record the
	# world as the tick *found* it, and every frame would be one tick stale.
	#
	# The snapshot builder had exactly that defect from US-0030 to US-0035 while
	# two comments claimed otherwise, and it is invisible in any assertion that
	# only checks a frame exists.
	_host.spawn(PEER)
	_walk(PEER, 6)

	var history := _director.ctx.lag_comp
	var newest := history.rewind(history.newest_tick(), Vector3.ZERO, 1000.0)
	var live := _host.context_for(PEER).position
	assert_almost_eq(
		newest.position_of(PEER).distance_to(live),
		0.0,
		0.001,
		"the newest frame is not the position the tick ended at"
	)


func test_the_past_really_is_behind_the_present() -> void:
	# If the ring recorded the *current* position into every frame — an easy way
	# to write this wrong, since the recorder holds a live `PawnContext` — the
	# test above would still pass and lag compensation would rewind to nowhere.
	_host.spawn(PEER)
	_walk(PEER, 8)

	var history := _director.ctx.lag_comp
	var oldest := history.rewind(history.oldest_tick(), Vector3.ZERO, 1000.0)
	var newest := history.rewind(history.newest_tick(), Vector3.ZERO, 1000.0)
	var travelled := oldest.position_of(PEER).distance_to(newest.position_of(PEER))
	gut.p("pawn travelled %.3f m across the recorded window" % travelled)
	assert_gt(travelled, 0.05, "every recorded frame holds the same position — nothing was rewound")


func test_two_pawns_are_recorded_separately() -> void:
	_host.spawn(PEER)
	_host.spawn(OTHER)
	_run_ticks(3)

	var history := _director.ctx.lag_comp
	var world := history.rewind(history.newest_tick(), _host.context_for(PEER).position, 1000.0)
	assert_true(world.has(PEER), "the first pawn is missing from the ring")
	assert_true(world.has(OTHER), "the second pawn is missing from the ring")
	assert_ne(
		world.position_of(PEER), world.position_of(OTHER), "two pawns recorded at one position"
	)


func test_a_departed_pawn_stops_being_recorded() -> void:
	# **ENet REUSES PEER IDS**, US-0037. A ring that kept recording a freed pawn
	# would hand the next joiner a past that is not theirs — and at M4 that past
	# is what a kill resolves against.
	_host.spawn(PEER)
	_run_ticks(3)
	_host.despawn(PEER)
	_run_ticks(3)

	var history := _director.ctx.lag_comp
	var world := history.rewind(history.newest_tick(), Vector3.ZERO, 1000.0)
	assert_false(world.has(PEER), "a departed pawn is still being recorded")


func test_nothing_is_recorded_in_the_lobby() -> void:
	# The clock advances outside play; the world does not. A history full of
	# identical lobby frames would answer a rewind with a world that never was.
	_host.spawn(PEER)
	_director.ctx.phase = MatchPhase.Phase.LOBBY
	_run_ticks(10)
	assert_eq(_director.ctx.lag_comp.size(), 0, "the lobby was recorded into the history")


func test_the_ring_never_grows_past_its_capacity() -> void:
	_host.spawn(PEER)
	_run_ticks(40)
	var history := _director.ctx.lag_comp
	assert_eq(history.size(), history.capacity(), "the ring is not full after 40 ticks")
	assert_eq(
		history.newest_tick() - history.oldest_tick(),
		history.capacity() - 1,
		"the ring holds a window of the wrong length"
	)
