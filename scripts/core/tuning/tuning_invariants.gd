## The gameplay half of TUNABLES.md §17's 31 cross-field invariants.
##
## **SPLIT AT 31 INVARIANTS, NOT REORGANISED.** The wire and budget rules moved
## to `TuningInvariantsTech` when this file reached 400 lines; nothing else
## changed, and `check()` is still the one entry point. The split is by what a
## rule is ABOUT — a speed ladder is a design decision and a snapshot rate is
## not — rather than by which half happened to be longer.
##
## A value can be inside its own documented range and still be wrong, because what
## matters is its relationship to another. Invariant 1 is the clearest case:
## blend-walk and the NPC stroll are both legal anywhere in 1.2–1.6, and the game
## is broken unless they are the SAME number.
##
## Separated from TuningProfile so the list reads as a list. Each check names both
## operands and their values: "invariant 7 failed" costs the reader two lookups.
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
	e.append_array(TuningInvariantsTech.check(p))
	e.append_array(TuningInvariantsScore.check(p))
	e.append_array(_traversal_reach(p))
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
	# 28. AN IDLE ANCHOR MUST FORM A VALID BLEND POCKET. NPCs stopping anywhere
	# within the arrival radius are at most twice it apart, and that spread has to
	# fit inside the radius TUN-BLEND-POCKET-MIN-NPC is counted in. Widen the
	# arrival radius past this and anchors quietly stop producing pockets: nothing
	# errors, and the game simply has fewer places to hide.
	if p.crowd.anchor_arrive_radius * 2.0 > p.suspicion.blend_pocket_radius:
		e.append(
			(
				(
					"28. 2 x crowd.anchor_arrive_radius (%.2f) must be <= "
					+ "suspicion.blend_pocket_radius (%.2f), or an idle anchor stops "
					+ "forming a blend pocket"
				)
				% [p.crowd.anchor_arrive_radius, p.suspicion.blend_pocket_radius]
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


## 24, 25. **ANYTHING YOU CAN CLIMB UP, YOU CAN FALL DOWN.** A probe shallower
## than the tallest single climb cannot measure the drop back down it, and an
## unmeasured drop is one the planner must refuse rather than guess at — it used
## to substitute the probe depth and set the pawn down in mid-air. And a lip you
## cannot vault up must not be dismissed as a step down.
static func _traversal_reach(p: TuningProfile) -> Array[String]:
	var e: Array[String] = []
	if p.movement.gap_probe_depth < p.movement.traverse_climb_max_height:
		e.append(
			(
				"24. movement.gap_probe_depth (%.1f) must be >= traverse_climb_max_height (%.1f)"
				% [p.movement.gap_probe_depth, p.movement.traverse_climb_max_height]
			)
		)
	if p.movement.hop_standing >= p.movement.hop_committed:
		e.append(
			(
				"26. movement.hop_standing (%.2f) must be < hop_committed (%.2f)"
				% [p.movement.hop_standing, p.movement.hop_committed]
			)
		)
	if p.movement.drop_min_height > p.movement.traverse_vault_max_height:
		e.append(
			(
				"25. movement.drop_min_height (%.2f) must be <= traverse_vault_max_height (%.2f)"
				% [p.movement.drop_min_height, p.movement.traverse_vault_max_height]
			)
		)
	if p.crowd.idle_duration_min >= p.crowd.idle_duration_max:
		e.append(
			(
				"27. crowd.idle_duration_min (%.1f) must be < idle_duration_max (%.1f)"
				% [p.crowd.idle_duration_min, p.crowd.idle_duration_max]
			)
		)
	return e

## 20. The client frame budget must actually add up.
