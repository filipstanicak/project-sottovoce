## **THE CHASE: HOW LONG IT LASTS, AND HOW FAR THE HUNTER CAN SEE.**
## TUNABLES.md §17 invariants 34-36, ADR-0014, US-0097.
##
## **SPLIT OUT OF `TuningInvariants` ON 2026-08-29**, when adding these took that
## file to 408 lines. Third split of the same file and the third by subject rather
## than by size: tech is how the game is *transmitted*, score is what it *pays*,
## this is how long you keep a contract once you have been seen, and what is left
## is how the game *plays*.
##
## **ALL THREE ARE RELATIONS TO A COMPASS VALUE**, which is why they group: two
## against `TUN-COMPASS-WARN-RADIUS` — the radius that opens a chase — and one
## against `TUN-COMPASS-LOCK-CONE`, the cone whose raycast the pursuit test rides.
## `TuningInvariants.check()` calls this, so there is still exactly one entry point.
class_name TuningInvariantsPursuit
extends RefCounted


static func check(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	e.append_array(_pursuit_window(p))
	e.append_array(_pursuit_sight(p))
	return e


## 34. **ESCAPING MUST NEVER REQUIRE SPEED**, which is the one of the three that
## is about *time*. Added 2026-08-29 (US-0097, ADR-0014).
static func _pursuit_window(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 34. ESCAPING MUST NEVER REQUIRE SPEED. The chase has to outlast the walk out
	# of warning range at civilian pace, or the only reliable escape is to run —
	# and running costs anonymity, so a tuning value would invert design law 1 with
	# nothing anywhere reporting it.
	#
	# **IT FIRED ON ITS FIRST RUN, AGAINST US-0097's OWN PROPOSED VALUE.** The
	# quotient is 10.7143 and the story wrote 10.7, which asks the prey for
	# 1.402 m/s — fractionally faster than a blend walk, in exactly the direction
	# this forbids. The value went up rather than the tolerance out: an epsilon wide
	# enough to admit it is an epsilon wide enough to admit the next one too.
	var walk_out := p.compass.warn_radius / maxf(p.movement.blend_walk, 0.001)
	if p.contract.pursuit_duration < walk_out:
		e.append(
			(
				"34. contract.pursuit_duration (%.2f) must be >= warn_radius / blend_walk (%.2f)"
				% [p.contract.pursuit_duration, walk_out]
			)
		)
	return e


## 35 and 36. **THE TWO THAT ARE ABOUT SIGHT**, and each fails silently in its own
## direction — one drains a chase the hunter is winning, the other doubles the
## raycast budget with no symptom but frame time.
static func _pursuit_sight(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 35. A CHASE MUST BE SUSTAINABLE AT THE RANGE IT OPENS AT. It begins when a
	# careless hunter comes within `warn_radius`; if sight reached less far the bar
	# would drain while the hunter stood exactly where they triggered it.
	if p.contract.pursuit_sight_range < p.compass.warn_radius:
		e.append(
			(
				"35. contract.pursuit_sight_range (%.1f) must be >= compass.warn_radius (%.1f)"
				% [p.contract.pursuit_sight_range, p.compass.warn_radius]
			)
		)
	# 36. THE PURSUIT CONE MUST BE THE WIDER OF THE TWO, OR IT CANNOT RIDE THE
	# LOCK'S RAYCAST. `SYS-DETECTION` spends one query per watching hunter and both
	# questions are about the same ordered pair; inverted, the pursuit needs a
	# second cast per chase against a budget of 2-6.
	if p.contract.pursuit_sight_cone < p.compass.lock_cone:
		e.append(
			(
				"36. contract.pursuit_sight_cone (%.1f) must be >= compass.lock_cone (%.1f)"
				% [p.contract.pursuit_sight_cone, p.compass.lock_cone]
			)
		)
	return e
