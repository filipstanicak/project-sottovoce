## **LAYER 4 OF FOUR, AND THE ONLY ONE WHOSE FAILURE IS INVISIBLE.** US-0047,
## TDD-08 §5 and §5.1, GDD-03 §6.3 rule 3.
##
## **A UNIT TEST RUNNING A THREE-MINUTE MATCH, WHICH NEEDS SAYING.** The story's
## test notes ask for a headless match; the integration suite is at 152 s of the
## 180 s it is allowed, and 5 400 net ticks of *physics* would not fit in what is
## left. So the crowd here is real — real `NpcBrain`s, real `NpcPool` bodies, the
## real `SpatialHash` — and only the **navigation** is modelled: an NPC walks to
## its anchor in a straight line at `TUN-CROWD-NPC-SPEED-STROLL`.
##
## **THAT MODEL IS OPTIMISTIC IN ONE DIRECTION AND THE TEST SAYS SO.** A real path
## round the district's geometry is longer than a straight line, so a real clone
## takes longer to arrive than one here does. What the model cannot flatter is the
## *rule*: the counting, the reservations and the choice of who goes are the
## shipped code, unchanged.
##
## **THE COUNTERFACTUAL IS ASSERTED BEFORE THE GUARANTEE.** A crowd that never
## develops a local hole satisfies "every player always had two clones nearby"
## perfectly, and would go green with `CloneBalance` deleted. So the first test
## runs the same three minutes with the director's pass switched off and requires
## the starvation to actually happen.
extends GutTest

const SEED := 20260818
const MAP_DATA := "res://data/maps/map_vetraio.tres"
const CROWD := 78
const PLAYERS := 6

## Three minutes at the 30 Hz net tick. The story's own duration.
const MATCH_TICKS := 5400

## Ticks between samples of "how many clones can this player see". A third of a
## second: nobody loses a clone faster than that at walking speed, and 5 400
## samples of a 24-way count is a second of test time for no more evidence.
const SAMPLE_EVERY := 10

var _pool: NpcPool
var _hash: SpatialHash
var _map: MapData
var _rng: RandomNumberGenerator
var _balance: CloneBalance
var _watchers: PackedVector3Array
var _goals: PackedVector3Array


func before_each() -> void:
	_map = load(MAP_DATA) as MapData
	_rng = RandomNumberGenerator.new()
	_rng.seed = SEED
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, PLAYERS)
	_hash = SpatialHash.new()
	_hash.setup(_map.bounds, CROWD)
	_balance = CloneBalance.new()
	_balance.setup(_map, _rng)
	_goals = PackedVector3Array()
	_goals.resize(CROWD)
	for index: int in CROWD:
		var anchor: Vector3 = _map.idle_anchors[index % _map.idle_anchors.size()]
		_pool.set_position(index, anchor)
		_pool.context_of(index).rng = _rng
		_goals[index] = CrowdDirector.NO_GOAL
	_cluster_the_players()


## **SIX PLAYERS IN ONE ZONE**, which is what the story asks for and also the case
## that matters: local depletion is a *local* failure, so a crowd spread evenly
## over a district full of evenly spread players never produces one.
func _cluster_the_players() -> void:
	_watchers = PackedVector3Array()
	var here: Vector3 = _map.idle_anchors[0]
	for seat: int in PLAYERS:
		var angle := TAU * float(seat) / float(PLAYERS)
		_watchers.append(here + Vector3(cos(angle) * 3.0, 0.0, sin(angle) * 3.0))


## **PUT THE WHOLE CROWD SOMEWHERE ELSE.** The short tests below assert what
## happens when a region is short; placed round-robin over 62 anchors, the
## cluster starts with enough of everybody and the first pass has nothing to do —
## which reads exactly like a rule that does not work.
func _starve_the_district() -> void:
	var far: Vector3 = _map.idle_anchors[_map.idle_anchors.size() - 1]
	for index: int in CROWD:
		_pool.set_position(index, far + Vector3(float(index % 9), 0.0, float(index / 9)))
	_reindex()


func _reindex() -> void:
	var points := PackedVector3Array()
	points.resize(CROWD)
	for index: int in CROWD:
		points[index] = _pool.body_of(index).global_position
	_hash.rebuild(points, _pool.roster, CROWD)


## One tick of the district: brains run, walkers walk, arrivals sit down. This is
## `CrowdDirector._advance` with the navigation replaced by a straight line.
func _step_the_crowd() -> void:
	var dt := MatchContext.net_dt()
	var step := Tuning.crowd.npc_speed_stroll * dt
	var arrive: float = Tuning.crowd.anchor_arrive_radius
	for index: int in CROWD:
		var brain := _pool.brain_of(index)
		var cctx := _pool.context_of(index)
		brain.step(cctx, dt)
		cctx.clear_events()
		if brain.state != NpcBrain.State.STROLL:
			continue
		if _goals[index] == CrowdDirector.NO_GOAL:
			_goals[index] = _next_anchor(index)
		var here := _pool.body_of(index).global_position
		var to := _goals[index] - here
		to.y = 0.0
		if to.length() <= arrive:
			brain.handle(NpcBrain.Event.REACHED_ANCHOR, cctx)
			cctx.clear_events()
			_goals[index] = CrowdDirector.NO_GOAL
			continue
		_pool.set_position(index, here + to.normalized() * step)


## What `CrowdIntent._an_anchor` does: the reservation if there is one, otherwise
## a seeded pick. The whole of layer 4's effect on an NPC is this one line.
func _next_anchor(index: int) -> Vector3:
	var directed := _balance.take(index)
	if directed != CrowdDirector.NO_GOAL:
		return directed
	return _map.idle_anchors[_rng.randi_range(0, _map.idle_anchors.size() - 1)]


## `CrowdDirector._rebalance_clones`, in the same three lines.
func _apply(sent: Dictionary) -> void:
	for index: int in sent:
		_goals[index] = CrowdDirector.NO_GOAL
		var brain := _pool.brain_of(index)
		if brain.state == NpcBrain.State.IDLE:
			brain.handle(NpcBrain.Event.TIMER_EXPIRED, _pool.context_of(index))
			_pool.context_of(index).clear_events()


## The worst count any player had of any in-use persona, sampled through the run.
## Returns [worst, worst_settled, samples, breaches, settle_ticks, late_breaches].
func _run_the_match(rebalancing: bool) -> Array:
	var interval := maxi(Tuning.ticks(&"TUN-CROWD-DIRECTOR-INTERVAL"), 1)
	var radius: float = Tuning.crowd.clone_local_radius
	var worst := 99
	var worst_settled := 99
	var samples := 0
	var breaches := 0
	var late_breaches := 0
	# **TWENTY SECONDS.** A clone crosses the local radius in about eighteen, so
	# nothing that re-routes rather than teleporting can be judged before then —
	# and the first seconds belong to `CrowdPlacement`, which is persona-blind.
	var settle := interval * 10
	for tick: int in range(1, MATCH_TICKS + 1):
		_step_the_crowd()
		_reindex()
		if rebalancing and tick % interval == 0:
			_apply(_balance.rebalance(_hash, _pool, _watchers, CrowdRoster.PLAYABLE))
		if tick % SAMPLE_EVERY != 0:
			continue
		samples += 1
		for centre: Vector3 in _watchers:
			for persona: StringName in CrowdRoster.PLAYABLE:
				var seen := _hash.count_persona(centre, radius, persona)
				worst = mini(worst, seen)
				if seen < int(Tuning.crowd.clone_local_min):
					breaches += 1
					if tick > settle:
						late_breaches += 1
				if tick > settle:
					worst_settled = mini(worst_settled, seen)
	return [worst, worst_settled, samples, breaches, settle, late_breaches]


func test_the_scenario_actually_starves_without_the_director() -> void:
	# **THE VACUOUS-SUCCESS GUARD, AND IT RUNS FIRST.** Everything below asserts
	# that a hole does not open. If this district never opened one, all of it would
	# pass with `CloneBalance` deleted from the project.
	var result := _run_the_match(false)
	gut.p(
		(
			"no director: worst %d clones of one persona within %.0f m, over %d samples"
			% [result[0], Tuning.crowd.clone_local_radius, result[2]]
		)
	)
	assert_gt(result[2], 100, "the run took too few samples to mean anything")
	assert_lt(
		int(result[0]),
		int(Tuning.crowd.clone_local_min),
		(
			"six clustered players never dropped below the local minimum on their own — "
			+ "this district cannot demonstrate the failure US-0047 exists to fix, so "
			+ "every assertion in this file is vacuous"
		)
	)


func test_the_local_minimum_holds_over_a_clustered_match() -> void:
	# The story's fourth criterion. **The first passes are excluded and the number
	# is printed rather than hidden**: the crowd starts wherever it was placed, and
	# a clone crosses the local radius in about eighteen seconds, so no rule that
	# re-routes rather than teleporting can be true at tick one.
	var result := _run_the_match(true)
	gut.p(
		(
			(
				"with the director: worst %d overall, %d after settling; "
				+ "%d of %d readings under the floor, %d of them after settling; "
				+ "%d fetches over %d passes"
			)
			% [
				result[0],
				result[1],
				result[3],
				result[2] * PLAYERS * 4,
				result[5],
				_balance.rerouted_total,
				_balance.passes
			]
		)
	)
	assert_gt(_balance.rerouted_total, 0, "nothing was ever fetched — the rule is inert")
	assert_gt(_balance.held_total, 0, "nothing was ever held; only fetching cannot hold a floor")
	assert_eq(
		result[5],
		0,
		(
			(
				"the floor was breached %d times after the crowd settled — the two halves of "
				+ "this rule are holding and fetching, and one of them has stopped working"
			)
			% result[5]
		)
	)
	assert_true(
		int(result[1]) >= int(Tuning.crowd.clone_local_min),
		(
			(
				"a clustered player was left with %d clones of an in-use persona within %.0f m, "
				+ "against TUN-CROWD-CLONE-LOCAL-MIN %d"
			)
			% [result[1], Tuning.crowd.clone_local_radius, Tuning.crowd.clone_local_min]
		)
	)


func test_it_reroutes_and_never_respawns_or_repersonas() -> void:
	# The story's second criterion, and GDD-03 §6.3 rule 4 underneath it: a server
	# that changed a clone's identity would be describing a different city from the
	# one every client derived from the same seed.
	var before := _pool.roster.duplicate()
	var bodies := _pool.body_count()
	for _pass: int in 20:
		for _tick: int in 60:
			_step_the_crowd()
		_reindex()
		_apply(_balance.rebalance(_hash, _pool, _watchers, CrowdRoster.PLAYABLE))
	assert_gt(_balance.rerouted_total, 0, "nothing was re-routed, so nothing was tested")
	assert_eq(_pool.roster, before, "a clone's persona changed — GDD-03 §6.3 rule 4")
	assert_eq(_pool.body_count(), bodies, "the pool grew or shrank; nothing may spawn mid-match")
	assert_eq(_pool.active_count(), CROWD, "the active crowd size changed")


func test_every_destination_is_a_place_and_never_a_player() -> void:
	# **THE MECHANICAL HALF OF "MUST NOT READ AS CLONES FOLLOWING PLAYERS".** The
	# target is city furniture. A clone sent to an anchor arrives and stands there
	# like everybody else; a clone sent at a player converges on whoever is alone,
	# which is the tell this whole system exists to avoid producing.
	_starve_the_district()
	var sent := _balance.rebalance(_hash, _pool, _watchers, CrowdRoster.PLAYABLE)
	assert_gt(sent.size(), 0, "no re-route happened, so no destination was checked")
	for index: int in sent:
		var goal: Vector3 = sent[index]
		assert_true(
			_map.idle_anchors.has(goal),
			"clone %d was sent to %v, which is not an anchor" % [index, goal]
		)
		for centre: Vector3 in _watchers:
			assert_true(
				goal.distance_to(centre) > 0.01,
				"clone %d was sent at a player's own position" % index
			)


func test_a_reroute_does_not_re_aim_at_a_player_who_moves() -> void:
	# The other half. A destination that tracked the player would be a pursuit
	# however slowly it updated; this one is decided once and then walked to.
	_starve_the_district()
	var sent := _balance.rebalance(_hash, _pool, _watchers, CrowdRoster.PLAYABLE)
	assert_gt(sent.size(), 0, "nothing was re-routed, so nothing was tested")
	var who: int = sent.keys()[0]
	var target: Vector3 = sent[who]
	for seat: int in _watchers.size():
		_watchers[seat] = _watchers[seat] + Vector3(40.0, 0.0, 40.0)
	for _tick: int in 60:
		_step_the_crowd()
	_reindex()
	_apply(_balance.rebalance(_hash, _pool, _watchers, CrowdRoster.PLAYABLE))
	assert_eq(_balance.take(who), target, "the clone's destination followed the player")


func test_nobody_is_robbed_to_pay_somebody_else() -> void:
	# Two clusters, both short. A rule that took the nearest clone regardless would
	# move one out of A's radius to fix B's, then back again next pass — and
	# neither player would ever hold two.
	var far: Vector3 = _map.idle_anchors[_map.idle_anchors.size() / 2]
	_watchers.append(far)
	var radius: float = Tuning.crowd.clone_local_radius
	_reindex()
	_balance.rebalance(_hash, _pool, _watchers, CrowdRoster.PLAYABLE)
	# **FETCHES ONLY.** A held insider is a re-route as well, and it is by
	# definition standing inside somebody's radius — its own player's.
	assert_gt(_balance.fetched.size(), 0, "nothing was fetched, so nothing was tested")
	for index: int in _balance.fetched:
		var here := _pool.body_of(index).global_position
		for centre: Vector3 in _watchers:
			var flat := Vector2(here.x - centre.x, here.z - centre.z).length()
			assert_true(
				flat > radius,
				(
					"clone %d was taken from inside a player's own %.0f m (%.1f m away)"
					% [index, radius, flat]
				)
			)


func test_a_hole_one_deep_is_not_answered_with_a_stream() -> void:
	# **THE ACCOUNTING, WHICH IS WHAT REPLACES A THROTTLE.** A clone crosses the
	# local radius in about eighteen seconds — nine passes. Counting only arrived
	# clones would send nine for a hole one deep, and nine Lucerna walking into one
	# market is precisely the leak the story warns about.
	_starve_the_district()
	_balance.rebalance(_hash, _pool, _watchers, CrowdRoster.PLAYABLE)
	var first := _balance.rerouted_last_pass
	assert_gt(first, 0, "the first pass fetched nobody, so there is no stream to bound")
	var later := 0
	for _pass: int in 5:
		for _tick: int in 60:
			_step_the_crowd()
		_reindex()
		_balance.rebalance(_hash, _pool, _watchers, CrowdRoster.PLAYABLE)
		later += _balance.rerouted_last_pass
	gut.p("first pass fetched %d, the next five fetched %d in total" % [first, later])
	assert_lt(
		later, first, "the same holes were fetched again every pass — nothing counts as inbound"
	)


func test_an_unwatched_crowd_is_never_rerouted() -> void:
	# No players, no local minimum to hold. A district that reorganised itself with
	# nobody in it would be spending the crowd on nothing and, worse, would mean the
	# rule is keyed on something other than a player.
	_reindex()
	var sent := _balance.rebalance(_hash, _pool, PackedVector3Array(), CrowdRoster.PLAYABLE)
	assert_eq(sent.size(), 0, "an empty district re-routed somebody")
	assert_eq(_balance.deficits_last_pass, 0, "a deficit was found with nobody to have one")
