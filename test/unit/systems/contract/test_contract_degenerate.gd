## **WHAT THE SYSTEM DOES WHEN THE MATCH RUNS OUT OF PLAYERS.** US-0050, GDD-03
## §7.4, GDD-07 §5.
##
## Below `TUN-CONTRACT-MIN-CYCLE-LENGTH` the cycle is still *valid* and no longer a
## *game*: at two players the contracts are mutual, hunter equals prey, and the
## asymmetry the whole design rests on is gone. At one there is nobody to hunt.
##
## **BOTH ARE HANDLED RATHER THAN PREVENTED**, because preventing them means
## refusing a death. What the system owes is that it does not error, does not
## announce nonsense, and does not go quiet in a way that leaves a client pointing
## at somebody who is gone.
extends GutTest

const SEED := 20260821

var _ctx: MatchContext
var _system: ContractSystem
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


func _record(peer: int, contract: int, reason: int) -> void:
	_issued.append({"peer": peer, "contract": contract, "reason": reason})


func _run(ticks: int) -> void:
	for _step: int in ticks:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func _settle() -> void:
	_run(Tuning.ticks(&"TUN-CONTRACT-REPAIR-DEBOUNCE") + 2)


func test_two_players_hunt_each_other_and_are_both_told() -> void:
	_system.open(PackedInt32Array([11, 12, 13, 14]), _ctx)
	_system.contract_issued.connect(_record)
	_system.report_disconnect(11, _ctx)
	_system.report_disconnect(12, _ctx)
	_settle()
	assert_eq(_system.cycle.size(), 2, "the teardown did not reach two players")
	assert_eq(_system.cycle.assert_valid(), "", "a two-cycle is valid and was called invalid")
	assert_eq(_system.contract_of(13), 14, "13 does not hunt 14")
	assert_eq(_system.contract_of(14), 13, "14 does not hunt 13")
	# **BOTH ARE TOLD.** A degenerate cycle is still a cycle, and a player whose
	# contract silently stopped updating would be hunting a corpse.
	assert_eq(_system.announced_contract_of(13), 14, "13 was not told")
	assert_eq(_system.announced_contract_of(14), 13, "14 was not told")


func test_one_survivor_is_issued_no_contract_and_nothing_errors() -> void:
	_system.open(PackedInt32Array([11, 12, 13]), _ctx)
	_system.contract_issued.connect(_record)
	_system.report_disconnect(11, _ctx)
	_system.report_disconnect(12, _ctx)
	_settle()
	assert_eq(_system.cycle.size(), 1, "the teardown did not reach one player")
	assert_eq(_system.contract_of(13), ContractCycle.NOBODY, "the last player was given a contract")
	assert_eq(_system.cycle.assert_valid(), "", "a one-player cycle is not an invalid one")
	# Ticking on is the case that would crash if anything divided by the cycle size.
	_run(90)
	assert_eq(_system.cycle.size(), 1, "the lone survivor changed")


func test_an_empty_match_ticks_without_erroring() -> void:
	_system.open(PackedInt32Array([11, 12]), _ctx)
	_system.report_disconnect(11, _ctx)
	_system.report_disconnect(12, _ctx)
	_run(30)
	assert_eq(_system.cycle.size(), 0, "the cycle is not empty")
	assert_eq(_system.cycle.assert_valid(), "", "an empty cycle is not an invalid one")


func test_a_match_that_recovers_issues_contracts_again() -> void:
	# **THE HALF THAT WOULD ROT UNNOTICED.** A system that handled the descent and
	# then stayed quiet on the way back up would look perfectly correct in every
	# teardown test and leave a rejoining lobby with no contracts at all.
	_system.open(PackedInt32Array([11, 12, 13, 14]), _ctx)
	_system.report_disconnect(11, _ctx)
	_system.report_disconnect(12, _ctx)
	_settle()
	_system.contract_issued.connect(_record)
	_system.report_join(11, _ctx)
	_system.report_join(12, _ctx)
	_settle()
	assert_eq(_system.cycle.size(), 4, "the lobby did not refill")
	assert_eq(_system.cycle.assert_valid(), "", "the refilled cycle is invalid")
	for peer: int in [11, 12]:
		assert_ne(
			_system.announced_contract_of(peer), ContractCycle.NOBODY, "%d was never told" % peer
		)
	assert_gt(_issued.size(), 0, "nobody was told anything on the way back up")
