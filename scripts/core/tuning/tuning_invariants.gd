## The 23 cross-field invariants from TUNABLES.md §17.
##
## A value can be inside its own documented range and still be wrong, because
## what matters is its relationship to another value. Invariant 1 is the clearest
## case: blend-walk and the NPC stroll are both legal anywhere in 1.2–1.6, and
## the game is broken unless they are the SAME number.
##
## Separated from TuningProfile so the list reads as a list. Each check returns a
## sentence naming both operands and their actual values — an invariant failure
## that says only "invariant 7 failed" costs the reader the same lookup twice.
class_name TuningInvariants
extends RefCounted


static func check(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	e.append_array(_speed_ladder(p))
	e.append_array(_fov_ladder(p))
	e.append_array(_crowd_relations(p))
	e.append_array(_suspicion_and_tiers(p))
	e.append_array(_combat(p))
	e.append_array(_compass(p))
	e.append_array(_abilities(p))
	e.append_array(_net(p))
	e.append_array(_scoring(p))
	e.append_array(_perf(p))
	return e


static func _speed_ladder(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 1. THE MOST IMPORTANT INVARIANT IN THE FILE. A player at blend-walk must be
	# indistinguishable from an NPC by motion alone.
	if not is_equal_approx(p.movement.blend_walk, p.crowd.npc_speed_stroll):
		e.append(
			(
				(
					"1. blend_walk (%.3f) must EQUAL crowd.npc_speed_stroll (%.3f) — "
					+ "a player who moves at a different speed from the crowd is readable "
					+ "from motion alone, and anonymity is dead"
				)
				% [p.movement.blend_walk, p.crowd.npc_speed_stroll]
			)
		)
	# 2. The speed ladder is monotonic.
	var ladder: Array[Array] = [
		["blend_walk", p.movement.blend_walk],
		["stroll", p.movement.stroll],
		["run", p.movement.run],
		["sprint", p.movement.sprint],
	]
	for i: int in range(ladder.size() - 1):
		if float(ladder[i][1]) >= float(ladder[i + 1][1]):
			e.append(
				(
					"2. speed ladder not monotonic: %s (%.3f) >= %s (%.3f)"
					% [ladder[i][0], ladder[i][1], ladder[i + 1][0], ladder[i + 1][1]]
				)
			)
	return e


## 21, 22. The FOV ladder mirrors the speed ladder and must run the same way.
## GDD-02 §4.2: inverted, the lens would still be a channel — it would simply
## tell a sprinting player they were calm, which is worse than silence.
static func _fov_ladder(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	var ladder: Array[Array] = [
		["fov_blend", p.camera.fov_blend],
		["fov_stroll", p.camera.fov_stroll],
		["fov_run", p.camera.fov_run],
		["fov_sprint", p.camera.fov_sprint],
	]
	for i: int in range(ladder.size() - 1):
		if float(ladder[i][1]) >= float(ladder[i + 1][1]):
			e.append(
				(
					(
						"21. FOV ladder not monotonic: %s (%.1f) >= %s (%.1f) — "
						+ "speed would read as calm"
					)
					% [ladder[i][0], ladder[i][1], ladder[i + 1][0], ladder[i + 1][1]]
				)
			)
	# 22. The one value motion-reduction locks to replaces the whole ladder, so it
	# must sit inside the span it replaces or it frames EVERY speed unusually.
	if p.camera.fov_motion_reduced < p.camera.fov_blend:
		e.append(
			(
				"22. camera.fov_motion_reduced (%.1f) must be >= camera.fov_blend (%.1f)"
				% [p.camera.fov_motion_reduced, p.camera.fov_blend]
			)
		)
	if p.camera.fov_motion_reduced > p.camera.fov_sprint:
		e.append(
			(
				"22. camera.fov_motion_reduced (%.1f) must be <= camera.fov_sprint (%.1f)"
				% [p.camera.fov_motion_reduced, p.camera.fov_sprint]
			)
		)
	return e


## 13, 14. The crowd must remain a place a fast player cannot disappear into.
static func _crowd_relations(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 14. A sprinting player cannot hide inside a startle wave.
	if p.crowd.npc_speed_flee >= p.movement.sprint:
		e.append(
			(
				"14. crowd.npc_speed_flee (%.3f) must be < movement.sprint (%.3f)"
				% [p.crowd.npc_speed_flee, p.movement.sprint]
			)
		)
	# 13. Two distinct information phases.
	if p.crowd.gawk_duration >= p.crowd.corpse_lifetime:
		e.append(
			(
				"13. crowd.gawk_duration (%.3f) must be < crowd.corpse_lifetime (%.3f)"
				% [p.crowd.gawk_duration, p.crowd.corpse_lifetime]
			)
		)
	return e


static func _suspicion_and_tiers(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 3. The decay cliff sits exactly at the top civilian speed.
	if not is_equal_approx(p.suspicion.decay_speed_ceiling, p.movement.stroll):
		e.append(
			(
				"3. suspicion.decay_speed_ceiling (%.3f) must EQUAL movement.stroll (%.3f)"
				% [p.suspicion.decay_speed_ceiling, p.movement.stroll]
			)
		)
	# 4. Tier order.
	if p.suspicion.tier_noticed >= p.suspicion.tier_exposed:
		e.append(
			(
				"4. suspicion.tier_noticed (%.1f) must be < tier_exposed (%.1f)"
				% [p.suspicion.tier_noticed, p.suspicion.tier_exposed]
			)
		)
	# 5. Hysteresis cannot exceed the first tier or a player can never leave it.
	if p.suspicion.hysteresis >= p.suspicion.tier_noticed:
		e.append(
			(
				(
					"5. suspicion.hysteresis (%.1f) must be < tier_noticed (%.1f), "
					+ "or a player who enters Noticed can never leave it"
				)
				% [p.suspicion.hysteresis, p.suspicion.tier_noticed]
			)
		)
	return e


static func _combat(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 6. THE PREY MUST HAVE TEETH. Design law 5; never invert this to help hunters.
	if p.combat.stun_range <= p.combat.kill_range:
		e.append(
			(
				(
					"6. combat.stun_range (%.2f) must be > combat.kill_range (%.2f) — "
					+ "the prey's reach must exceed the hunter's. Non-negotiable."
				)
				% [p.combat.stun_range, p.combat.kill_range]
			)
		)
	# 7. An Anonymous hunter is unstunnable, so patience is genuinely safe.
	if not is_equal_approx(p.combat.stun_min_tier, p.suspicion.tier_noticed):
		e.append(
			(
				"7. combat.stun_min_tier (%.1f) must EQUAL suspicion.tier_noticed (%.1f)"
				% [p.combat.stun_min_tier, p.suspicion.tier_noticed]
			)
		)
	# 15. No unskippable animation exceeds the commit ceiling.
	if p.combat.kill_anim_duration > p.movement.max_commit:
		e.append(
			(
				"15. combat.kill_anim_duration (%.2f) must be <= movement.max_commit (%.2f)"
				% [p.combat.kill_anim_duration, p.movement.max_commit]
			)
		)
	return e


## 8, 9, 10. The Compass's own ordering, and its shared threshold with the stun.
static func _compass(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 8. "I can stun them" and "I was warned about them" must be one condition.
	if not is_equal_approx(p.compass.warn_min_tier, p.suspicion.tier_noticed):
		e.append(
			(
				(
					"8. compass.warn_min_tier (%.1f) must EQUAL suspicion.tier_noticed (%.1f) — "
					+ "two thresholds here would be unlearnable"
				)
				% [p.compass.warn_min_tier, p.suspicion.tier_noticed]
			)
		)
	# 9, 10. Compass internal ordering.
	if p.compass.pulse_min >= p.compass.pulse_max:
		e.append(
			(
				"9. compass.pulse_min (%.3f) must be < compass.pulse_max (%.3f)"
				% [p.compass.pulse_min, p.compass.pulse_max]
			)
		)
	if p.compass.lock_range >= p.compass.range_max:
		e.append(
			(
				"10. compass.lock_range (%.2f) must be < compass.range_max (%.2f)"
				% [p.compass.lock_range, p.compass.range_max]
			)
		)
	return e


## 11 and 12 compare against per-ability values from TUNABLES §8, which live in
## AbilityData rather than a *Tuning section. They are checked only once those
## resources are populated — and their ABSENCE is reported, never passed over.
static func _abilities(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	var whisperbolt: Variant = p.abilities.get(Ids.ABIL_WHISPERBOLT)
	if whisperbolt == null:
		e.append("11. cannot check: abilities[ABIL-WHISPERBOLT] is not populated")
	elif float(whisperbolt.get(&"range_min")) <= p.combat.kill_range:
		e.append(
			(
				(
					"11. whisperbolt.range_min (%.2f) must be > combat.kill_range (%.2f) — "
					+ "Whisperbolt may never substitute for melee"
				)
				% [whisperbolt.get(&"range_min"), p.combat.kill_range]
			)
		)
	var cinderfall: Variant = p.abilities.get(Ids.ABIL_CINDERFALL)
	if cinderfall == null:
		e.append("12. cannot check: abilities[ABIL-CINDERFALL] is not populated")
	elif float(cinderfall.get(&"radius")) < 2.0 * p.combat.kill_range:
		e.append(
			(
				(
					"12. cinderfall.radius (%.2f) must be >= 2 x combat.kill_range (%.2f) — "
					+ "the cloud must deny a kill attempt, not merely obscure one"
				)
				% [cinderfall.get(&"radius"), 2.0 * p.combat.kill_range]
			)
		)
	return e


static func _net(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 16. The history buffer is never the binding constraint.
	if p.net.lagcomp_max > p.net.lagcomp_history / 2.0:
		e.append(
			(
				"16. net.lagcomp_max (%.1f) must be <= net.lagcomp_history / 2 (%.1f)"
				% [p.net.lagcomp_max, p.net.lagcomp_history / 2.0]
			)
		)
	# 17. A culled NPC can never affect anything the client can perceive.
	if p.net.npc_cull_radius < p.compass.range_max:
		e.append(
			(
				"17. net.npc_cull_radius (%.1f) must be >= compass.range_max (%.1f)"
				% [p.net.npc_cull_radius, p.compass.range_max]
			)
		)
	return e


## 18, 19. The score table encodes the design thesis; guard its shape.
static func _scoring(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	# 18. THE BONUS HIERARCHY ENCODES THE DESIGN THESIS. If a tuning change
	# inverts this, the tuning change is wrong.
	if not (p.scoring.blended > p.scoring.patient and p.scoring.patient > p.scoring.silent):
		e.append(
			(
				(
					"18. scoring must satisfy blended (%.0f) > patient (%.0f) > silent (%.0f) — "
					+ "this ordering IS the design thesis"
				)
				% [p.scoring.blended, p.scoring.patient, p.scoring.silent]
			)
		)
	# 19. Defence pays like offence.
	if not is_equal_approx(p.scoring.stun, p.scoring.contract):
		e.append(
			(
				"19. scoring.stun (%.0f) must EQUAL scoring.contract (%.0f)"
				% [p.scoring.stun, p.scoring.contract]
			)
		)
	e.append_array(_patience(p))
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


## 20. The client frame budget must actually add up.
static func _perf(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	var spent := (
		p.perf.crowd_budget
		+ p.perf.net_budget
		+ p.perf.gameplay_budget
		+ p.perf.ui_budget
		+ p.perf.render_budget
	)
	if spent > p.perf.frame_budget:
		e.append(
			(
				"20. client budgets sum to %.2f ms, over frame_budget %.2f ms"
				% [spent, p.perf.frame_budget]
			)
		)
	return e
