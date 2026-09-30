## **EACH ONE-LINE NOTICE REACHES THE ONE PLAYER IT IS ABOUT.** US-0105, ADR-0024,
## `NET-S2C-NOTICE`.
##
## The decisions are tested here and the sends are one line each: *a new pursuer on
## you* goes to the prey of a newly announced contract, never at the countdown's
## first deal; *you have taken the lead* goes to the new sole leader among the
## players still here, and only when points were paid.
extends GutTest

const A := 11
const B := 12
const C := 13

var _ctx: MatchContext
var _announcer: MatchAnnouncer
var _heard: Array = []


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.tick = 100
	for peer: int in [A, B, C]:
		_ctx.slots.assign(peer)
		_ctx.pawn_contexts[peer] = PawnContext.new()
	_announcer = MatchAnnouncer.new(_ctx)


func _pay(actor: int, points: float) -> void:
	_ctx.score.append(
		ScoreAward.new(_ctx.tick, Ids.SCORE_CONTRACT, actor, 0, points), Tuning.match_rules, 1
	)


func test_a_new_contract_tells_its_prey() -> void:
	var told := MatchAnnouncer.pursuer_notice_for(B, ContractSystem.Reason.KILL)
	assert_eq(told, B, "the prey of a new contract was not told")
	for reason: int in [
		ContractSystem.Reason.RESPAWN,
		ContractSystem.Reason.REPAIR,
		ContractSystem.Reason.ESCAPE,
		ContractSystem.Reason.STUNNED
	]:
		assert_eq(MatchAnnouncer.pursuer_notice_for(B, reason), B, "reason %d told nobody" % reason)


func test_the_first_deal_tells_nobody() -> void:
	# Everybody gets a pursuer at the countdown at once: a notice to all is news to none.
	var told := MatchAnnouncer.pursuer_notice_for(B, ContractSystem.Reason.START)
	assert_eq(told, ContractCycle.NOBODY, "the countdown's deal announced a pursuer")


func test_losing_a_contract_tells_nobody() -> void:
	# A hunter announced onto NOBODY has no prey to tell.
	var told := MatchAnnouncer.pursuer_notice_for(ContractCycle.NOBODY, ContractSystem.Reason.KILL)
	assert_eq(told, ContractCycle.NOBODY)


func test_the_first_scorer_takes_the_lead_and_an_overtaker_takes_it_next() -> void:
	_pay(A, 100.0)
	assert_eq(_announcer.lead_taken(), A, "the first scorer was not told")
	_pay(A, 100.0)
	assert_eq(_announcer.lead_taken(), ScoreLead.NOBODY, "holding the lead was announced")
	_pay(B, 300.0)
	assert_eq(_announcer.lead_taken(), B, "the overtaker was not told")


func test_a_player_who_left_does_not_lead_from_outside() -> void:
	_pay(C, 900.0)
	_ctx.pawn_contexts.erase(C)
	_pay(A, 100.0)
	assert_eq(_announcer.lead_taken(), A, "a departed player's score still held the lead")


# --- the hops: the real entry points, then the client's half -----------------


func test_contract_issued_sends_the_pursuer_notice() -> void:
	_announcer.contract_issued(A, B, ContractSystem.Reason.KILL)
	assert_eq(
		_announcer.notices_sent, [[B, NoticeWire.Kind.NEW_PURSUER]], "nothing reached the prey"
	)
	_announcer.contract_issued(C, A, ContractSystem.Reason.START)
	assert_eq(_announcer.notices_sent.size(), 1, "the countdown's deal sent a notice")


func test_the_score_flush_sends_the_lead_and_only_on_points() -> void:
	_pay(A, 100.0)
	_announcer.flush_score()
	assert_eq(_announcer.notices_sent, [[A, NoticeWire.Kind.TOOK_LEAD]], "the lead reached nobody")
	# A quiet tick after the leader leaves announces nobody: taking the lead is scoring.
	_pay(B, 50.0)
	_announcer.flush_score()
	_ctx.pawn_contexts.erase(A)
	_announcer.flush_score()
	assert_eq(_announcer.notices_sent.size(), 1, "a departure handed somebody the lead")


func _on_notice(kind: int) -> void:
	_heard.append(kind)


func test_the_client_puts_a_known_notice_on_the_bus_and_drops_an_unknown_one() -> void:
	var bridge := HudBridge.new()
	add_child_autofree(bridge)
	_heard = []
	EventBus.notice_received.connect(_on_notice)
	Net.events.s2c_notice(NoticeWire.Kind.TOOK_LEAD)
	Net.events.s2c_notice(NoticeWire.Kind.size())
	EventBus.notice_received.disconnect(_on_notice)
	assert_eq(_heard, [NoticeWire.Kind.TOOK_LEAD], "the bus did not carry exactly the known notice")
