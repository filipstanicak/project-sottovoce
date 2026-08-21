## **LAYER 4 OF FOUR, AND THE ONLY ONE WHOSE FAILURE IS INVISIBLE.** US-0047,
## TDD-08 §5, §5.1.4 and §5.1.5, GDD-03 §6.3 rule 3.
## **A UNIT TEST RUNNING A THREE-MINUTE MATCH.** The integration suite has no room
## for 5 400 ticks of physics, so the crowd is real and only **navigation** is
## modelled, as a straight line at `TUN-CROWD-NPC-SPEED-STROLL`: optimistic about
## travel, so it cannot flatter the rule.
##
## **THE COUNTERFACTUAL IS ASSERTED BEFORE THE GUARANTEE.** A crowd that never
## develops a hole would go green with `CloneBalance` deleted, so the first test
## runs the same three minutes with the pass off and requires starvation.
extends GutTest

const SEED := 20260818
const MAP_DATA := "res://data/maps/map_vetraio.tres"
const CROWD := 78
const PLAYERS := 6

## Three minutes at the 30 Hz net tick. The story's own duration.
const MATCH_TICKS := 5400

## A third of a second: nobody loses a clone faster than that at walking speed.
const SAMPLE_EVERY := 10

var _pool: NpcPool
var _hash: SpatialHash
var _map: MapData
var _rng: RandomNumberGenerator
var _balance: CloneBalance
var _watchers: PackedVector3Array
var _short_seen: int = 0
var _suppressed_seen: int = 0
var _supply_total: float = 0.0
var _clone_supply: float = 0.0
var _deficits_seen: int = 0
var _held_seen: int = 0
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


## **SIX PLAYERS IN ONE ZONE** — local depletion is a *local* failure that evenly
## spread players never produce.
func _cluster_the_players() -> void:
	_watchers = PackedVector3Array()
	var here: Vector3 = _map.idle_anchors[0]
	for seat: int in PLAYERS:
		var angle := TAU * float(seat) / float(PLAYERS)
		_watchers.append(here + Vector3(cos(angle) * 3.0, 0.0, sin(angle) * 3.0))


## **PUT THE WHOLE CROWD SOMEWHERE ELSE**, or the cluster starts with enough of
## everybody and the first pass has nothing to do — which reads like a broken rule.
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


## One tick: `CrowdDirector._advance` with navigation replaced by a straight line.
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


## What `CrowdIntent._an_anchor` does: the reservation if there is one, otherwise a
## seeded pick — the whole of layer 4's effect on an NPC.
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
## `[worst, worst_settled, samples, breaches, settle_ticks, late_breaches, late]`.
func _run_the_match(rebalancing: bool) -> Array:
	_deficits_seen = 0
	_held_seen = 0
	_short_seen = 0
	_suppressed_seen = 0
	_supply_total = 0.0
	_clone_supply = 0.0
	var interval := maxi(Tuning.ticks(&"TUN-CROWD-DIRECTOR-INTERVAL"), 1)
	var radius: float = Tuning.crowd.clone_local_radius
	var worst := 99
	var worst_settled := 99
	var samples := 0
	var breaches := 0
	var late_breaches := 0
	# **THE GRACE GDD-03 §6.3 RULE 3 IS NOW SCOPED BY, DERIVED.** This read
	# `interval * 10` and landed within four ticks of the derivation — a multiplier
	# that agrees with the answer is not one that follows it, and the first retune
	# of the radius would have parted them in silence.
	var settle := CloneParity.grace_ticks()
	var late_readings := 0
	for tick: int in range(1, MATCH_TICKS + 1):
		_step_the_crowd()
		_reindex()
		if rebalancing and tick % interval == 0:
			_apply(_balance.rebalance(_hash, _pool, _watchers, CrowdRoster.PLAYABLE))
			_deficits_seen += _balance.deficits_last_pass
			_short_seen += _balance.short_last_pass
			_suppressed_seen += _balance.suppressed_last_pass
			_held_seen += _balance.held_last_pass
		if tick % SAMPLE_EVERY != 0:
			continue
		samples += 1
		# **WHAT THE REGION ACTUALLY SUPPLIES**, against the floor it must hold. A mean
		# below the floor is a density problem no accounting fixes.
		_supply_total += float(_hash.count_within(_watchers[0], radius))
		for persona: StringName in CrowdRoster.PLAYABLE:
			_clone_supply += float(_hash.count_persona(_watchers[0], radius, persona))
		for centre: Vector3 in _watchers:
			for persona: StringName in CrowdRoster.PLAYABLE:
				var seen := _hash.count_persona(centre, radius, persona)
				worst = mini(worst, seen)
				if seen < int(Tuning.crowd.clone_local_min):
					breaches += 1
					if tick > settle:
						late_breaches += 1
				if tick > settle:
					late_readings += 1
					worst_settled = mini(worst_settled, seen)
	return [worst, worst_settled, samples, breaches, settle, late_breaches, late_readings]


func test_the_scenario_actually_starves_without_the_director() -> void:
	# **THE VACUOUS-SUCCESS GUARD, AND IT RUNS FIRST.** If this district never opened
	# a hole, everything below would pass with `CloneBalance` deleted.
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
	# The story's fourth criterion, over the window GDD-03 §6.3 rule 3 binds in.
	var result := _run_the_match(true)
	gut.p(
		(
			(
				"with the director: worst %d overall, %d after the %.1f s grace; "
				+ "%d of %d readings under the floor, %d of %d after it"
			)
			% [
				result[0],
				result[1],
				CloneParity.grace_seconds(),
				result[3],
				result[2] * PLAYERS * 4,
				result[5],
				result[6]
			]
		)
	)
	gut.p(
		(
			(
				"the pass saw %d short pairs: %d already had a clone coming, %d were "
				+ "dispatched. %d fetches, %d holds. SUPPLY "
				+ "%.1f NPCs, %.2f clones of each persona, floor %d"
			)
			% [
				_short_seen,
				_suppressed_seen,
				_deficits_seen,
				_balance.rerouted_total,
				_held_seen,
				_supply_total / maxf(float(result[2]), 1.0),
				_clone_supply / maxf(float(result[2]), 1.0) / float(CrowdRoster.PLAYABLE.size()),
				int(Tuning.crowd.clone_local_min)
			]
		)
	)
	assert_gt(_balance.rerouted_total, 0, "nothing was ever fetched — the rule is inert")
	assert_gt(_balance.held_total, 0, "nothing was ever held; only fetching cannot hold a floor")
	# **THE RULE NEVER IGNORES A BREACH — THAT IS WHAT IT CAN GUARANTEE.** "Zero
	# breaches, always" was asserted here for one map and was never a property of
	# the rule: a fetched clone walks the radius in eighteen seconds, so a player who
	# loses one is short for that walk however promptly help is sent. TDD-08 §5.1.4.
	assert_true(
		_deficits_seen + _suppressed_seen >= _short_seen,
		(
			(
				"the pass saw %d short pairs but only acted on %d and had help coming for "
				+ "%d — some breach was seen and ignored, which is the one thing this rule "
				+ "must never do"
			)
			% [_short_seen, _deficits_seen, _suppressed_seen]
		)
	)
	# And the floor is never breached by more than one, ever: the counterfactual
	# reaches zero, so a worst of 1 is the rule doing most of the work.
	assert_true(
		int(result[0]) >= int(Tuning.crowd.clone_local_min) - 1,
		"a clustered player fell to %d, further below the floor than one walk explains" % result[0]
	)
	# **THE ASSERTION IS ON THE WINDOW THE RULE BINDS IN; THE WHOLE POPULATION IS
	# PRINTED BESIDE IT.** Charging rule 3 for the readings inside its own grace
	# measures `CrowdPlacement`'s arrangement and calls the answer layer 4's.
	# `CloneParity` holds why the grace exists; TDD-08 §11.2.2's perf gate made the
	# same print-the-other-one choice, so nothing looks dropped.
	assert_gt(
		int(result[6]), 100, "too few settled readings for the scoped assertion to mean anything"
	)
	assert_lt(
		int(result[5]) * 100,
		int(result[6]),
		"the floor was under water for more than 1 %% of the readings rule 3 binds on"
	)
	# **THE SETTLED WORST IS REPORTED AND NOT ASSERTED, AND THAT IS NOT A GAP.** It
	# is a minimum over a subset of the readings the assertion above covers, so
	# `worst >= floor - 1` already implies it. It is 1, and the one it is missing is
	# the clone that is walking — which is why US-0047's *always* stays unticked.
	gut.p("settled worst %d against a floor of %d" % [result[1], Tuning.crowd.clone_local_min])


func test_it_reroutes_and_never_respawns_or_repersonas() -> void:
	# The story's second criterion, and GDD-03 §6.3 rule 4 underneath it: a server
	# that changed an identity describes a different city from the one clients drew.
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
	# **THE MECHANICAL HALF OF "MUST NOT READ AS CLONES FOLLOWING PLAYERS".** A clone
	# sent to an anchor stands there like everybody else; sent at a player it
	# converges on whoever is alone, which is the tell.
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
	# move one out of A's radius to fix B's and back again — neither ever holds two.
	var far: Vector3 = _map.idle_anchors[_map.idle_anchors.size() / 2]
	_watchers.append(far)
	var radius: float = Tuning.crowd.clone_local_radius
	# Starved, or a district that already satisfies both clusters fetches nobody and
	# the assertion below is true of nothing.
	_starve_the_district()
	_balance.rebalance(_hash, _pool, _watchers, CrowdRoster.PLAYABLE)
	# **FETCHES ONLY**: a held insider is standing inside somebody's radius already.
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
	# **THE ACCOUNTING, WHICH REPLACES A THROTTLE.** Nine passes per journey, so
	# counting only arrived clones would send nine for a hole one deep — nine Lucerna
	# walking into one market, the leak the story warns about.
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
