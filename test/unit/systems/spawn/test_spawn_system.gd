## **`SYS-SPAWN` END TO END: DEATH, DELAY, PLACEMENT, PROTECTION.** US-0062,
## TDD-10 §6, GDD-02 §3.
##
## The pure rule is exercised in `test/unit/core/spawn/`. What is here is the
## lifecycle: that `Dead` finally has an exit, that the five seconds are counted
## in the right tick domain, that the spawn point is chosen when the timer expires
## rather than when the player died, and that the player comes back briefly
## untargetable.
extends GutTest

const VICTIM := 101
const KILLER := 102
const OTHER := 103

var _contracts: ContractSystem
var _spawn: SpawnSystem
var _ctx: MatchContext
var _machines: Array[PawnStateMachine] = []
var _returns: Array = []


func before_each() -> void:
	_machines.clear()
	_returns = []
	_ctx = MatchContext.new()
	_ctx.tick = 500
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = 7
	_ctx.map = _a_map()
	_contracts = ContractSystem.new()
	add_child_autofree(_contracts)
	_contracts.setup(_ctx)
	_spawn = _contracts.spawn
	_spawn.respawned.connect(func(p: int, at: Vector3, k: int) -> void: _returns.append([p, at, k]))


func after_each() -> void:
	for machine: PawnStateMachine in _machines:
		machine.free()
	_machines.clear()


## Six points on a line, 40 m apart — the same arithmetic fixture the pure test
## uses, so a failure here is about the lifecycle rather than about geometry.
func _a_map() -> MapData:
	var map := MapData.new()
	var points: Array[Vector3] = []
	for i: int in 6:
		points.append(Vector3(float(i) * 40.0, 0.0, 0.0))
	map.spawn_points = points
	return map


func _place(peer: int, at: Vector3) -> PawnContext:
	var machine := PawnStateMachine.new()
	for script: GDScript in PawnStateMachine.REGISTERED:
		machine.register(script.new())
	_machines.append(machine)
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, 0.0)
	machine.spawn_into(pawn, PawnStateId.IDLE)
	_ctx.pawn_contexts[peer] = pawn
	_ctx.pawn_machines[peer] = machine
	return pawn


func _a_lobby() -> void:
	_place(VICTIM, Vector3(20.0, 0.0, 0.0))
	_place(KILLER, Vector3(0.0, 0.0, 0.0))
	_place(OTHER, Vector3(200.0, 0.0, 0.0))
	_contracts.open(PackedInt32Array([VICTIM, KILLER, OTHER]), _ctx)


## A death, resolved the way `SYS-KILL` resolves one: the victim is put into
## `Dead` through the machine, then the death is reported.
func _kill() -> void:
	var machine := _ctx.pawn_machines[VICTIM] as PawnStateMachine
	machine.transition(_ctx.pawn_contexts[VICTIM] as PawnContext, PawnStateId.DEAD, 3)
	_spawn.report_death(VICTIM, KILLER, _ctx)


func _advance(ticks: int = 1) -> void:
	for _i: int in ticks:
		_ctx.tick += 1
		_contracts.tick(_ctx, MatchContext.net_dt())


func _state(peer: int) -> StringName:
	return (_ctx.pawn_contexts[peer] as PawnContext).state_id


# ------------------------------------------------------------ the exit ----


func test_dead_finally_has_an_exit() -> void:
	# **THE WHOLE POINT OF THIS STORY.** Until `Respawning` was registered the
	# graph's only edge out of `Dead` led to a state that did not exist, so a
	# killed player stayed dead for the rest of the match.
	_a_lobby()
	_kill()
	assert_eq(_state(VICTIM), PawnStateId.DEAD, "the fixture did not kill anybody")
	_advance()
	assert_eq(_state(VICTIM), PawnStateId.RESPAWNING, "Dead did not lead anywhere")
	_advance(SpawnSystem.delay_ticks() + 1)
	assert_eq(_state(VICTIM), PawnStateId.IDLE, "the player never came back")


func test_the_delay_is_counted_in_net_ticks() -> void:
	# **TRAP 9.** `SYS-SPAWN` ticks at 30 Hz; `step_ticks` would give a 2.5 s death,
	# and both numbers are plausible integers. The two converters must disagree or
	# this assertion proves nothing.
	assert_ne(
		Tuning.ticks(&"TUN-RESPAWN-DELAY"),
		Tuning.step_ticks(&"TUN-RESPAWN-DELAY"),
		"the two tick domains agree, so this test cannot tell them apart"
	)
	_a_lobby()
	_kill()
	var due := _ctx.tick + SpawnSystem.delay_ticks()
	_advance(SpawnSystem.delay_ticks() - 1)
	assert_eq(_state(VICTIM), PawnStateId.RESPAWNING, "the player came back a tick early")
	assert_eq(_spawn.return_tick_of(VICTIM), due, "the recorded return tick is not the tuned one")
	_advance()
	assert_eq(_state(VICTIM), PawnStateId.IDLE, "the player never came back")


func test_the_player_is_put_on_a_declared_spawn_point() -> void:
	_a_lobby()
	_kill()
	_advance(SpawnSystem.delay_ticks() + 1)
	assert_eq(_returns.size(), 1, "no respawn was announced")
	var at: Vector3 = _returns[0][1]
	assert_true(_ctx.map.spawn_points.has(at), "placed at %v, which is not a spawn point" % at)
	assert_eq((_ctx.pawn_contexts[VICTIM] as PawnContext).position, at, "the pawn was not moved")


func test_the_point_is_chosen_when_the_timer_expires_and_not_when_they_died() -> void:
	# **FIVE SECONDS IS LONG ENOUGH FOR THE LOBBY TO MOVE.** The killer stands at
	# the far end at the moment of death and walks to the near end during the wait;
	# the placement must respect where they are *now*.
	_a_lobby()
	var killer := _ctx.pawn_contexts[KILLER] as PawnContext
	killer.position = Vector3(200.0, 0.0, 0.0)
	_kill()
	_advance(SpawnSystem.delay_ticks() - 1)
	killer.position = Vector3(200.0, 0.0, 0.0)
	_advance(2)
	assert_eq(_returns.size(), 1, "no respawn to check")
	var at: Vector3 = _returns[0][1]
	assert_gte(
		at.distance_to(killer.position),
		Tuning.contract.respawn_min_dist_from_killer,
		"placed %.1f m from where the killer actually is" % at.distance_to(killer.position)
	)


func test_suspicion_is_reset_through_the_tunable() -> void:
	# `PawnContext.reset_for_spawn` writes a literal `0.0`, which *agrees* with
	# `TUN-RESPAWN-SUSPICION` and does not read it — so before US-0062 the tunable
	# had no reader at all and retuning it would have changed nothing.
	_a_lobby()
	(_ctx.pawn_contexts[VICTIM] as PawnContext).suspicion = 95.0
	_kill()
	_advance(SpawnSystem.delay_ticks() + 1)
	assert_almost_eq(
		(_ctx.pawn_contexts[VICTIM] as PawnContext).suspicion,
		Tuning.contract.suspicion,
		0.001,
		"a respawned player did not come back at TUN-RESPAWN-SUSPICION"
	)


func test_they_come_back_briefly_untargetable() -> void:
	_a_lobby()
	_kill()
	_advance(SpawnSystem.delay_ticks() + 1)
	assert_true(_ctx.lockouts.is_protected(VICTIM, _ctx.tick), "TUN-RESPAWN-INVULN was never armed")
	_advance(SpawnSystem.invuln_ticks())
	assert_false(
		_ctx.lockouts.is_protected(VICTIM, _ctx.tick),
		"the invulnerability outlived TUN-RESPAWN-INVULN"
	)


func test_the_protection_is_shorter_than_the_delay() -> void:
	# The tunable's own note: *"long enough to be abusable would be worse than
	# none"*. If these two ever crossed, a player could die on purpose to buy a
	# longer shield than the death cost them.
	assert_lt(
		Tuning.contract.respawn_invuln,
		Tuning.contract.respawn_delay,
		"the spawn shield now outlasts the respawn delay"
	)


func test_the_cycle_is_repaired_in_the_tick_they_are_placed() -> void:
	# **`SYS-SPAWN` TICKS FIRST INSIDE `SYS-CONTRACT`**, so there is never a tick in
	# which somebody stands on the map holding no contract.
	_a_lobby()
	_kill()
	_advance(SpawnSystem.delay_ticks() + 1)
	assert_true(_contracts.cycle.has(VICTIM), "the respawned player is not back in the cycle")
	assert_eq(_contracts.cycle.assert_valid(), "", _contracts.cycle.assert_valid())


func test_a_departing_peer_leaves_no_pending_respawn() -> void:
	# ENet reuses peer ids. An inherited timer would place a brand-new joiner
	# somewhere they did not ask to be, five seconds after connecting.
	_a_lobby()
	_kill()
	assert_eq(_spawn.pending_count(), 1)
	_spawn.forget(VICTIM)
	assert_eq(_spawn.pending_count(), 0, "the departed peer's respawn survived them")
	_advance(SpawnSystem.delay_ticks() + 1)
	assert_eq(_returns.size(), 0, "a peer that left was placed anyway")


func test_the_placement_counter_reports_the_fallback_separately() -> void:
	# A lobby in which every respawn falls back is one where the anti-camp analysis
	# has stopped holding, and that is a number somebody can read.
	_a_lobby()
	_kill()
	_advance(SpawnSystem.delay_ticks() + 1)
	assert_eq(_spawn.placements, 1, "the placement was not counted")
	assert_eq(_spawn.fallbacks, 0, "an ordinary respawn was recorded as a fallback")
