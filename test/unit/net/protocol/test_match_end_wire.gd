## **`NET-S2C-MATCH-END`, AND THE ONE ASSERTION THAT MAKES US-0077's THIRD CRITERION
## STRUCTURAL.** US-0077.
##
## *"The breakdown is derived from the SAME fold as the totals, so they cannot
## disagree."* A wire that sent totals **and** a breakdown would satisfy that
## criterion in prose and break it the first time either arithmetic moved. This one
## sends the log, so `test_the_client_folds_to_the_servers_own_totals` is the
## criterion rather than a claim about it: the same `ScoreFold` runs on both sides of
## the socket, over the same events.
extends GutTest

const ALICE := 401
const BOB := 402

var _ctx: MatchContext
var _announcer: MatchAnnouncer
var _rules: MatchTuning


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.active_started_at = 0
	_rules = Tuning.match_rules
	_ctx.slots.assign(ALICE)
	_ctx.slots.assign(BOB)
	_announcer = MatchAnnouncer.new(_ctx)


func _slot(peer: int) -> int:
	return _ctx.slots.slot_of(peer)


## Two kills for Alice and one stun for Bob, appended the way a live match appends.
func _play_a_short_match() -> void:
	var scoring := KillScoring.new()
	for at: int in [120, 900]:
		var facts := KillScoreFacts.new()
		facts.tick = at
		facts.killer = ALICE
		facts.victim = BOB
		facts.tier = SuspicionMath.Tier.ANONYMOUS
		_ctx.tick = at
		scoring.pay_for_kill(_ctx, facts)
	_ctx.tick = 1500
	scoring.pay_for_stun(_ctx, BOB, ALICE)


func _payload() -> PackedByteArray:
	return _announcer.results_payload({ALICE: [Ids.ABIL_CINDERFALL, Ids.ABIL_LUNGE], BOB: []})


func test_the_fixture_actually_scored_something() -> void:
	# **THE PREMISE.** Every assertion below folds this log; an empty one would let
	# the whole file agree with anything.
	_play_a_short_match()
	assert_gt(_ctx.score.events().size(), 4, "the fixture scored almost nothing")


## **THE ONE THIS FILE EXISTS FOR.** Server-side totals, client-side totals, one fold.
func test_the_client_folds_to_the_servers_own_totals() -> void:
	_play_a_short_match()
	var report := MatchEndWire.unpack(_payload(), _rules)
	assert_not_null(report, "the payload did not decode at all")
	for peer: int in [ALICE, BOB]:
		assert_eq(
			ScoreFold.total_for(report.events, _slot(peer)),
			ScoreFold.total_for(_ctx.score.events(), peer),
			"the client's total for slot %d is not the server's" % _slot(peer)
		)


## And the breakdown comes out of the same array, so it cannot be a second sum.
func test_the_breakdown_sums_to_the_total() -> void:
	_play_a_short_match()
	var report := MatchEndWire.unpack(_payload(), _rules)
	var slot := _slot(ALICE)
	var by_kind := ScoreFold.breakdown(report.events, slot)
	assert_gt(by_kind.size(), 1, "the breakdown has nothing in it to sum")
	var sum := 0
	for kind: StringName in by_kind:
		sum += int(by_kind[kind])
	assert_eq(
		sum, ScoreFold.total_for(report.events, slot), "the breakdown does not sum to the total"
	)


## **THE MULTIPLIER IS NOT ON THE WIRE AND SURVIVES ANYWAY.** `ScoreEvent` derives it
## from the event's own tick, so a client rebuilding events from the log reaches the
## same number the server paid — from the same `MatchTuning`, which the handshake
## refuses a peer for not holding.
func test_the_final_contract_multiplier_survives_a_round_trip() -> void:
	var scoring := KillScoring.new()
	_ctx.tick = MatchClock.final_opens_at(_rules) + 60
	scoring.pay_for_stun(_ctx, ALICE, BOB)
	var report := MatchEndWire.unpack(_payload(), _rules)
	assert_eq(report.events.size(), 1, "the fixture scored the wrong number of events")
	assert_eq(
		report.events[0].multiplier,
		_rules.finalphase_mult,
		"a Final Contract award decoded at a single score"
	)


func test_every_id_on_the_wire_is_a_slot_and_never_a_peer() -> void:
	_play_a_short_match()
	var report := MatchEndWire.unpack(_payload(), _rules)
	for event: ScoreEvent in report.events:
		assert_lt(event.actor_id, 8, "an actor arrived as a peer id rather than a slot")
		assert_lt(event.subject_id, 8, "a subject arrived as a peer id rather than a slot")


func test_the_kits_and_the_patience_arrive_per_slot() -> void:
	_ctx.score_windows.sample_tier(ALICE, SuspicionMath.Tier.ANONYMOUS)
	_ctx.score_windows.sample_tier(ALICE, SuspicionMath.Tier.ANONYMOUS)
	_ctx.score_windows.sample_tier(BOB, SuspicionMath.Tier.NOTICED)
	var report := MatchEndWire.unpack(_payload(), _rules)
	assert_eq(int(report.anonymous_ticks[_slot(ALICE)]), 2, "Alice's patience did not arrive")
	assert_eq(int(report.anonymous_ticks[_slot(BOB)]), 0, "Bob was credited patience he never had")
	assert_eq(
		(report.kits[_slot(ALICE)] as Array).size(), 2, "Alice's kit did not survive the wire"
	)
	assert_eq(
		(report.kits[_slot(ALICE)] as Array)[1], Ids.ABIL_LUNGE, "the kit came back in a new order"
	)


## **SECONDS RATHER THAN TICKS, FROM THE RULES RATHER THAN FROM A LITERAL 30.**
func test_patience_reads_back_in_seconds() -> void:
	for _i: int in int(_rules.tick_rate):
		_ctx.score_windows.sample_tier(ALICE, SuspicionMath.Tier.ANONYMOUS)
	var report := MatchEndWire.unpack(_payload(), _rules)
	assert_almost_eq(
		report.anonymous_seconds(_slot(ALICE), _rules), 1.0, 0.001, "a tick rate was hardcoded"
	)


## **A SHORT PACKET IS DROPPED WHOLE, NOT PARTLY READ.** `StreamPeerBuffer` answers a
## read past the end with zero, so an unchecked decode builds a scoreboard out of
## slot 0 scoring nothing — shown at the one moment players are reading the game's
## own account of what they just did.
func test_a_truncated_payload_decodes_to_nothing() -> void:
	_play_a_short_match()
	var full := _payload()
	assert_gt(full.size(), MatchEndWire.ROW, "the fixture produced no rows to truncate")
	for cut: int in [1, MatchEndWire.ROW, full.size() - 1]:
		assert_null(
			MatchEndWire.unpack(full.slice(0, full.size() - cut), _rules),
			"a payload %d bytes short still decoded" % cut
		)


func test_an_empty_payload_decodes_to_nothing() -> void:
	assert_null(MatchEndWire.unpack(PackedByteArray(), _rules), "an empty payload decoded")


## **`SCORE-DEATH` TRAVELS HERE WHERE THE FEED WITHHOLDS IT**, and that is the
## difference between the two messages rather than an oversight: the feed's question
## is *what was I just paid for* and a death pays nothing, while US-0077's fifth
## criterion is *your killers by name and count* — which is exactly this row.
func test_the_death_markers_travel_where_the_feed_withholds_them() -> void:
	_play_a_short_match()
	var report := MatchEndWire.unpack(_payload(), _rules)
	assert_eq(
		ScoreFold.deaths_of(report.events, _slot(BOB)),
		2,
		"the results screen cannot see who killed whom"
	)
