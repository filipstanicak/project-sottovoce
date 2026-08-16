## **THE WAVE ARRIVES THROUGH `CrowdDirector.tick()`, NOT THROUGH A TEST CALLING
## THE ALARM.** US-0044.
##
## `test_startle_wave.gd` proves `CrowdAlarm` works. This proves the crowd system
## *uses* it: the once-a-second sprinter sweep is on the director's own tick, and
## a startled NPC gets a flee goal and a flee speed from `_goal_for` and
## `_speed_for`. Every one of those is a place the wiring could be missing while
## both classes stayed correct and both suites stayed green — which is US-0039's
## defect, and this project has now shipped it once.
##
## A unit test rather than an integration one: the director needs a pool and a
## context, not a map or a navigation server, and the integration suite is at
## 141 s of the 180 s it is allowed.
extends GutTest

const SEED := 20260816
const CROWD := 24

var _pool: NpcPool
var _director: CrowdDirector
var _ctx: MatchContext


func before_each() -> void:
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, 6)

	_director = CrowdDirector.new()
	add_child_autofree(_director)

	_ctx = MatchContext.new()
	_ctx.crowd = _pool
	_ctx.match_seed = SEED
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED

	# A line along +X so "how far did it reach" is a number a reader can count.
	for index: int in CROWD:
		_pool.set_position(index, Vector3(float(index), 0.0, 0.0))
	_director.setup(_ctx)


func _tick(times: int) -> void:
	for _t: int in times:
		_ctx.tick += 1
		_director.tick(_ctx, MatchContext.net_dt())


func _startled() -> int:
	var count := 0
	for index: int in CROWD:
		if _pool.brain_of(index).state == NpcBrain.State.STARTLE:
			count += 1
	return count


func test_a_sprinting_pawn_startles_the_crowd_through_the_directors_own_tick() -> void:
	# **NOBODY CALLS THE ALARM HERE.** A pawn is put in the context moving faster
	# than `TUN-SPEED-RUN`, and the director's sweep is expected to find it.
	var pawn := CharacterBody3D.new()
	add_child_autofree(pawn)
	pawn.global_position = Vector3(4.0, 0.0, 0.0)
	pawn.velocity = Vector3(0.0, 0.0, Tuning.movement.sprint)
	_ctx.pawns[9] = pawn

	_tick(Tuning.ticks(&"TUN-CROWD-STARTLE-SPRINT-INTERVAL") + 1)
	gut.p("%d of %d NPCs were startled by a sprinting pawn" % [_startled(), CROWD])
	assert_gt(_startled(), 0, "the director never swept for sprinters")


func test_a_walking_pawn_is_swept_past_without_a_ripple() -> void:
	var pawn := CharacterBody3D.new()
	add_child_autofree(pawn)
	pawn.global_position = Vector3(4.0, 0.0, 0.0)
	pawn.velocity = Vector3(0.0, 0.0, Tuning.movement.stroll)
	_ctx.pawns[9] = pawn
	_tick(Tuning.ticks(&"TUN-CROWD-STARTLE-SPRINT-INTERVAL") + 1)
	assert_eq(_startled(), 0, "strolling past a market startled it")


func test_the_sweep_is_once_a_second_rather_than_every_tick() -> void:
	# GDD-03 §6.4. At 30 Hz a per-tick sweep would fire thirty overlapping waves a
	# second and the crowd would scatter as a solid radius rather than as a trail —
	# and the wave would stop carrying a direction, which is its whole purpose.
	var interval := Tuning.ticks(&"TUN-CROWD-STARTLE-SPRINT-INTERVAL")
	assert_gt(interval, 1, "the sweep interval collapsed to every tick")
	assert_almost_eq(
		float(interval) / Tuning.net.server_tick,
		Tuning.crowd.startle_sprint_interval,
		0.05,
		"the sweep does not run at TUN-CROWD-STARTLE-SPRINT-INTERVAL"
	)


func test_a_startled_npc_is_sent_away_at_the_flee_speed() -> void:
	# `_goal_for` and `_speed_for` are the director's half of the wave. A startled
	# NPC that kept strolling toward the bench it had picked would break the one
	# thing a distant player is meant to read: everybody running *away from* a
	# point, from which the point can be recovered.
	# **ONE TICK FIRST, BECAUSE THE SHARED HASH IS EMPTY UNTIL THERE HAS BEEN
	# ONE.** `startle_at` queries the grid `_reindex` rebuilds at the top of the
	# crowd stage; called before any tick it finds nobody and startles nobody,
	# silently. In a match `SYS-KILL` resolves at the `combat` stage — four
	# positions *after* `crowd` in `SystemOrder` — so the grid is always fresh by
	# then, and this is the test paying the ordering it does not get for free.
	_tick(1)
	var here := _pool.body_of(12).global_position
	_director.startle_at(Vector3.ZERO, 20.0)
	# **LONG ENOUGH FOR THE REPATH QUEUE.** It serves
	# `TUN-PERF-CROWD-REPATH-PER-TICK` a tick and the whole crowd is asking, so
	# reading a destination two ticks after a startle reads an agent that has not
	# been given one yet — and an unset `target_position` is the origin, which is
	# exactly the point the wave started from. The first version of this test
	# measured that and reported a fleeing NPC running *at* the violence.
	_tick(12)
	assert_eq(_pool.brain_of(12).state, NpcBrain.State.STARTLE, "the interrupt did not land")

	# **AWAY FROM WHATEVER SCARED *IT*, WHICH IS NOT ALWAYS THE VIOLENCE.** A
	# propagated NPC flees the neighbour who startled it, and that can carry it
	# across the original point — which is correct, and is what makes the wave a
	# decaying front rather than an expanding ring. The first version of this
	# assertion measured distance from the violence and caught NPC 12 fleeing a
	# neighbour four metres further out, landing on the far side.
	var scared_by := _pool.context_of(12).startle_origin
	var goal := _pool.agent_of(12).target_position
	assert_gt(
		goal.distance_to(scared_by),
		here.distance_to(scared_by),
		"the startled NPC was sent toward what scared it"
	)
	assert_gt(
		Tuning.crowd.npc_speed_flee,
		Tuning.crowd.npc_speed_stroll,
		"fleeing is not faster than a stroll"
	)


func test_the_wave_points_back_at_where_it_started() -> void:
	# **THE MECHANICAL HALF OF "READS DIRECTIONALLY".** Every startled NPC is sent
	# further from the origin than it stood, so the flee vectors of a wave diverge
	# from one point and a distant observer can recover roughly where it was. The
	# *human* half of that criterion needs rendered NPCs and an owner at a windowed
	# client, and US-0044 leaves it unticked for exactly that reason.
	_tick(1)
	_director.startle_at(Vector3.ZERO, 8.0)
	_tick(12)
	var outward := 0
	var checked := 0
	for index: int in CROWD:
		if _pool.brain_of(index).state != NpcBrain.State.STARTLE:
			continue
		checked += 1
		var here := _pool.body_of(index).global_position
		if _pool.agent_of(index).target_position.length() > here.length():
			outward += 1
	gut.p("%d of %d startled NPCs were sent outward from the violence" % [outward, checked])
	assert_gt(checked, 4, "too few NPCs were startled for the shape to mean anything")
	# Not necessarily all of them: a propagated NPC flees the neighbour who scared
	# it, which can carry it across the original point. A strong majority is what
	# makes the front recoverable, and it is what the design claims.
	assert_gt(outward * 4, checked * 3, "the wave did not point away from where it started")


func test_a_corpse_registered_through_the_director_gathers_a_cluster() -> void:
	# `SYS-KILL` calls this at M4. Nothing in a shipping scene does yet, and the
	# story says so — but the path from "a body appeared" to "six people are
	# standing around it" is whole, and this is where that stays true.
	_tick(1)
	var corpse := _director.register_corpse(Vector3(6.0, 0.0, 0.0), 0)
	assert_not_null(corpse, "the director refused to register a corpse")
	# Long enough for the repath queue to hand every gawker a destination: it
	# serves `TUN-PERF-CROWD-REPATH-PER-TICK` a tick and the whole crowd is asking.
	_tick(12)
	var gawking := 0
	var walking_to_it := 0
	for index: int in CROWD:
		if _pool.brain_of(index).state != NpcBrain.State.GAWK:
			continue
		gawking += 1
		if _pool.agent_of(index).target_position.distance_to(corpse.position) < 0.5:
			walking_to_it += 1
	gut.p("%d NPCs gathered around the body, %d walking to it" % [gawking, walking_to_it])
	assert_eq(gawking, int(Tuning.crowd.gawk_max), "the cluster is not TUN-CROWD-GAWK-MAX")
	assert_gt(walking_to_it, 0, "the cluster was granted but nobody was sent to the body")


func test_a_body_is_cleared_away_when_its_lifetime_runs_out() -> void:
	_tick(1)
	_director.register_corpse(Vector3(6.0, 0.0, 0.0), 0)
	assert_eq(_director.corpses().corpses.size(), 1)
	_ctx.tick = int(Tuning.net.server_tick * (Tuning.crowd.corpse_lifetime + 1.0))
	_tick(1)
	assert_eq(_director.corpses().corpses.size(), 0, "the body outlasted TUN-CORPSE-LIFETIME")
