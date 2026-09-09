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


## **THE MATCH ENDS AND THE RESULTS GO OUT, AND NOTHING ELSE IN THIS PROJECT COULD
## SAY SO.** US-0077.
##
## `MatchAnnouncer.results_payload` is tested against its own fixture in
## `test_match_end_wire.gd`, and `MatchSystem` is tested against its own in
## `test_match_system.gd`. **Neither runs the two together**, so a `phase_changed`
## handler that forgot the `RESULTS` branch would leave both green and the results
## screen would simply never arrive — which is exactly what left
## `NET-C2S-ABILITY-REQUEST` with no caller under three completed stories, and
## `ContractSystem.open` with no caller under five.
##
## **IT RAISES THE TRANSITION RATHER THAN EARNING IT.** What `MatchSystem` decides is
## that file's; this stops at the one hop.
func test_the_results_are_sent_when_the_phase_reaches_results() -> void:
	_consequences.announcer = MatchAnnouncer.new(_ctx)
	_consequences.phase_changed(MatchPhase.Phase.ACTIVE, MatchPhase.Phase.FINAL, _ctx)
	assert_eq(
		_consequences.announcer.results_sent, 0, "the results went out before the match ended"
	)
	_consequences.phase_changed(MatchPhase.Phase.FINAL, MatchPhase.Phase.RESULTS, _ctx)
	assert_eq(_consequences.announcer.results_sent, 1, "the match ended and nobody was told")


## **THE SKIP PRESS REACHES THE RULE, AND NOTHING ELSE IN THIS PROJECT COULD SAY SO.**
## US-0077.
##
## `RpcRouter` authorises and emits; `MatchSystem` counts. **Neither runs the other**,
## so a handler that dropped the press would leave both green and the results screen
## would simply never end early — the shape that left `NET-C2S-ABILITY-REQUEST` with no
## caller under three completed stories.
func test_a_skip_press_reaches_the_match() -> void:
	var match_state := MatchSystem.new()
	match_state.setup(_ctx, Tuning.match_rules)
	match_state.players = 1
	_ctx.phase = MatchPhase.Phase.RESULTS
	_consequences.match_state = match_state
	_consequences.skip_requested(PLAYERS[0])
	assert_eq(match_state.skips(), 1, "the press never reached the rule")


## And it does not fall over when nothing is wired, which is every fixture that
## builds this class for one of the other handlers.
func test_a_skip_press_with_no_match_system_is_survivable() -> void:
	_consequences.match_state = null
	_consequences.skip_requested(PLAYERS[0])
	assert_true(true, "a skip press with no SYS-MATCH took the server down")
