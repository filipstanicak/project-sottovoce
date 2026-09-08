## **WHICH TICK A SCORE EVENT IS STAMPED WITH, AND WHY IT IS NOT `ctx.tick`.**
## US-0079.
##
## `ScoreEvent` freezes `TUN-MATCH-FINALPHASE-MULT` from its own tick, against
## `MatchClock.final_opens_at`, which is measured **from the first tick of play**.
## `ctx.tick` is counted from boot. Those were the same number for four milestones
## because `server_root` set `ACTIVE` in `_ready` as a placeholder — so nothing in
## this project could tell the two origins apart, and every award happened to be
## right by an accident that `SYS-MATCH` removes.
##
## **THE LOAD-BEARING TEST IS `test_a_kill_in_the_warmups_shadow_pays_a_single
## _score`**, which is the whole defect in one arrangement: a boot tick past the
## boundary and a match tick short of it. Every other assertion here would pass over
## a codebase that had never heard of `match_tick`.
extends GutTest

const KILLER := 11
const VICTIM := 12

var _ctx: MatchContext
var _scoring: KillScoring


func before_each() -> void:
	_ctx = MatchContext.new()
	_scoring = KillScoring.new()


## A match that began `started_at` ticks after boot, now `into` ticks old.
func _a_match_that_began_late(started_at: int, into: int) -> void:
	_ctx.active_started_at = started_at
	_ctx.tick = started_at + into
	_ctx.phase = MatchPhase.Phase.ACTIVE


func _only_event() -> ScoreEvent:
	var events := _ctx.score.events()
	assert_eq(events.size(), 1, "expected exactly one event, got %d" % events.size())
	return events[0] if events.size() == 1 else null


func test_a_stun_is_stamped_with_the_match_tick() -> void:
	_a_match_that_began_late(500, 40)
	_scoring.pay_for_stun(_ctx, KILLER, VICTIM)
	assert_eq(_only_event().tick, 40, "the stun was stamped with the boot tick")


func test_an_escape_is_stamped_with_the_match_tick() -> void:
	_a_match_that_began_late(500, 40)
	_scoring.pay_for_escape(_ctx, VICTIM, KILLER, false)
	assert_eq(_ctx.score.events()[0].tick, 40, "the escape was stamped with the boot tick")


func test_the_facts_a_kill_is_judged_on_carry_the_match_tick() -> void:
	_a_match_that_began_late(500, 40)
	assert_eq(_scoring.facts_at(_ctx, KILLER, VICTIM).tick, 40, "the kill facts read from boot")


## **THE ONE THAT WOULD HAVE CAUGHT IT.** The lobby and the countdown push the whole
## match later than the boot tick by however long players took to arrive — which is
## unbounded — so a boot tick can sit deep inside the Final Contract's arithmetic
## while the match is thirty seconds old. Stamped from `ctx.tick`, this stun pays
## **double** in the first minute of play.
func test_a_kill_in_the_warmups_shadow_pays_a_single_score() -> void:
	var rules := Tuning.match_rules
	var opens := MatchClock.final_opens_at(rules)
	_a_match_that_began_late(opens, 30)
	assert_gt(_ctx.tick, opens, "the fixture did not put the BOOT tick past the boundary")
	_scoring.pay_for_stun(_ctx, KILLER, VICTIM)
	assert_eq(
		_only_event().multiplier,
		1.0,
		"a stun thirty ticks into the match paid the Final Contract multiplier"
	)


## And the boundary still arrives, measured from the right origin.
func test_a_kill_past_the_boundary_still_pays_double() -> void:
	var rules := Tuning.match_rules
	_a_match_that_began_late(500, MatchClock.final_opens_at(rules))
	_scoring.pay_for_stun(_ctx, KILLER, VICTIM)
	assert_eq(_only_event().multiplier, rules.finalphase_mult, "the Final Contract never paid")


## **A KILL PRESSED BEFORE THE BOUNDARY AND LANDING AFTER IT PAYS 1x**, US-0079's
## sixth criterion and the story's own named test.
##
## The two moments are 0.9 s apart — `TUN-KILL-CORPSE-SPAWN-DELAY` — and the
## multiplier is frozen from whichever is on the event. The bonuses were earned when
## the player committed, so they pay single; the **death marker** is stamped at the
## fall, which is inside the Final Contract, and it pays nothing either way. That the
## two disagree here is the criterion rather than a wrinkle: it is what stops a hunter
## banking a press against a boundary they can see coming.
func test_a_kill_pressed_before_the_boundary_and_landing_after_it_pays_once() -> void:
	var rules := Tuning.match_rules
	var opens := MatchClock.final_opens_at(rules)
	_a_match_that_began_late(400, opens + 27)
	var facts := KillScoreFacts.new()
	facts.tick = opens - 1
	facts.killer = KILLER
	facts.victim = VICTIM
	facts.tier = SuspicionMath.Tier.ANONYMOUS
	_scoring.pay_for_kill(_ctx, facts)
	var paid := 0
	for event: ScoreEvent in _ctx.score.events():
		if event.kind == Ids.SCORE_DEATH:
			assert_eq(event.tick, _ctx.match_tick(), "the death was not stamped at the fall")
			continue
		paid += 1
		assert_eq(
			event.multiplier, 1.0, "%s paid the Final Contract for a press before it" % event.kind
		)
	assert_gt(paid, 0, "the kill paid nothing at all — an empty loop agrees with everything")


## Before a match has reached `ACTIVE` there is no origin, and the answer is zero
## rather than a negative tick — a stun during the countdown pays once.
func test_a_match_that_has_not_begun_stamps_zero() -> void:
	_ctx.tick = 900
	_ctx.phase = MatchPhase.Phase.WARMUP
	assert_eq(_ctx.match_tick(), 0, "a match that has not begun has a match tick")
	_scoring.pay_for_stun(_ctx, KILLER, VICTIM)
	assert_eq(_only_event().multiplier, 1.0, "a stun in the countdown paid double")
