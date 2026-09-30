## **A CHASE LIVES ONLY WHILE ITS PREY IS THE HUNTER'S ANNOUNCED CONTRACT.** ADR-0014,
## US-0097, reported from the controls on 2026-09-30.
##
## *"After a kill a new contract is shown, and it changes again a few seconds later."*
## `PursuitBoard.close` claimed from US-0097 on that a kill called it, and nothing
## did: the killer's chase on the prey they had just killed drained and was scored as
## the dead prey **escaping** — the killer lost the contract they had just been told,
## and the corpse was paid `SCORE-ESCAPE`. These tests drive the real
## `ContractSystem` and, for the owner's sequence, the real `PursuitTracker` drain.
extends GutTest

const SEED := 20260930

var _ctx: MatchContext
var _system: ContractSystem
var _issued: Array = []
var _escapes: Array = []


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	_issued = []
	_escapes = []
	_system = ContractSystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	_system.contract_issued.connect(
		func(peer: int, contract: int, _r: int) -> void: _issued.append([peer, contract])
	)
	_system.open(PackedInt32Array([11, 12, 13, 14]), _ctx)
	_run(10)


func _run(ticks: int) -> void:
	for _i: int in ticks:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func _chase(hunter: int) -> void:
	_ctx.pursuit.refresh(
		hunter, _system.announced_contract_of(hunter), Tuning.ticks(&"TUN-PURSUIT-DURATION")
	)


func test_the_killers_chase_on_the_dead_prey_ends() -> void:
	var victim := _system.announced_contract_of(11)
	_chase(11)
	assert_true(_ctx.pursuit.is_chasing(11), "the premise: no chase was open")
	_system.report_death(victim, 11, _ctx)
	assert_false(_ctx.pursuit.is_chasing(11), "the chase outlived the kill")


func test_the_owners_sequence_keeps_the_new_contract() -> void:
	# The report, end to end: a chase open, a kill, then long enough for an orphaned
	# chase to drain. The killer is told one new contract and keeps it; nobody escapes.
	var tracker := PursuitTracker.new()
	tracker.escaped.connect(
		func(hunter: int, prey: int, _c: bool) -> void: _escapes.append([hunter, prey])
	)
	_chase(11)
	_system.report_death(_system.announced_contract_of(11), 11, _ctx)
	_issued = []
	for _i: int in (
		Tuning.ticks(&"TUN-PURSUIT-DURATION") + Tuning.ticks(&"TUN-CONTRACT-REASSIGN-DELAY") + 30
	):
		_ctx.tick += 1
		tracker.begin_pass()
		tracker.drain(_ctx)
		_system.tick(_ctx, MatchContext.net_dt())
	assert_eq(_escapes, [], "the dead prey escaped")
	var named := _issued.filter(func(e: Array) -> bool: return e[0] == 11 and e[1] != 0)
	assert_eq(named.size(), 1, "the killer was told %d contracts after the kill" % named.size())


func test_the_dead_hunters_own_chase_ends() -> void:
	var victim := _system.announced_contract_of(11)
	_chase(victim)
	_system.report_death(victim, 11, _ctx)
	assert_false(_ctx.pursuit.is_chasing(victim), "a dead hunter's chase could still pay an escape")


func test_a_stunned_hunters_chase_ends() -> void:
	# ADR-0019: the prey is paid for the stun; the chase draining later paid them again.
	_chase(12)
	_system.report_stun(12, _ctx)
	assert_false(_ctx.pursuit.is_chasing(12), "the stunned hunter's chase outlived the stun")


func test_only_a_chase_on_somebody_else_is_stale() -> void:
	_ctx.pursuit.refresh(13, 14, 100)
	ContractSystem.end_stale_chase(_ctx, 13, 14)
	assert_true(_ctx.pursuit.is_chasing(13), "a chase on the current contract was ended")
	ContractSystem.end_stale_chase(_ctx, 13, 12)
	assert_false(_ctx.pursuit.is_chasing(13), "a chase on a former contract survived")


func test_a_reassignment_ends_the_chase_on_the_old_prey_and_only_that_one() -> void:
	# A join is inserted into the cycle and takes one hunter's contract; that hunter's
	# chase on the old prey would otherwise drain into an escape and cost them the new
	# one. Everyone whose contract did not move keeps their chase.
	var before := {}
	for hunter: int in [11, 12, 13, 14]:
		before[hunter] = _system.announced_contract_of(hunter)
		_chase(hunter)
	_ctx.pawn_contexts[15] = PawnContext.new()
	_system.report_join(15, _ctx)
	_run(Tuning.ticks(&"TUN-CONTRACT-REPAIR-DEBOUNCE") + 5)
	var moved := 0
	for hunter: int in before:
		if _system.announced_contract_of(hunter) != int(before[hunter]):
			moved += 1
			assert_false(
				_ctx.pursuit.is_chasing(hunter), "%d kept a chase on a former contract" % hunter
			)
		else:
			assert_true(
				_ctx.pursuit.is_chasing(hunter), "%d lost a chase on a current contract" % hunter
			)
	assert_eq(moved, 1, "the premise: a join moved %d contracts, not one" % moved)
