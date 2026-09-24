## **THE THREE SEAMS THE REVIEW OF US-0100 FOUND, EACH AS A TEST.**
##
## Every one of them was code that ran, in a suite that was green, doing the wrong
## thing across a boundary no single unit could see — which is this project's most
## expensive recurring shape and the reason two of US-0100's criteria were left
## unticked on the strength of the implementation alone. The review then found a
## defect in **both** of them.
##
## 1. The countdown announced the persona from the *previous* deal, because
##    `ContractSystem.open` announces synchronously and the deal ran after it.
## 2. A lobby join was dealt to, against the rule that nobody has a persona before
##    the countdown — and it spent the match generator, so the seed stopped
##    reproducing the district.
## 3. A departure left `personas_in_use` naming somebody who had gone, so the 2 s
##    pass fetched clones for a persona nobody wore.
extends GutTest

const SEED := 771103
const PLAYERS := [41, 42, 43, 44]

var _consequences: MatchConsequences
var _contracts: ContractSystem
var _crowd: CrowdDirector
var _ctx: MatchContext
var _announced: Dictionary = {}


func before_each() -> void:
	_announced = {}
	_ctx = MatchContext.new()
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	_ctx.tick = 0
	_ctx.phase = MatchPhase.Phase.WARMUP
	for peer: int in PLAYERS:
		var pawn := PawnContext.new()
		pawn.peer_id = peer
		_ctx.pawn_contexts[peer] = pawn
		_ctx.pawns[peer] = null
	_contracts = ContractSystem.new()
	add_child_autofree(_contracts)
	_contracts.setup(_ctx)
	_crowd = CrowdDirector.new()
	add_child_autofree(_crowd)
	_consequences = MatchConsequences.new(_ctx)
	_consequences.contracts = _contracts
	_consequences.crowd = _crowd


## The announcement's own reading, captured at the instant the contract is issued
## rather than afterwards — which is the only moment that can disagree.
func _capture_announcements() -> void:
	for peer: int in PLAYERS:
		_contracts.contract_issued.connect(
			func(hunter: int, contract: int, _reason: int) -> void:
				var target: PawnContext = _ctx.pawn_contexts.get(contract)
				_announced[hunter] = target.persona if target != null else &""
		)
		break


# --- 1. the order at the countdown ----------------------------------------


## **THE PERSONA A HUNTER IS TOLD IS THE PERSONA THE TARGET IS WEARING.** Planted —
## `contracts.open` before `deal_personas` — every entry below reads `&""` on the
## first match, and the *previous* deal on every one after it.
func test_the_countdown_announces_the_persona_it_just_dealt() -> void:
	_capture_announcements()
	_consequences.countdown_opened(PackedInt32Array(PLAYERS), _ctx)
	assert_gt(_announced.size(), 0, "no contract was announced, so nothing was proven")
	for hunter: int in _announced:
		var contract := _contracts.cycle.contract_of(hunter)
		var target: PawnContext = _ctx.pawn_contexts.get(contract)
		assert_false(
			String(_announced[hunter]).is_empty(),
			"hunter %d was told an empty persona: the deal ran after the announcement" % hunter
		)
		assert_eq(
			_announced[hunter],
			target.persona,
			"hunter %d was told a persona the target is not wearing" % hunter
		)


func test_the_countdown_deals_everybody_a_persona() -> void:
	_consequences.countdown_opened(PackedInt32Array(PLAYERS), _ctx)
	for peer: int in PLAYERS:
		var pawn: PawnContext = _ctx.pawn_contexts[peer]
		assert_true(CrowdRoster.PLAYABLE.has(pawn.persona), "peer %d holds nothing" % peer)


# --- 2. the join is gated on the countdown ---------------------------------


## **NOBODY HAS A PERSONA BEFORE THE COUNTDOWN**, which is the rule US-0100 states
## and `PersonaWire.NONE` encodes. A lobby join that was dealt to broke both.
func test_a_lobby_join_is_not_dealt_to() -> void:
	_ctx.phase = MatchPhase.Phase.LOBBY
	var joiner := 45
	var pawn := PawnContext.new()
	pawn.peer_id = joiner
	_ctx.pawn_contexts[joiner] = pawn
	_consequences.peer_joined(joiner)
	assert_eq(pawn.persona, &"", "a persona was dealt in the lobby")


## **AND THE LOBBY JOIN MUST NOT SPEND THE MATCH GENERATOR**, or the recorded seed
## stops reproducing the district — the one property `PersonaDeal` exists to keep,
## and one nothing else in the suite would notice.
func test_a_lobby_join_does_not_spend_the_match_generator() -> void:
	_ctx.phase = MatchPhase.Phase.LOBBY
	for joiner: int in [45, 46, 47]:
		var pawn := PawnContext.new()
		pawn.peer_id = joiner
		_ctx.pawn_contexts[joiner] = pawn
		_consequences.peer_joined(joiner)
	var after_joins := _ctx.rng.state
	var fresh := RandomNumberGenerator.new()
	fresh.seed = SEED
	assert_eq(after_joins, fresh.state, "three lobby joins moved the match generator")


func test_a_join_after_the_countdown_is_dealt_to() -> void:
	for phase: int in [MatchPhase.Phase.WARMUP, MatchPhase.Phase.ACTIVE, MatchPhase.Phase.FINAL]:
		_ctx.phase = phase
		var joiner := 50 + phase
		var pawn := PawnContext.new()
		pawn.peer_id = joiner
		_ctx.pawn_contexts[joiner] = pawn
		_consequences.peer_joined(joiner)
		assert_true(
			CrowdRoster.PLAYABLE.has(pawn.persona),
			"a join in phase %d was left without a persona and so without clones" % phase
		)


## The placeholder loadout is **not** gated: it is a consequence of arriving, not
## of the clock, and gating it would leave a lobby player with no kit at all.
func test_the_placeholder_loadout_is_given_in_the_lobby_too() -> void:
	var abilities := AbilitySystem.new()
	add_child_autofree(abilities)
	_consequences.abilities = abilities
	_ctx.phase = MatchPhase.Phase.LOBBY
	var joiner := 48
	_ctx.pawn_contexts[joiner] = PawnContext.new()
	_consequences.peer_joined(joiner)
	assert_eq(
		abilities.loadout.get(joiner, []).size(), 2, "a lobby player was left with no kit at all"
	)


# --- 3. a departure changes who is in play ---------------------------------


## **THE PERSONA OF SOMEBODY WHO LEFT IS NOT IN PLAY.** Left in the list, the 2 s
## rebalance keeps fetching clones for a persona nobody wears — for the rest of the
## match, while the players still there go under-served.
func test_a_departure_drops_its_persona_from_the_list() -> void:
	_consequences.countdown_opened(PackedInt32Array(PLAYERS), _ctx)
	var lonely := &""
	for candidate: StringName in CrowdRoster.PLAYABLE:
		var wearers := 0
		for peer: int in PLAYERS:
			if _ctx.pawn_contexts[peer].persona == candidate:
				wearers += 1
		if wearers == 1:
			lonely = candidate
			break
	if lonely.is_empty():
		pending("this seed dealt no persona to exactly one player; nothing to drop")
		return
	assert_true(_crowd.personas_in_use.has(lonely), "the fixture never had the persona in play")
	for peer: int in PLAYERS:
		if _ctx.pawn_contexts[peer].persona == lonely:
			_ctx.pawn_contexts.erase(peer)
			break
	_consequences.peer_left(_ctx)
	assert_false(
		_crowd.personas_in_use.has(lonely),
		"the 2 s pass still fetches clones for a persona nobody is wearing"
	)


## A persona two players wear survives one of them leaving.
func test_a_departure_keeps_a_persona_somebody_else_still_wears() -> void:
	for peer: int in PLAYERS:
		_ctx.pawn_contexts[peer].persona = Ids.PERSONA_LUCERNA
	_consequences.refresh_personas_in_use(_ctx)
	_ctx.pawn_contexts.erase(PLAYERS[0])
	_consequences.peer_left(_ctx)
	assert_true(
		_crowd.personas_in_use.has(Ids.PERSONA_LUCERNA), "a persona three players wear was dropped"
	)


## **AN EMPTY LIST IS NEVER WRITTEN.** `test_crowd_perf.gd` empties
## `personas_in_use` on purpose to measure the pass with layer 4 off, so a lobby
## that has not dealt yet must not look like that measurement.
func test_an_empty_district_falls_back_to_every_persona() -> void:
	_ctx.pawn_contexts.clear()
	_consequences.peer_left(_ctx)
	assert_eq(
		_crowd.personas_in_use.size(),
		CrowdRoster.PLAYABLE.size(),
		"an emptied lobby turned the clone pass off rather than falling back"
	)
