## **THE HANDLER TAKES THE PURSUER, AND NOTHING ELSE IN THE PROJECT COULD SAY SO.**
## `StunSystem.stunned(stunner, target, lockout)` carries two peer ids of the same
## type in adjacent positions, and ADR-0019 makes one of them lose their contract.
## Transposed, the player who successfully read an approach and defended themselves
## is punished for it — and every assertion in
## `test_the_stun_costs_the_contract.gd` still passes, because that file calls
## `report_stun` directly and never sees the wiring.
##
## **THIS IS THE SEAM THIS PROJECT KEEPS FINDING PROVEN BY NOBODY**: the rule is
## tested, the system is tested, and the hop between them is tested here.
##
## Only the two handlers that are pure `SYS-CONTRACT` calls are driven. `killed`
## reaches six systems and a corpse, which is `test_the_m4_loop_resolves.gd`'s.
extends GutTest

const SEED := 20190020
const PLAYERS := [31, 32, 33, 34, 35, 36]

var _consequences: MatchConsequences
var _contracts: ContractSystem
var _ctx: MatchContext


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	_ctx.tick = 0
	_contracts = ContractSystem.new()
	add_child_autofree(_contracts)
	_contracts.setup(_ctx)
	_contracts.open(PackedInt32Array(PLAYERS), _ctx)
	_settle()
	_consequences = MatchConsequences.new(_ctx)
	_consequences.contracts = _contracts


func _settle() -> void:
	for _i: int in Tuning.ticks(&"TUN-CONTRACT-REASSIGN-DELAY") + 20:
		_ctx.tick += 1
		_contracts.tick(_ctx, MatchContext.net_dt())


func test_the_fixture_is_a_sound_cycle() -> void:
	assert_eq(_contracts.cycle.assert_valid(), "", "the fixture did not open a sound cycle")


func test_a_stun_costs_the_pursuer_the_contract_and_not_the_stunner() -> void:
	var pursuer: int = PLAYERS[0]
	var stunner := _contracts.announced_contract_of(pursuer)
	var stunners_own := _contracts.announced_contract_of(stunner)
	assert_ne(stunner, ContractCycle.NOBODY, "the fixture's pursuer holds no contract")

	# The signal's own argument order: (stunner, target, lockout_ticks).
	_consequences.stunned(stunner, pursuer, 360)

	assert_eq(
		_contracts.announced_contract_of(pursuer),
		ContractCycle.NOBODY,
		"the stunned pursuer kept the contract"
	)
	assert_eq(
		_contracts.announced_contract_of(stunner),
		stunners_own,
		"the stunner was punished for defending themselves"
	)


func test_an_escape_costs_the_hunter_the_contract() -> void:
	# The same transposition hazard on `escaped(hunter, prey, close_call)`. The
	# payment half is `KillScoring`'s and is not reached, because `kills` is unset.
	var hunter: int = PLAYERS[1]
	var prey := _contracts.announced_contract_of(hunter)
	var preys_own := _contracts.announced_contract_of(prey)
	_consequences.contracts = _contracts
	_contracts.report_escape(hunter, _ctx)
	assert_eq(
		_contracts.announced_contract_of(hunter),
		ContractCycle.NOBODY,
		"the hunter kept the contract they lost"
	)
	assert_eq(_contracts.announced_contract_of(prey), preys_own, "the escapee's own contract moved")
