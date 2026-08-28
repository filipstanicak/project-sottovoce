## **EVERY ROW OF GDD-07 §3, FIRING ON ITS OWN CONDITION AND NOT OTHERWISE.**
## US-0065, TDD-10 §2.
##
## Facts in, awards out — so the whole table is walkable without a server, a world
## or a clock. What is asserted for each bonus is **both directions**: it appears
## when its condition holds, and it is absent when the condition is one step the
## other side of the line. A test that only ever checks the first is satisfied by a
## bonus that always fires.
extends GutTest

const KILLER := 9
const VICTIM := 4

var _s: ScoringTuning
var _facts: KillScoreFacts


func before_each() -> void:
	_s = Tuning.scoring
	# The plainest possible kill: Anonymous, ran there, saw nothing, no history.
	_facts = KillScoreFacts.new()
	_facts.tick = 500
	_facts.killer = KILLER
	_facts.victim = VICTIM
	_facts.tier = SuspicionMath.Tier.ANONYMOUS


func _kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for award: ScoreAward in ScoreBonuses.for_kill(_facts, _s):
		out.append(award.kind)
	return out


func _points_for(kind: StringName) -> float:
	for award: ScoreAward in ScoreBonuses.for_kill(_facts, _s):
		if award.kind == kind:
			return award.points
	return -1.0


func _rung_total() -> float:
	var paid := 0.0
	for kind: StringName in [Ids.SCORE_SILENT, Ids.SCORE_HALFSEEN, Ids.SCORE_RECKLESS]:
		paid += maxf(_points_for(kind), 0.0)
	return paid


# ------------------------------------------------------- the tier ladder ---


func test_exactly_one_rung_of_the_suspicion_ladder_fires() -> void:
	# **THE HOLE THE 2026-08-27 RE-AUDIT FOUND.** Silent paid 200 at Anonymous,
	# Reckless 0 at Exposed, and a kill at Noticed paid neither — so being glimpsed
	# and being caught in the open scored identically. Three names, three bands of
	# one number, and the bands are a partition.
	var rungs: Array[StringName] = [Ids.SCORE_SILENT, Ids.SCORE_HALFSEEN, Ids.SCORE_RECKLESS]
	for tier: int in [
		SuspicionMath.Tier.ANONYMOUS, SuspicionMath.Tier.NOTICED, SuspicionMath.Tier.EXPOSED
	]:
		_facts.tier = tier
		var fired := 0
		for kind: StringName in _kinds():
			if kind in rungs:
				fired += 1
		assert_eq(fired, 1, "tier %d fired %d rungs of the ladder" % [tier, fired])


func test_the_ladder_pays_less_the_more_visible_you_were() -> void:
	_facts.tier = SuspicionMath.Tier.ANONYMOUS
	var anonymous := _rung_total()
	_facts.tier = SuspicionMath.Tier.NOTICED
	var noticed := _rung_total()
	_facts.tier = SuspicionMath.Tier.EXPOSED
	var exposed := _rung_total()
	assert_gt(anonymous, noticed, "Anonymous did not beat Noticed")
	assert_gt(noticed, exposed, "Noticed did not beat Exposed")


func test_reckless_fires_at_zero_rather_than_not_firing() -> void:
	# **ADR-0013 NEUTRALISED THE PENALTY AND KEPT THE EVENT**, because the feed line
	# saying *you were seen* is the half that teaches. An award worth nothing is not
	# a no-op here, and deleting it would delete the lesson.
	_facts.tier = SuspicionMath.Tier.EXPOSED
	assert_has(_kinds(), Ids.SCORE_RECKLESS, "Exposed no longer produces a feed line")
	assert_eq(_points_for(Ids.SCORE_RECKLESS), 0.0, "there is a points penalty in the game again")


# ------------------------------------------------------------ the kill ---


func test_a_valid_kill_always_pays_the_unit_of_account() -> void:
	# `SYS-KILL` only ever kills the announced contract, so every kill that reaches
	# scoring is a contract kill by construction.
	for tier: int in [SuspicionMath.Tier.ANONYMOUS, SuspicionMath.Tier.EXPOSED]:
		_facts.tier = tier
		assert_has(_kinds(), Ids.SCORE_CONTRACT)
	assert_eq(_points_for(Ids.SCORE_CONTRACT), _s.contract)


func test_the_plainest_kill_pays_only_two_things() -> void:
	# The premise for every "and not otherwise" below: with no condition met, the
	# only awards are the unit and one rung of the ladder.
	assert_eq(_kinds().size(), 2, "a bare kill paid %s" % [_kinds()])


# --------------------------------------------------------- the approach ---


func test_patient_masked_and_blended_each_fire_only_on_their_own_fact() -> void:
	for row: Array in [
		["patient", Ids.SCORE_PATIENT, _s.patient],
		["masked", Ids.SCORE_MASKED, _s.masked],
		["blended", Ids.SCORE_BLENDED, _s.blended],
	]:
		var field := str(row[0])
		var kind := row[1] as StringName
		assert_does_not_have(_kinds(), kind, "%s fired with %s false" % [kind, field])
		_facts.set(field, true)
		assert_has(_kinds(), kind, "%s did not fire with %s true" % [kind, field])
		assert_eq(_points_for(kind), float(row[2]), "%s paid the wrong amount" % kind)
		_facts.set(field, false)


func test_focus_needs_the_whole_window() -> void:
	var window := Tuning.ticks(&"TUN-SCORE-FOCUS-WINDOW")
	assert_gt(window, 1, "the focus window is under two ticks; this proves nothing")
	_facts.focus_ticks = window - 1
	assert_does_not_have(_kinds(), Ids.SCORE_FOCUS, "Focus paid one tick short of the window")
	_facts.focus_ticks = window
	assert_has(_kinds(), Ids.SCORE_FOCUS, "Focus did not pay at exactly the window")


func test_from_above_needs_the_height_and_is_signed() -> void:
	# **SIGNED, AND THAT IS THE ASSERTION THAT MATTERS.** An absolute difference
	# would pay a player for being killed from a roof rather than for killing from
	# one, and both readings satisfy "at least three metres apart".
	_facts.height = _s.fromabove_height - 0.01
	assert_does_not_have(_kinds(), Ids.SCORE_FROMABOVE, "From Above paid just under the height")
	_facts.height = _s.fromabove_height
	assert_has(_kinds(), Ids.SCORE_FROMABOVE, "From Above did not pay at the height")
	_facts.height = -_s.fromabove_height * 2.0
	assert_does_not_have(_kinds(), Ids.SCORE_FROMABOVE, "From Above paid for killing UPWARDS")


# ---------------------------------------------------------- the hunt ---


func test_long_hunt_has_two_rungs_and_the_upper_replaces_the_lower() -> void:
	# **NOT 50 + 150.** GDD-07 §3 prices the +100 step as compensation for the extra
	# 25 seconds of foregone scoring; paying both would compensate twice.
	var rate: float = Tuning.net.server_tick
	_facts.hunt_ticks = int((_s.longhunt_t1 - 1.0) * rate)
	assert_does_not_have(_kinds(), Ids.SCORE_LONGHUNT, "Long Hunt paid under the first rung")
	_facts.hunt_ticks = int((_s.longhunt_t1 + 1.0) * rate)
	assert_eq(_points_for(Ids.SCORE_LONGHUNT), _s.longhunt_1, "wrong rung just past the first")
	_facts.hunt_ticks = int((_s.longhunt_t2 + 1.0) * rate)
	assert_eq(_points_for(Ids.SCORE_LONGHUNT), _s.longhunt_2, "wrong rung just past the second")


func test_only_one_long_hunt_award_is_ever_made() -> void:
	_facts.hunt_ticks = int((_s.longhunt_t2 + 30.0) * Tuning.net.server_tick)
	var rungs := 0
	for kind: StringName in _kinds():
		if kind == Ids.SCORE_LONGHUNT:
			rungs += 1
	assert_eq(rungs, 1, "a long hunt paid both rungs, compensating the same seconds twice")


func test_vendetta_fires_only_on_the_flag() -> void:
	assert_does_not_have(_kinds(), Ids.SCORE_VENDETTA)
	_facts.vendetta = true
	assert_eq(_points_for(Ids.SCORE_VENDETTA), _s.vendetta)


func test_poisoned_is_implemented_and_dormant() -> void:
	# ASM-0016: no MVP ability triggers it, and `ABIL-NIGHTSHADE` is post-MVP.
	# **Implemented and tested rather than absent**, so the day an ability wants it
	# there is nothing to design — and the dormancy is asserted where somebody
	# looking for it will find it.
	assert_does_not_have(_kinds(), Ids.SCORE_POISONED, "something in the MVP poisons")
	_facts.poisoned = true
	assert_eq(_points_for(Ids.SCORE_POISONED), _s.poisoned, "the bonus is not implemented")


# --------------------------------------------------------------- stun ---


func test_a_stun_is_worth_exactly_one_base_kill() -> void:
	# **A STATEMENT, NOT A CALCULATION** (GDD-07 §3): successfully defending
	# yourself is worth as much as successfully attacking. TUNABLES §17.19 pins the
	# two equal so it cannot drift, and this asserts the rule reads that pin rather
	# than a number of its own.
	var awards := ScoreBonuses.for_stun(120, KILLER, VICTIM, _s)
	assert_eq(awards.size(), 1, "a stun paid more than one thing")
	assert_eq(awards[0].kind, Ids.SCORE_STUN)
	assert_eq(awards[0].points, _s.contract, "a stun is no longer worth one base kill")
	assert_eq(awards[0].actor, KILLER, "the stun was paid to the wrong player")


func test_death_awards_and_deducts_nothing() -> void:
	# GDD-07 §3's last row, and US-0065's own criterion. **A points penalty would
	# make a trailing player's position unrecoverable** and push them toward the
	# safest, most passive play — the opposite of what a trailing player should do.
	assert_eq(_s.death_penalty, 0.0, "dying costs points again")
	var log := ScoreLog.new()
	log.mark_death(500, VICTIM, KILLER, Tuning.match_rules)
	assert_eq(ScoreFold.total_for(log.events(), VICTIM), 0, "the victim was charged for dying")
	assert_eq(ScoreFold.total_for(log.events(), KILLER), 0, "the killer was paid by the marker")


func test_every_award_carries_the_initiation_tick() -> void:
	# **THE TENSE IS THE WHOLE POINT.** Every bonus is judged at the moment the
	# player pressed, so every event must be stamped there — the multiplier is
	# frozen from it, and a contact-frame stamp would pay a pre-boundary kill double.
	_facts.patient = true
	_facts.vendetta = true
	for award: ScoreAward in ScoreBonuses.for_kill(_facts, _s):
		assert_eq(award.tick, _facts.tick, "%s was stamped at another moment" % award.kind)
		assert_eq(award.actor, KILLER)
		assert_eq(award.subject, VICTIM)
