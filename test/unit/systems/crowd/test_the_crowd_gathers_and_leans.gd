## **WHERE A STROLL ENDS: ALONE, IN A CIRCLE, OR AT A COUNTER.** US-0103, GDD-03 §6.3
## rule 7, `CrowdPlaces`.
##
## Measured before it: idle figures stood with another idle figure 27 % of the time
## and an NPC leaned at a stall counter 7 % of the time, so a player doing either was
## doing what the crowd almost never did. These hold the rules that changed it.
extends GutTest

const SEED := 20261004

var _map: MapData
var _rng: RandomNumberGenerator
var _spots: LeanSpots
var _places: CrowdPlaces
var _lean: float
var _circle: float


func before_each() -> void:
	_map = MapData.new()
	var anchors: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(60, 0, 0)]
	var counters: Array[Vector3] = [Vector3(30, 0, 0), Vector3(32, 0, 0)]
	_map.idle_anchors = anchors
	_map.static_props = counters
	_rng = RandomNumberGenerator.new()
	_rng.seed = SEED
	_spots = LeanSpots.new()
	_places = CrowdPlaces.new()
	_places.setup(_map, _rng, _spots)
	_lean = Tuning.crowd.lean_chance
	_circle = Tuning.crowd.circle_chance


func after_each() -> void:
	Tuning.crowd.lean_chance = _lean
	Tuning.crowd.circle_chance = _circle


## Every stroll in this test ends where the test says.
func _always(lean: float, circle: float) -> void:
	Tuning.crowd.lean_chance = lean
	Tuning.crowd.circle_chance = circle


func test_a_circle_starts_at_the_nearest_anchor_and_the_next_stroller_joins_it() -> void:
	_always(0.0, 1.0)
	var first := _places.goal_for(1, Vector3(9, 0, 1))
	assert_almost_eq(
		first.distance_to(Vector3(10, 0, 0)),
		Tuning.crowd.circle_radius,
		0.001,
		"a circle did not start at the anchor nearest the stroller"
	)
	var second := _places.goal_for(2, Vector3(5, 0, 0))
	assert_almost_eq(second.distance_to(Vector3(10, 0, 0)), Tuning.crowd.circle_radius, 0.001)
	assert_gt(first.distance_to(second), 0.5, "two members were given the same seat")
	assert_eq(_places.circles(), 1, "a second stroller nearby started its own circle")


func test_a_circle_across_the_district_is_not_joined() -> void:
	# **THE FIRST VERSION'S DEFECT.** A member sent across the district arrived after
	# the first had left, and circles never formed.
	_always(0.0, 1.0)
	_places.goal_for(1, Vector3(9, 0, 1))
	var far := _places.goal_for(2, Vector3(60, 0, 1))
	assert_almost_eq(far.distance_to(Vector3(60, 0, 0)), Tuning.crowd.circle_radius, 0.001)
	assert_eq(_places.circles(), 2, "a stroller crossed the district to join a circle")


func test_a_full_circle_takes_nobody_more_and_a_leaver_frees_a_seat() -> void:
	_always(0.0, 1.0)
	var members := 0
	for index: int in 10:
		_places.goal_for(index, Vector3(10, 0, 1))
		members = _places.in_circles()
	assert_between(members, Tuning.crowd.idle_group_size_min, Tuning.crowd.idle_group_size_max)
	_places.release(0)
	assert_eq(_places.in_circles(), members - 1)


func test_a_stroller_leans_at_a_free_counter_and_never_at_a_held_one() -> void:
	_always(1.0, 0.0)
	_spots.take_for_player(21, 0)
	var goal := _places.goal_for(4, Vector3.ZERO)
	assert_eq(goal, _map.static_props[1], "a civilian walked to a counter a player holds")
	assert_eq(_spots.reserved_by(4), 1, "the civilian did not reserve the counter it walks to")
	assert_eq(_spots.npc_at(1), LeanSpots.VACANT, "a civilian held a counter it has not reached")
	_places.arrived(4)
	assert_eq(_spots.npc_at(1), 4, "a civilian who arrived does not hold the counter")
	_places.release(4)
	assert_true(_spots.is_vacant(1), "a civilian who walked on kept the counter")


func test_a_full_market_sends_the_stroller_elsewhere() -> void:
	_always(1.0, 0.0)
	_spots.take_for_player(21, 0)
	_spots.take_for_player(22, 1)
	assert_eq(_places.goal_for(4, Vector3.ZERO), CrowdDirector.NO_GOAL)


func test_with_no_chance_of_either_every_stroll_ends_at_the_callers_anchor() -> void:
	_always(0.0, 0.0)
	for index: int in 20:
		assert_eq(_places.goal_for(index, Vector3.ZERO), CrowdDirector.NO_GOAL)


func test_a_player_finds_a_counter_a_civilian_holds_refused_with_a_reason() -> void:
	var blend := BlendSystem.new()
	var ctx := MatchContext.new()
	ctx.tick = 100
	ctx.map = _map
	ctx.lean_spots = _spots
	var refused: Array = []
	blend.blend_refused.connect(func(p: int, w: int) -> void: refused.append([p, w]))
	var pawn := PawnContext.new()
	pawn.peer_id = 21
	pawn.reset_for_spawn(Vector3(30, 0, 0.5), 0.0)
	ctx.pawn_contexts[21] = pawn
	_spots.take_for_npc(4, 0)
	assert_eq(blend.request(21, ctx), BlendKind.Kind.NONE, "a player leaned into a civilian")
	assert_eq(refused, [[21, BlendRefusal.Why.PROP_OCCUPIED]])
	_spots.release_npc(4)
	assert_eq(blend.request(21, ctx), BlendKind.Kind.PROP_STATIC)
	assert_eq(_spots.player_at(0), 21)
	blend.forget(21, ctx)
	assert_true(_spots.is_vacant(0), "a departing player kept the counter")


func test_a_player_who_stops_leaning_frees_the_counter() -> void:
	var blend := BlendSystem.new()
	var ctx := MatchContext.new()
	ctx.tick = 100
	ctx.map = _map
	ctx.lean_spots = _spots
	ctx.crowd_hash.setup(AABB(Vector3(-40, -20, -40), Vector3(160, 40, 160)), 8)
	var pawn := PawnContext.new()
	pawn.peer_id = 21
	pawn.reset_for_spawn(Vector3(30, 0, 0.5), 0.0)
	ctx.pawn_contexts[21] = pawn
	assert_eq(blend.request(21, ctx), BlendKind.Kind.PROP_STATIC)
	for _i: int in Tuning.ticks(&"TUN-BLEND-ENTRY-TIME") + 2:
		ctx.tick += 1
		blend.resolve(ctx)
	blend.request(21, ctx)
	for _i: int in Tuning.ticks(&"TUN-BLEND-EXIT-TIME") + 2:
		ctx.tick += 1
		blend.resolve(ctx)
	assert_true(_spots.is_vacant(0), "a player who stood up kept the counter")


func test_a_startled_civilian_leaves_its_counter_free() -> void:
	var pool := NpcPool.new()
	add_child_autofree(pool)
	pool.preallocate(4)
	pool.activate(4, SEED, CrowdRoster.PLAYABLE, 6)
	var director := CrowdDirector.new()
	add_child_autofree(director)
	var ctx := MatchContext.new()
	ctx.crowd = pool
	ctx.map = _map
	ctx.match_seed = SEED
	ctx.rng = _rng
	director.setup(ctx)
	# Somebody watching from beside the counter, so the NPC is in the near band and
	# thinks every tick rather than measuring LOD.
	var observer := CharacterBody3D.new()
	add_child_autofree(observer)
	observer.global_position = Vector3(30, 0, 2)
	ctx.pawns[1] = observer
	pool.set_position(0, Vector3(30, 0, 0))
	ctx.lean_spots.take_for_npc(0, 0)
	# One tick first: the alarm asks the spatial hash who is near, and the hash is built
	# at the top of a tick.
	ctx.tick += 1
	director.tick(ctx, MatchContext.net_dt())
	director.startle_at(Vector3(31, 0, 0))
	for _i: int in 6:
		ctx.tick += 1
		director.tick(ctx, MatchContext.net_dt())
	assert_eq(pool.brain_of(0).state, NpcBrain.State.STARTLE, "the premise: nobody was startled")
	assert_true(ctx.lean_spots.is_vacant(0), "a civilian who fled kept the counter")


## **REVIEW OF #250: A WALK TO A COUNTER BLOCKS NO PLAYER.** Driven through the real
## director: the civilian has chosen the counter and is still strolling, and a player
## at the empty counter must be let in; only an arrival holds it.
func test_an_empty_counter_a_civilian_walks_to_is_still_a_players() -> void:
	_always(1.0, 0.0)
	var scene := _a_director_with_one_civilian(Vector3(0, 0, 0))
	var ctx: MatchContext = scene[0]
	var pool: NpcPool = scene[1]
	var spot := ctx.lean_spots.reserved_by(0)
	assert_ne(spot, LeanSpots.VACANT, "the premise: the civilian chose no counter")
	assert_eq(pool.brain_of(0).state, NpcBrain.State.STROLL, "the premise: it is not walking")
	var blend := BlendSystem.new()
	var pawn := PawnContext.new()
	pawn.peer_id = 21
	pawn.reset_for_spawn(_map.static_props[spot] + Vector3(0, 0, 0.5), 0.0)
	ctx.pawn_contexts[21] = pawn
	assert_eq(
		blend.request(21, ctx),
		BlendKind.Kind.PROP_STATIC,
		"a player was refused an empty counter because a civilian was on the way"
	)
	assert_eq(ctx.lean_spots.reserved_by(0), LeanSpots.VACANT, "the reservation outlived it")


func test_a_civilian_holds_the_counter_only_once_it_has_arrived() -> void:
	_always(1.0, 0.0)
	var scene := _a_director_with_one_civilian(Vector3(0, 0, 0))
	var ctx: MatchContext = scene[0]
	var director: CrowdDirector = scene[2]
	var spot := ctx.lean_spots.reserved_by(0)
	assert_eq(ctx.lean_spots.npc_at(spot), LeanSpots.VACANT)
	director._intent.changed_state(0, NpcBrain.State.IDLE)
	assert_eq(ctx.lean_spots.npc_at(spot), 0, "a civilian who arrived does not hold it")


## **REVIEW OF #250: A CLONE REROUTE GIVES THE OLD PLACE UP.** `CloneBalance` hands its
## goal over before `CrowdPlaces` is asked, so the release has to come first.
func test_a_clone_rerouted_on_the_way_to_a_counter_gives_it_up() -> void:
	_always(1.0, 0.0)
	var scene := _an_intent_with_clones()
	var intent: CrowdIntent = scene[0]
	var balance: CloneBalance = scene[1]
	intent.goal_for(0, NpcBrain.State.STROLL)
	var spot := _spots.reserved_by(0)
	assert_ne(spot, LeanSpots.VACANT, "the premise: the clone chose no counter")
	balance.pending[0] = Vector3(60, 0, 0)
	assert_eq(intent.goal_for(0, NpcBrain.State.STROLL), Vector3(60, 0, 0))
	assert_eq(_spots.reserved_by(0), LeanSpots.VACANT, "the rerouted clone kept the counter")


func test_a_clone_rerouted_out_of_a_circle_gives_its_seat_up() -> void:
	_always(0.0, 1.0)
	var scene := _an_intent_with_clones()
	var intent: CrowdIntent = scene[0]
	var balance: CloneBalance = scene[1]
	intent.goal_for(0, NpcBrain.State.STROLL)
	intent.changed_state(0, NpcBrain.State.IDLE)
	assert_eq(intent.places().in_circles(), 1, "the premise: the clone stands in no circle")
	balance.pending[0] = Vector3(60, 0, 0)
	intent.goal_for(0, NpcBrain.State.STROLL)
	assert_eq(intent.places().in_circles(), 0, "the rerouted clone kept its seat")


func _a_director_with_one_civilian(at: Vector3) -> Array:
	var pool := NpcPool.new()
	add_child_autofree(pool)
	pool.preallocate(1)
	pool.activate(1, SEED, CrowdRoster.PLAYABLE, 6)
	var director := CrowdDirector.new()
	add_child_autofree(director)
	var ctx := MatchContext.new()
	ctx.crowd = pool
	ctx.map = _map
	ctx.match_seed = SEED
	ctx.rng = _rng
	ctx.lean_spots = _spots
	director.setup(ctx)
	var observer := CharacterBody3D.new()
	add_child_autofree(observer)
	observer.global_position = at + Vector3(0, 0, 2)
	ctx.pawns[1] = observer
	pool.set_position(0, at)
	pool.brain_of(0).state = NpcBrain.State.STROLL
	ctx.tick += 1
	director.tick(ctx, MatchContext.net_dt())
	return [ctx, pool, director]


func _an_intent_with_clones() -> Array:
	var pool := NpcPool.new()
	add_child_autofree(pool)
	pool.preallocate(2)
	pool.activate(2, SEED, CrowdRoster.PLAYABLE, 6)
	pool.set_position(0, Vector3(9, 0, 1))
	var balance := CloneBalance.new()
	balance.setup(_map, _rng)
	var intent := CrowdIntent.new()
	intent.setup(pool, _map, _rng, CrowdFormations.new(), CorpseRegister.new(), balance)
	intent.use_lean_spots(_spots)
	return [intent, balance]
