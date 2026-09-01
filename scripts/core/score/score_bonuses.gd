## **WHAT A KILL IS WORTH, AS A PURE FUNCTION OF WHAT WAS TRUE WHEN IT WAS
## PRESSED.** GDD-07 §3, TDD-10 §2, US-0065. PURE.
##
## Facts in, awards out. No world, no context, no clock — which is what lets
## `test_score_bonuses.gd` walk every row of GDD-07 §3's table without standing
## anything up, and what makes the archetypes in `test_score_fold.gd` reproducible
## from the two files together.
##
## **THE SUSPICION LADDER IS EXACTLY ONE RUNG WIDE.** Silent, Halfseen and Reckless
## are three names for three bands of one number, so precisely one of them fires on
## every kill. That is asserted rather than assumed: the hole this closes is the
## one the 2026-08-27 fidelity re-audit found, where a kill at Noticed paid neither
## and being glimpsed scored the same as being caught in the open.
##
## **`SCORE-RECKLESS` FIRES AT ZERO RATHER THAN NOT FIRING.** ADR-0013 neutralised
## the penalty and kept the event, because the feed line saying *you were seen* is
## the half that teaches. An award that pays nothing is not a no-op here.
class_name ScoreBonuses
extends RefCounted


## Every award a kill earns, in feed order. `SCORE-VARIETY` is **not** here: it is
## the one bonus computed at append time, because it counts against the events
## already in the log (TDD-10 §1.4).
static func for_kill(facts: KillScoreFacts, s: ScoringTuning) -> Array[ScoreAward]:
	var awards: Array[ScoreAward] = []
	awards.append(_award(facts, Ids.SCORE_CONTRACT, s.contract))
	awards.append(_for_tier(facts, s))
	for award: ScoreAward in _for_approach(facts, s):
		awards.append(award)
	for award: ScoreAward in _for_the_hunt(facts, s):
		awards.append(award)
	return awards


## A valid stun is worth exactly one base kill. **A statement rather than a
## calculation**: successfully defending yourself is worth as much as successfully
## attacking, and TUNABLES invariant §17.19 pins the two equal so it cannot drift.
static func for_stun(tick: int, stunner: int, target: int, s: ScoringTuning) -> Array[ScoreAward]:
	return [ScoreAward.new(tick, Ids.SCORE_STUN, stunner, target, s.stun)] as Array[ScoreAward]


## **WHAT SURVIVING A HUNT IS WORTH.** US-0097, ADR-0014, GDD-07 §3.
##
## Paid to the **prey**, at the tick their pursuer's bar emptied. `SCORE-ESCAPE` is
## one base kill — invariant 37, the same statement invariant 19 makes about the
## stun: the prey's two non-death outcomes must both price against the kill they
## prevented, or one of them becomes the only one worth playing for.
##
## **`SCORE-CLOSECALL` IS AN ADDITION, NOT A REPLACEMENT.** Escaping from under the
## hunter's nose is the same achievement performed under pressure rather than a
## different achievement, which is why it is half an escape on top rather than a
## larger escape instead.
static func for_escape(
	tick: int, prey: int, hunter: int, close_call: bool, s: ScoringTuning
) -> Array[ScoreAward]:
	var awards: Array[ScoreAward] = [ScoreAward.new(tick, Ids.SCORE_ESCAPE, prey, hunter, s.escape)]
	if close_call:
		awards.append(ScoreAward.new(tick, Ids.SCORE_CLOSECALL, prey, hunter, s.closecall))
	return awards


## **THE ONE RUNG OF THE SUSPICION LADDER THIS KILL LANDED ON.** Never zero rungs
## and never two: the bands are a partition of one number, and a kill that paid
## neither Silent nor Halfseen nor Reckless is the defect that existed until the
## re-audit added the middle rung.
static func _for_tier(facts: KillScoreFacts, s: ScoringTuning) -> ScoreAward:
	if facts.tier >= SuspicionMath.Tier.EXPOSED:
		return _award(facts, Ids.SCORE_RECKLESS, s.reckless)
	if facts.tier >= SuspicionMath.Tier.NOTICED:
		return _award(facts, Ids.SCORE_HALFSEEN, s.halfseen)
	return _award(facts, Ids.SCORE_SILENT, s.silent)


## How the killer arrived: patient, disguised, watching, from above, or hidden.
static func _for_approach(facts: KillScoreFacts, s: ScoringTuning) -> Array[ScoreAward]:
	var awards: Array[ScoreAward] = []
	if facts.patient:
		awards.append(_award(facts, Ids.SCORE_PATIENT, s.patient))
	if facts.masked:
		awards.append(_award(facts, Ids.SCORE_MASKED, s.masked))
	if facts.focus_ticks >= Tuning.ticks(&"TUN-SCORE-FOCUS-WINDOW"):
		awards.append(_award(facts, Ids.SCORE_FOCUS, s.focus))
	if facts.height >= s.fromabove_height:
		awards.append(_award(facts, Ids.SCORE_FROMABOVE, s.fromabove))
	if facts.blended:
		awards.append(_award(facts, Ids.SCORE_BLENDED, s.blended))
	return awards


## What the hunt itself was: long, personal, or delivered by something slow.
static func _for_the_hunt(facts: KillScoreFacts, s: ScoringTuning) -> Array[ScoreAward]:
	var awards: Array[ScoreAward] = []
	var long_hunt := longhunt_points(facts.hunt_ticks, s)
	if long_hunt > 0.0:
		awards.append(_award(facts, Ids.SCORE_LONGHUNT, long_hunt))
	if facts.vendetta:
		awards.append(_award(facts, Ids.SCORE_VENDETTA, s.vendetta))
	if facts.poisoned:
		awards.append(_award(facts, Ids.SCORE_POISONED, s.poisoned))
	return awards


## **TWO RUNGS UNDER ONE ID, WHICH IS WHY THE BREAKDOWN SUMS RATHER THAN COUNTS.**
## The upper rung replaces the lower rather than adding to it — GDD-07 §3 prices
## the +100 step as compensation for the extra 25 seconds of foregone scoring, and
## paying 50 + 150 would compensate twice.
static func longhunt_points(hunt_ticks: int, s: ScoringTuning) -> float:
	var seconds := float(hunt_ticks) / maxf(Tuning.net.server_tick, 1.0)
	if seconds > s.longhunt_t2:
		return s.longhunt_2
	if seconds > s.longhunt_t1:
		return s.longhunt_1
	return 0.0


static func _award(facts: KillScoreFacts, kind: StringName, points: float) -> ScoreAward:
	return ScoreAward.new(facts.tick, kind, facts.killer, facts.victim, points)
