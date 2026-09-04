## **THE WHOLE M4 LOOP, THROUGH THE SHIPPED SERVER.** US-0063, ADR-0016.
##
## **EVERY M4 SYSTEM IS UNIT-TESTED IN ISOLATION AND NOTHING HAD EVER RUN THEM
## TOGETHER.** The M4 gate found that: `test_the_loop_closes.gd` is M2's and proves
## the *transport*; the fifteen stories after it were each proven against their own
## fixture. A stage-ordering mistake between them — the class of defect that gave
## `SYS-DETECTION` a stale crowd, or left `Dead` with no exit — is invisible to
## every one of those fixtures.
##
## This drives one contract from a press to a respawn through
## `server_root.tscn`'s real `MatchDirector`, at the real 30 Hz tick, with the
## crowd live:
##
##   press → validate → commit → contact frame → death → cycle repair →
##   reassign breath → announcement → respawn timer → constrained placement →
##   reinsertion
##
## **NOTHING HERE CALLS A SYSTEM.** Everything is asserted from `MatchContext` and
## the pawn states, because the point is the ordering the director imposes, not
## the rules the units already cover.
extends GutTest

const SERVER_ROOT := "res://scenes/server_root.tscn"
const PLAYERS := 4

var _root: Node
var _hunter: int = -1
var _prey: int = -1


func before_each() -> void:
	_root = (load(SERVER_ROOT) as PackedScene).instantiate()
	# The server disables physics interpolation in `boot.gd`, which this file never
	# runs. Node-local, never the `SceneTree` flag — see `test_server_tick_budget.gd`.
	_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child_autofree(_root)
	for _i: int in 150:
		await get_tree().physics_frame
		if _root.crowd.active_count() > 0:
			break
	for seat: int in PLAYERS:
		Net.peer_joined.emit(9300 + seat)
	# **INSERTIONS ARE BATCHED BY `TUN-CONTRACT-REPAIR-DEBOUNCE` AND THE
	# ANNOUNCEMENT WAITS FOR THE BATCH.** Four ticks is not enough and the symptom
	# is an empty `announced_contracts` that reads as *SYS-CONTRACT never ran*.
	# US-0050's own distinction: the graph is never behind what a player has been
	# told, and is sometimes ahead.
	await _run(maxi(Tuning.ticks(&"TUN-CONTRACT-REPAIR-DEBOUNCE"), 1) + 6)
	_pick_a_hunt()


## **THE AUTOLOAD IS PUT BACK**, or a dangling router reaches whatever runs next.
func after_each() -> void:
	Net.bind_router(null, null)


## Take the cycle's own first edge rather than assuming one. Contracts are dealt
## by `SYS-CONTRACT` on join and the order is not this file's business.
func _pick_a_hunt() -> void:
	for peer: int in _ctx().announced_contracts.keys():
		var contract := int(_ctx().announced_contracts[peer])
		if contract != ContractCycle.NOBODY and contract != peer:
			_hunter = peer
			_prey = contract
			return


func _ctx() -> MatchContext:
	return _root.director.ctx


func _pawn(peer: int) -> PawnContext:
	return _ctx().pawn_contexts.get(peer)


func _run(ticks: int) -> void:
	for _i: int in ticks * 2:
		await get_tree().physics_frame


## Put the hunter behind their contract, inside reach and cone, on open ground,
## and give the lag-comp ring a few ticks to hold both of them there.
func _close_the_distance() -> void:
	var prey := _pawn(_prey)
	var hunter := _pawn(_hunter)
	prey.position = Vector3(60.0, 0.0, 45.0)
	prey.yaw = PI
	hunter.position = prey.position - Vector3(0.0, 0.0, 1.4)
	hunter.yaw = 0.0
	_root.pawns.get_node("Pawn_%d" % _hunter).global_position = hunter.position
	_root.pawns.get_node("Pawn_%d" % _prey).global_position = prey.position


## `TUN-KILL-CORPSE-SPAWN-DELAY`, which is the contact frame. Read here rather
## than written as 27, so retuning it moves the wait with it.
func _contact_ticks() -> int:
	return maxi(Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY"), 1)


func _press_kill() -> void:
	var command := InputCommand.empty(1)
	command.buttons = InputBits.KILL
	# Twice, because the system edge-detects a press in its own map and the first
	# command establishes the previous state.
	_root.director.enqueue_input(_hunter, InputCommand.empty(1))
	_root.director.enqueue_input(_hunter, command)


func test_the_fixture_found_a_real_hunt() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** Every assertion below is satisfied by a test
	# that never identified two players at all.
	assert_ne(_hunter, -1, "no contract was dealt; SYS-CONTRACT did not run on join")
	assert_ne(_prey, _hunter, "a player was given a contract on themselves")
	assert_eq(_ctx().pawn_contexts.size(), PLAYERS, "the lobby did not seat")
	assert_gt(_root.crowd.active_count(), 0, "the district is empty; the crowd never placed")


func test_a_kill_travels_the_whole_loop() -> void:
	_close_the_distance()
	await _run(6)
	_press_kill()
	await _run(2)

	# 1. The killer is committed, and the victim is not dead yet.
	assert_eq(_pawn(_hunter).state_id, PawnStateId.KILL_ANIM, "the press did not commit the killer")
	assert_ne(_pawn(_prey).state_id, PawnStateId.DEAD, "the victim died before the contact frame")

	# 2. The contact frame lands and the victim leaves play.
	#
	# **`Dead` IS NEVER OBSERVABLE FROM OUTSIDE A TICK, AND THAT IS BY DESIGN.**
	# GDD-02 §3.1 gives `Respawning` the entry *"death resolved"* and the exit
	# *"`TUN-RESPAWN-DELAY` 5.0 s"*, and §3's diagram draws `Dead --> Respawning:
	# corpse spawned` — the corpse spawns at the contact frame, so both edges are
	# taken in the same tick. `SYS-KILL` sets `Dead` at the `combat` stage and
	# `SYS-SPAWN` moves it on at `contract`, one stage later.
	#
	# **So this asks `CombatTargets.is_dead`, not a state id.** Sampled once per
	# tick from out here, a `Dead` pawn is never seen: an assertion written against
	# the state reads `Respawning` and looks like a rule that does not work. It cost
	# an hour of the M4 gate and it is the reason both combat systems ask the
	# predicate rather than the state.
	var gone_at := -1
	for step: int in _contact_ticks() + 6:
		await _run(1)
		if gone_at < 0 and CombatTargets.is_dead(_pawn(_prey)):
			gone_at = step
	gut.p(
		(
			"victim left play %d ticks after the press; the contact frame is %d"
			% [gone_at, _contact_ticks()]
		)
	)
	assert_gte(gone_at, 0, "the contact frame never resolved")
	assert_eq(
		_pawn(_prey).state_id,
		PawnStateId.RESPAWNING,
		"the victim is serving the death in Dead; GDD-02 §3.1 puts the 5 s in Respawning"
	)

	# 3. The cycle is repaired in the tick the death resolves, so the victim's own
	#    pursuer inherits and nobody stands on the map holding no contract.
	assert_eq(
		_ctx().announced_contracts.get(_hunter),
		ContractCycle.NOBODY,
		"the killer was pointed at their own corpse instead of at nobody"
	)
	assert_false(_root.contracts.cycle.has(_prey), "the dead player is still in the cycle")
	assert_eq(_root.contracts.cycle.assert_valid(), "", _root.contracts.cycle.assert_valid())

	# 3b. **THE KILL WAS PAID FOR, IN THE SHIPPED SERVER.** US-0064. Every other
	#     assertion about scoring is a unit test over a `ScoreLog` a test built, and
	#     `NpcPool`'s lesson is that a criterion can be true of a class and false of
	#     the game — the pool allocated ninety bodies in tests and none in a match
	#     for a whole milestone, under a ticked criterion.
	var log := _ctx().score
	var paid := ScoreFold.breakdown(log.events(), _hunter)
	assert_true(
		paid.has(Ids.SCORE_CONTRACT), "the killer was not paid SCORE-CONTRACT by the running server"
	)
	# **EXACTLY ONE RUNG OF THE SUSPICION LADDER**, in the shipped server as well as
	# in the pure test (US-0065). The three are a partition of one number, and a
	# kill that paid none of them is the hole the 2026-08-27 re-audit found.
	var rungs := 0
	for kind: StringName in [Ids.SCORE_SILENT, Ids.SCORE_HALFSEEN, Ids.SCORE_RECKLESS]:
		rungs += 1 if paid.has(kind) else 0
	assert_eq(rungs, 1, "a real kill paid %d rungs of the suspicion ladder" % rungs)
	assert_gte(
		ScoreFold.total_for(log.events(), _hunter),
		int(round(Tuning.scoring.contract)),
		"the killer was paid less than one base kill"
	)
	assert_eq(ScoreFold.deaths_of(log.events(), _prey), 1, "no SCORE-DEATH marker was recorded")
	assert_eq(ScoreFold.total_for(log.events(), _prey), 0, "dying cost or paid the victim points")

	# 4. The breath ends and a new contract is announced.
	await _run(maxi(Tuning.ticks(&"TUN-CONTRACT-REASSIGN-DELAY"), 1) + 2)
	var after := int(_ctx().announced_contracts.get(_hunter, ContractCycle.NOBODY))
	assert_ne(after, ContractCycle.NOBODY, "the killer was never given a new contract")
	assert_ne(after, _prey, "the killer was re-pointed at the player they just killed")

	# 5. The victim comes back, placed away from their killer and back in the cycle.
	await _run(SpawnSystem.delay_ticks() + 4)
	assert_ne(_pawn(_prey).state_id, PawnStateId.DEAD, "the victim never left Dead")
	assert_true(_root.contracts.cycle.has(_prey), "the respawned player is not back in the cycle")
	assert_gte(
		_pawn(_prey).position.distance_to(_pawn(_hunter).position),
		Tuning.contract.min_dist_from_any_player,
		"the respawn landed inside somebody's kill range"
	)
	assert_eq(_root.contracts.cycle.assert_valid(), "", _root.contracts.cycle.assert_valid())
	assert_eq(_root.contracts.spawn.fallbacks, 0, "a four-player lobby needed rule 7's fallback")
	gut.p(
		(
			"the loop resolved: %d -> %d, reassigned to %d, victim back in the cycle"
			% [_hunter, _prey, after]
		)
	)


func test_the_crowd_is_told_and_a_corpse_is_registered() -> void:
	# **THE CONSEQUENCES THAT LEAVE `SYS-KILL` THROUGH `server_root`**, rather than
	# through the system's own return value. A kill that repaired the cycle and
	# startled nobody would pass every assertion in the test above — the four entry
	# points US-0060 wired are exactly the kind that look connected and are not.
	assert_eq(
		_root.crowd_director.corpses().corpses.size(), 0, "the district opens with a body in it"
	)
	_close_the_distance()
	await _run(6)
	_press_kill()
	await _run(_contact_ticks() + 4)
	assert_eq(
		_root.crowd_director.corpses().corpses.size(),
		1,
		"the victim fell and CrowdDirector.register_corpse was never reached"
	)
	gut.p("corpse registered; %d onlookers issued" % _root.crowd_director.corpses().watcher_count())


## **THE STUN'S CONTRACT REPAIR IS WIRED, WHICH ONLY THE REAL SCENE CAN SAY.**
## ADR-0019. `test_match_consequences.gd` proves the handler and
## `test_the_stun_costs_the_contract.gd` proves the rule; **neither of them runs
## `server_root.tscn`**, so a `connect` line deleted from the wiring would leave
## both green and the mechanic gone — which is the exact shape that left
## `NET-C2S-ABILITY-REQUEST` with no caller under three completed stories.
##
## **THE SIGNAL IS RAISED RATHER THAN EARNED.** What `SYS-STUN` decides — the tier
## floor, the cone, the reach, the exile — is `test_stun_system.gd`'s and is not
## re-proven here. What is under test is one hop: the server heard a stun land and
## the cycle repaired for it.
func test_a_stun_costs_the_pursuer_the_contract_on_the_real_server() -> void:
	assert_ne(_hunter, -1, "the fixture found no hunt")
	assert_eq(int(_ctx().announced_contracts[_hunter]), _prey, "the premise moved")
	_root.kills.stun.stunned.emit(_prey, _hunter, 360)
	await _run(2)
	assert_eq(
		int(_ctx().announced_contracts.get(_hunter, ContractCycle.NOBODY)),
		ContractCycle.NOBODY,
		"a stunned pursuer kept the contract — is `stunned` wired in `server_root`?"
	)
	# **AND IT STOPS THERE.** Settling through `TUN-CONTRACT-REASSIGN-DELAY` to watch
	# the new prey arrive costs about a hundred physics ticks — three seconds of a
	# suite already over its 180 s budget — to re-prove what
	# `test_the_stun_costs_the_contract.gd` proves in milliseconds. The hop is the
	# only thing here that needs a real server.
