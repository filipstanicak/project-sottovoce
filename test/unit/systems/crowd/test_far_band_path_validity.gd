## **A FAR AGENT RECOMPUTES ITS ROUTE LESS OFTEN.** US-0041's last criterion,
## TDD-08 §12 Q2, unblocked when US-0045 built the bands.
##
## **THIS IS THE ONE PATH QUERY `RepathQueue` DOES NOT STAGGER.** The queue
## decides when the *director* gives an agent a new target, three a tick. It says
## nothing about `path_max_distance`, which the agent uses to recalculate on its
## own whenever avoidance has pushed it further off its route than that — and
## ninety agents deciding that on the same crowded tick is exactly the spike §12
## Q2 asks about.
##
## **THE ASSERTION THAT MATTERS IS THE RETURN JOURNEY.** Loosening a Far agent is
## the easy half and the half that reads as done. The half that bites is a Far
## agent walking back into Near while keeping the tolerance its distance
## justified: it would follow a stale path right in front of the player who came
## to look at it, and nothing would report it.
extends GutTest

const SEED := 20260818
const CROWD := 24

var _pool: NpcPool
var _director: CrowdDirector
var _ctx: MatchContext


func before_each() -> void:
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, 6)
	_ctx = MatchContext.new()
	_ctx.crowd = _pool
	_ctx.match_seed = SEED
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	# Four metres apart along +X: index 0 at 0 m, index 23 at 92 m, so one line
	# crosses all three bands from a watcher at the origin.
	for index: int in CROWD:
		_pool.set_position(index, Vector3(float(index) * 4.0, 0.0, 0.0))
	_director = CrowdDirector.new()
	add_child_autofree(_director)


func _watch_from(where: Vector3) -> void:
	var observer := CharacterBody3D.new()
	add_child_autofree(observer)
	observer.global_position = where
	_ctx.pawns[1] = observer


func _tick(times: int) -> void:
	for _t: int in times:
		_ctx.tick += 1
		_director.tick(_ctx, MatchContext.net_dt())


func _drift(index: int) -> float:
	return _pool.agent_of(index).path_max_distance


## The first NPC in each band, so an assertion names a band rather than an index.
func _one_in(band: int) -> int:
	for index: int in CROWD:
		if _director.band_of(index) == band:
			return index
	return -1


func test_all_three_bands_are_occupied_by_this_line() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** Every comparison below is between two bands,
	# and a line that fell entirely into one would make all of them compare a value
	# with itself. It is also what would fail first if the band radii were retuned.
	_watch_from(Vector3.ZERO)
	_director.setup(_ctx)
	_tick(1)
	for band: int in [CrowdLod.Band.NEAR, CrowdLod.Band.MID, CrowdLod.Band.FAR]:
		assert_gt(_one_in(band), -1, "no NPC on this line is in band %d" % band)


func test_the_further_band_tolerates_more_drift() -> void:
	_watch_from(Vector3.ZERO)
	_director.setup(_ctx)
	_tick(1)
	var near := _drift(_one_in(CrowdLod.Band.NEAR))
	var mid := _drift(_one_in(CrowdLod.Band.MID))
	var far := _drift(_one_in(CrowdLod.Band.FAR))
	gut.p("path_max_distance: Near %.1f m, Mid %.1f m, Far %.1f m" % [near, mid, far])
	assert_gt(mid, near, "a Mid agent does not tolerate more drift than a Near one")
	assert_gt(far, mid, "a Far agent does not tolerate more drift than a Mid one")


func test_the_multiplier_is_the_band_stride_and_not_a_new_number() -> void:
	# **ONE NUMBER, NOT TWO.** How often an agent is thought about and how far it
	# may wander are the same question, so the stride is the multiplier. A separate
	# constant would be a second thing to retune and a second thing to forget.
	_watch_from(Vector3.ZERO)
	_director.setup(_ctx)
	_tick(1)
	var near := _drift(_one_in(CrowdLod.Band.NEAR))
	assert_gt(near, 0.0, "the Near tolerance is zero — the base was never captured")
	for band: int in [CrowdLod.Band.MID, CrowdLod.Band.FAR]:
		assert_almost_eq(
			_drift(_one_in(band)),
			near * float(CrowdLod.stride_of(band as CrowdLod.Band)),
			0.001,
			"band %d's path tolerance is not its own stride times the Near one" % band
		)


func test_a_near_agent_keeps_the_engines_own_default() -> void:
	# The agents a player can actually watch must behave exactly as they did before
	# this existed. A Near multiple of 1 is what guarantees that, and it is why the
	# base is captured from the agent rather than declared as 5.0 somewhere.
	var untouched := NavigationAgent3D.new()
	add_child_autofree(untouched)
	_watch_from(Vector3.ZERO)
	_director.setup(_ctx)
	_tick(1)
	assert_almost_eq(
		_drift(_one_in(CrowdLod.Band.NEAR)),
		untouched.path_max_distance,
		0.001,
		"a Near agent no longer matches an untouched NavigationAgent3D"
	)


func test_an_agent_walking_back_into_near_is_tightened_again() -> void:
	# **THE HALF THAT WOULD HAVE SHIPPED BROKEN.** Loosening on the way out is the
	# obvious direction. A Far agent that kept its loose tolerance when a player
	# walked up to it would follow a stale path in front of the one person looking
	# at it, and no test that only checks the outward direction would notice.
	_watch_from(Vector3(200.0, 0.0, 0.0))
	_director.setup(_ctx)
	_tick(1)
	var distant := _one_in(CrowdLod.Band.FAR)
	assert_gt(distant, -1, "nobody was Far to begin with")
	var loose := _drift(distant)

	# The player walks over to that NPC.
	(_ctx.pawns[1] as Node3D).global_position = _pool.body_of(distant).global_position
	_tick(1)
	assert_eq(_director.band_of(distant), CrowdLod.Band.NEAR, "the NPC did not become Near")
	assert_lt(
		_drift(distant), loose, "a Far agent kept its loose path tolerance after being approached"
	)


func test_an_unwatched_crowd_is_uniformly_loose() -> void:
	# No players means Far for everybody — `CrowdLod`'s own rule, and the emptiest
	# server must not be the most expensive one.
	_director.setup(_ctx)
	_tick(1)
	var first := _drift(0)
	for index: int in CROWD:
		assert_eq(_director.band_of(index), CrowdLod.Band.FAR, "NPC %d is not Far" % index)
		assert_almost_eq(_drift(index), first, 0.001, "NPC %d differs from the rest" % index)
