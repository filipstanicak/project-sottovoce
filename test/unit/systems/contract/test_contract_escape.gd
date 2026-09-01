## **AN ESCAPE IS A RESPAWN WITHOUT A DEATH.** ADR-0014, US-0097, GDD-03 §7.3.
##
## The hunter leaves the cycle and is queued for reinsertion through the same two
## `ContractCycle` calls a respawn uses — which is the whole reason the mechanic is
## cheap: `test_contract_cycle_fuzz.gd` already asserts the invariant over 10 000
## events against those two functions, so an escape is covered by construction
## rather than by a second proof.
extends GutTest

const SEED := 20970097
const PLAYERS := [11, 12, 13, 14, 15, 16]

var _system: ContractSystem
var _ctx: MatchContext
var _issued: Array = []


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	_ctx.tick = 0
	_issued = []
	_system = ContractSystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	_system.contract_issued.connect(
		func(peer: int, contract: int, reason: int) -> void:
			_issued.append({"peer": peer, "contract": contract, "reason": reason})
	)
	_system.open(PackedInt32Array(PLAYERS), _ctx)
	_settle()


## Past the debounce window and any hold, so the graph and the announcements agree.
func _settle() -> void:
	for _i: int in Tuning.ticks(&"TUN-CONTRACT-REASSIGN-DELAY") + 20:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func _reasons_for(peer: int) -> Array[int]:
	var out: Array[int] = []
	for entry: Dictionary in _issued:
		if int(entry["peer"]) == peer:
			out.append(int(entry["reason"]))
	return out


func test_the_fixture_is_a_sound_cycle() -> void:
	# **THE PREMISE.** Every assertion below about the cycle surviving is satisfied
	# by a cycle that was already broken.
	assert_eq(_system.cycle.assert_valid(), "", "the fixture did not open a sound cycle")
	assert_eq(_system.cycle.living().size(), PLAYERS.size())


func test_the_hunter_loses_the_contract_at_once() -> void:
	# **THE CLEAR IS IMMEDIATE AND THE NAME WAITS**, which is the shape a kill
	# already has. A Compass still pointing at somebody who escaped is the defect
	# this beat exists to prevent.
	var hunter: int = PLAYERS[0]
	var prey := _system.announced_contract_of(hunter)
	assert_ne(prey, ContractCycle.NOBODY, "the fixture's hunter holds no contract")
	_issued.clear()
	_system.report_escape(hunter, _ctx)
	assert_eq(_system.announced_contract_of(hunter), ContractCycle.NOBODY)
	assert_eq(_reasons_for(hunter), [ContractSystem.Reason.ESCAPE] as Array[int])


func test_the_cycle_is_still_sound_afterwards() -> void:
	_system.report_escape(PLAYERS[0], _ctx)
	_settle()
	assert_eq(_system.cycle.assert_valid(), "", "an escape broke the cycle")
	assert_eq(
		_system.cycle.living().size(), PLAYERS.size(), "the escaped hunter was not reinserted"
	)


func test_the_hunter_is_given_somebody_new_after_the_breath() -> void:
	var hunter: int = PLAYERS[0]
	var prey := _system.announced_contract_of(hunter)
	_issued.clear()
	_system.report_escape(hunter, _ctx)
	_settle()
	var now := _system.announced_contract_of(hunter)
	assert_ne(now, ContractCycle.NOBODY, "the hunter was left with nobody")
	assert_ne(now, prey, "the hunter was handed the same prey straight back")


func test_the_repeat_is_refused_by_the_anti_repeat_history() -> void:
	# **US-0097 NAMED THE WRONG MECHANISM AND GOT THE RIGHT GUARANTEE.** The story
	# says `_choose_index`'s `killer` constraint generalises; it does not — that one
	# forbids a **predecessor**, and what an escape must forbid is the hunter's
	# **successor** being the prey they just lost. What delivers it is
	# `_held_recently(peer, successor)`, which filters at the first relaxation stage
	# from the history written when the contract was issued.
	#
	# Asserted over every player rather than one, because a single seed can avoid
	# the repeat by luck.
	for hunter: int in PLAYERS:
		var prey := _system.announced_contract_of(hunter)
		_system.report_escape(hunter, _ctx)
		_settle()
		assert_ne(
			_system.announced_contract_of(hunter), prey, "%d was re-handed their escapee" % hunter
		)


func test_the_prey_is_untouched_and_still_hunting() -> void:
	# The prey escaped; nothing about *their* contract changed. An escape that
	# disturbed the escapee's own hunt would be paying them twice.
	var hunter: int = PLAYERS[0]
	var prey := _system.announced_contract_of(hunter)
	var theirs := _system.announced_contract_of(prey)
	_system.report_escape(hunter, _ctx)
	_settle()
	assert_eq(_system.announced_contract_of(prey), theirs, "the escapee's own contract moved")


func test_nobody_holds_nobody_once_the_window_closes() -> void:
	# The invariant `SYS-CONTRACT` exists to keep: there is never a tick boundary at
	# which a living player is contractless.
	_system.report_escape(PLAYERS[2], _ctx)
	_settle()
	for peer: int in PLAYERS:
		assert_ne(
			_system.announced_contract_of(peer), ContractCycle.NOBODY, "%d holds nobody" % peer
		)


func test_escaping_somebody_not_in_the_cycle_is_silent() -> void:
	_issued.clear()
	_system.report_escape(999, _ctx)
	assert_eq(_issued.size(), 0, "an escape by a stranger announced something")
