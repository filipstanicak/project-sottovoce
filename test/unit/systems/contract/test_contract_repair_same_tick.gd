## **NO PLAYER IS CONTRACTLESS AT A TICK BOUNDARY.** US-0050, TDD-10 §5, GDD-03 §7.4.
##
## `SystemOrder` puts `combat` before `contract` precisely so the cycle is repaired
## in the tick the death resolves. This asserts the consequence rather than the
## ordering — the ordering is `test_system_tick_order.gd`'s.
##
## **THE REPAIR IS IMMEDIATE AND THE ANNOUNCEMENT IS NOT**, and that distinction is
## what lets US-0050 ask for repair in the same tick *and* for events inside
## `TUN-CONTRACT-REPAIR-DEBOUNCE` to batch. A removal is not a rebuild: deleting a
## node from a cycle leaves a cycle, so it can be applied at once and cannot
## conflict with another removal.
extends GutTest

const SEED := 20260821

var _ctx: MatchContext
var _system: ContractSystem


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	_ctx.tick = 0
	_system = ContractSystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	_system.open(PackedInt32Array([11, 12, 13, 14, 15, 16]), _ctx)


func _everybody_has_a_contract(where: String) -> void:
	for peer: int in _system.cycle.living():
		assert_ne(
			_system.contract_of(peer),
			ContractCycle.NOBODY,
			"%s: peer %d holds no contract" % [where, peer]
		)
	assert_eq(_system.cycle.assert_valid(), "", "%s: the cycle is invalid" % where)


func test_a_kill_is_repaired_before_the_tick_ends() -> void:
	_everybody_has_a_contract("at match start")
	var victim: int = _system.cycle.living()[2]
	var killer := _system.cycle.pursuer_of(victim)
	var inherited := _system.contract_of(victim)
	# The `combat` stage, mid-tick.
	_system.report_death(victim, killer, _ctx)
	# **THE ASSERTION THAT MATTERS**, made before `contract` has even ticked: the
	# graph is already sound, so there is no instant at which anybody is adrift.
	_everybody_has_a_contract("immediately after the death")
	assert_false(_system.cycle.has(victim), "the victim is still in the cycle")
	assert_eq(
		_system.contract_of(killer), inherited, "the killer did not inherit the victim's contract"
	)
	_system.tick(_ctx, MatchContext.net_dt())
	_everybody_has_a_contract("at the tick boundary")


func test_five_deaths_in_a_row_never_leave_a_gap() -> void:
	# One at a time, checking between each. A rule that holds at six and at two can
	# still have a hole at four.
	while _system.cycle.size() > 2:
		var victim: int = _system.cycle.living()[0]
		_system.report_death(victim, _system.cycle.pursuer_of(victim), _ctx)
		_everybody_has_a_contract("after a death down to %d" % _system.cycle.size())
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())
		_everybody_has_a_contract("at the boundary at %d" % _system.cycle.size())


func test_a_double_kill_in_one_tick_leaves_a_sound_cycle() -> void:
	# The case GDD-03 §7.3's debounce exists for. Two removals in one tick cannot
	# conflict — that is the cycle's whole advantage — so what the debounce protects
	# is the announcement, not the graph.
	var order := _system.cycle.living()
	_system.report_death(order[1], _system.cycle.pursuer_of(order[1]), _ctx)
	_system.report_death(order[3], _system.cycle.pursuer_of(order[3]), _ctx)
	assert_eq(_system.cycle.size(), 4, "two deaths did not remove two players")
	_everybody_has_a_contract("after a double kill")


func test_a_disconnect_is_a_death_that_does_not_respawn() -> void:
	var leaver: int = _system.cycle.living()[4]
	var pursuer := _system.cycle.pursuer_of(leaver)
	var inherited := _system.contract_of(leaver)
	_system.report_disconnect(leaver, _ctx)
	_everybody_has_a_contract("after a disconnect")
	assert_eq(
		_system.contract_of(pursuer),
		inherited,
		"the pursuer was punished for their target quitting"
	)


func test_the_graph_is_never_behind_the_announcement() -> void:
	# **THE ONE DIRECTION THAT WOULD BE A DEFECT.** The graph may be ahead of what a
	# player has been told — that is the breath. It must never be behind, because a
	# client told to hunt somebody the server no longer has a contract for is a
	# compass pointing at a stranger.
	var victim: int = _system.cycle.living()[1]
	_system.report_death(victim, _system.cycle.pursuer_of(victim), _ctx)
	for step: int in 200:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())
		for peer: int in _system.cycle.living():
			var told := _system.announced_contract_of(peer)
			if told == ContractCycle.NOBODY:
				continue
			assert_true(
				_system.cycle.has(told),
				"tick %d: peer %d was told to hunt %d, who is not living" % [step, peer, told]
			)
