## **A STUNNED PURSUER FAILS THE CONTRACT AND IS DEALT A NEW ONE.** ADR-0019,
## reported from the controls on 2026-09-04 and sourced to the reference, where
## being stunned costs the hunter the target rather than four seconds of it.
##
## **IT IS THE ESCAPE'S OWN REPAIR WITH A DIFFERENT REASON ON IT**, deliberately:
## the clear, the anti-repeat memory, the breath and the reinsertion are one rule
## that `test_contract_cycle_fuzz.gd` already drives over 10 000 events. What this
## file asserts is the half a shared implementation cannot give for free — that the
## reason is the stun's rather than the escape's, and that the punishment lands on
## the pursuer rather than on the player who defended themselves.
extends GutTest

const SEED := 20190019
const PLAYERS := [21, 22, 23, 24, 25, 26]

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
	# **THE PREMISE.** Every assertion below about a cycle surviving a stun is
	# satisfied by a cycle that was already broken.
	assert_eq(_system.cycle.assert_valid(), "", "the fixture did not open a sound cycle")
	assert_eq(_system.cycle.living().size(), PLAYERS.size())


func test_the_pursuer_loses_the_contract_at_once() -> void:
	var pursuer: int = PLAYERS[0]
	var prey := _system.announced_contract_of(pursuer)
	assert_ne(prey, ContractCycle.NOBODY, "the fixture's pursuer holds no contract")
	_issued.clear()
	_system.report_stun(pursuer, _ctx)
	assert_eq(_system.announced_contract_of(pursuer), ContractCycle.NOBODY)


func test_the_reason_is_the_stun_and_not_the_escape() -> void:
	# **THE ONE THING A SHARED IMPLEMENTATION CANNOT GIVE FOR FREE.** `report_stun`
	# and `report_escape` are the same call with one argument different, so a
	# transposed reason changes nothing a player could see in a test that only
	# followed the cycle — and `reason:u8` is what the client is told about why its
	# contract moved.
	_issued.clear()
	_system.report_stun(PLAYERS[0], _ctx)
	assert_eq(_reasons_for(PLAYERS[0]), [ContractSystem.Reason.STUNNED] as Array[int])


func test_the_reason_enum_is_append_only() -> void:
	# `NET-S2C-CONTRACT-ASSIGNED` carries the reason as an index into the enum, so
	# an insertion in the middle silently retells every client a different story.
	assert_eq(int(ContractSystem.Reason.ESCAPE), 4, "ESCAPE moved off wire index 4")
	assert_eq(int(ContractSystem.Reason.STUNNED), 5, "STUNNED was not appended")


func test_the_pursuer_is_given_somebody_new_after_the_breath() -> void:
	var pursuer: int = PLAYERS[0]
	var prey := _system.announced_contract_of(pursuer)
	_system.report_stun(pursuer, _ctx)
	_settle()
	var now := _system.announced_contract_of(pursuer)
	assert_ne(now, ContractCycle.NOBODY, "the stunned pursuer was left with nobody")
	assert_ne(now, prey, "the stunned pursuer was handed their stunner straight back")


func test_the_stunner_keeps_their_own_hunt() -> void:
	# **THE PUNISHMENT IS THE PURSUER'S.** A stun that also disturbed the stunner's
	# own contract would charge the prey for defending themselves — the exact
	# inversion an argument transposed at the call site would produce, and one no
	# assertion about the pursuer can see.
	var pursuer: int = PLAYERS[0]
	var stunner := _system.announced_contract_of(pursuer)
	var theirs := _system.announced_contract_of(stunner)
	_system.report_stun(pursuer, _ctx)
	assert_eq(
		_system.announced_contract_of(stunner), theirs, "the stunner's own contract was cleared"
	)
	# **AND IT IS ASSERTED BEFORE THE BREATH, DELIBERATELY.** The reinsertion after
	# `TUN-CONTRACT-REASSIGN-DELAY` may legitimately land the stunned pursuer
	# directly in front of the stunner, which moves the stunner's contract without
	# anything being wrong — measured, on this file's own seed. Pinning the settled
	# value would assert the seed rather than the rule; what must hold afterwards is
	# only that the stunner still holds somebody.
	_settle()
	assert_ne(
		_system.announced_contract_of(stunner),
		ContractCycle.NOBODY,
		"the stunner was left holding nobody"
	)


func test_nobody_holds_nobody_once_the_window_closes() -> void:
	_system.report_stun(PLAYERS[2], _ctx)
	_settle()
	for peer: int in PLAYERS:
		assert_ne(
			_system.announced_contract_of(peer), ContractCycle.NOBODY, "%d holds nobody" % peer
		)


func test_the_cycle_is_still_sound_afterwards() -> void:
	_system.report_stun(PLAYERS[0], _ctx)
	_settle()
	assert_eq(_system.cycle.assert_valid(), "", "a stun broke the cycle")
	assert_eq(_system.cycle.living().size(), PLAYERS.size(), "the pursuer was not reinserted")


func test_stunning_somebody_not_in_the_cycle_is_silent() -> void:
	_issued.clear()
	_system.report_stun(999, _ctx)
	assert_eq(_issued.size(), 0, "a stun on a stranger announced something")
