## The economy half of TUNABLES.md §17's cross-field invariants: what the game
## **pays**, and the shape of the curve it pays along.
##
## **SPLIT OUT OF `TuningInvariants` ON 2026-08-27**, when adding invariant 32 took
## that file past 400 lines. It is the same division `TuningInvariantsTech` was made
## on and it is by subject rather than by size: tech is how the game is
## *transmitted*, this is what it *pays*, and what is left behind is how it *plays*.
## `TuningInvariants.check()` calls this, so there is still exactly one entry point.
class_name TuningInvariantsScore
extends RefCounted


static func check(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	e.append_array(_ladder_floor(p))
	e.append_array(_ladder_shape(p))
	e.append_array(_payouts(p))
	e.append_array(_patience(p))
	e.append_array(_escape(p))
	return e


## 18. **THE LADDER'S TOP RUNG PAYS AT LEAST THREE BASE KILLS** — the floor under
## the total. 32 below is about the steps; this one is about the height.
static func _ladder_floor(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 18. THE STEALTH LADDER'S TOP RUNG PAYS AT LEAST THREE BASE KILLS.
	#
	# **AMENDED 2026-08-26, ADR-0013.** It used to read
	# `blended > patient > silent`, which encoded a hierarchy the reference does
	# not have. What the thesis needs is not an ordering between the three but a
	# floor under the pair: with no penalty for recklessness left in the game,
	# paying three base kills for an unseen approach is the whole of what makes
	# patience correct. How the 300 splits between the instantaneous half and the
	# sustained one is ours to tune; the sum is not.
	if p.scoring.silent + p.scoring.patient < 3.0 * p.scoring.contract:
		e.append(
			(
				(
					"18. silent (%.0f) + patient (%.0f) must be >= 3x contract (%.0f) — "
					+ "the stealth ladder is the only thing left enforcing the thesis"
				)
				% [p.scoring.silent, p.scoring.patient, p.scoring.contract]
			)
		)
	return e


## 32. **AND THE LADDER IS A STAIRCASE, NOT A CLIFF** — the shape of the steps.
## Split from 18 on 2026-08-27 for the length guard, on a real seam: one is about
## what the top rung totals, the other about whether the rungs below it exist.
static func _ladder_shape(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 32. **THE STEALTH LADDER IS A STAIRCASE, NOT A CLIFF.** Added 2026-08-27 by the
	# fidelity re-audit, which found the middle rung missing: `SCORE-SILENT` paid 200
	# at Anonymous and `SCORE-RECKLESS` paid 0 at Exposed, and a kill at **Noticed**
	# paid neither — so being glimpsed and being caught in the open scored the same,
	# which is the one comparison the suspicion economy most needs to make.
	#
	# **THE `> 0` CLAUSE IS THE LOAD-BEARING ONE.** Every ordering above it is still
	# satisfied by a halfseen of exactly zero, which is precisely the cliff this
	# invariant exists to forbid. `>=` here would restore the defect and stay green.
	if p.scoring.halfseen <= 0.0:
		e.append(
			(
				(
					"32. halfseen (%.0f) must be > 0 — a zero rung restores the cliff the "
					+ "re-audit found, and every ordering check still passes over it"
				)
				% p.scoring.halfseen
			)
		)
	elif not (p.scoring.silent > p.scoring.halfseen and p.scoring.halfseen > p.scoring.reckless):
		e.append(
			(
				(
					"32. the stealth ladder must descend strictly: silent (%.0f) > "
					+ "halfseen (%.0f) > reckless (%.0f)"
				)
				% [p.scoring.silent, p.scoring.halfseen, p.scoring.reckless]
			)
		)
	return e


## 19. **A STUN OUTSCORES A BASE KILL.** Amended 2026-09-03 (ADR-0018) from `==`:
## the reference pays 200 against a base assassination's 100. **A floor, not a
## ratio** — a stun must still lose to a well-made kill, and `== 2 x` would pin a
## number no source gives.
static func _payouts(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	if p.scoring.stun <= p.scoring.contract:
		e.append(
			(
				"19. scoring.stun (%.0f) must EXCEED scoring.contract (%.0f)"
				% [p.scoring.stun, p.scoring.contract]
			)
		)
	return e


## 23. PATIENCE MUST BE A LINE YOU CAN CROSS. At or below stroll it is
## unearnable — a player at their cruising speed has already lost it — and at or
## above run it is unlosable without committing, which is the one thing it exists
## to price. It inherited 3.4 m/s from the deprecated Jog rung, which is why the
## threshold outlived the state.
static func _patience(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	var low := p.movement.stroll
	var high := p.movement.run
	var speed := p.scoring.patient_speed
	if not (low < speed and speed < high):
		var text := "23. scoring.patient_speed (%.2f) must sit strictly between "
		e.append((text + "stroll (%.2f) and run (%.2f)") % [speed, low, high])
	return e


## 37. **SURVIVING A HUNT IS WORTH WHAT ENDING ONE IS.** Added 2026-08-29 with
## `ABIL`-free US-0097, and it is invariant 19's sentence about a second verb: the
## prey has exactly two outcomes that are not a death — stun the hunter, or lose
## them — and both must price against the kill they prevented. Let either fall
## below a base kill and it becomes the outcome nobody plays for, which collapses
## design law 5 back onto the one tooth ADR-0013 had already blunted.
static func _escape(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	if not is_equal_approx(p.scoring.escape, p.scoring.contract):
		e.append(
			(
				"37. scoring.escape (%.0f) must EQUAL scoring.contract (%.0f)"
				% [p.scoring.escape, p.scoring.contract]
			)
		)
	return e
