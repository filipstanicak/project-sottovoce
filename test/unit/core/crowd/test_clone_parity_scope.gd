## **THE CONDITIONS GDD-03 §6.3 RULE 3's SCOPE RESTS ON.** GDD-03 §6.3 rule 3,
## GDD-05 §2.7 rule 8, TDD-08 §5.1.5, US-0047.
##
## Rule 3 stopped binding at the instant a player is placed on 2026-08-21, and a
## scope is only honest while the thing it defers to is true. **"It cannot matter
## in the finished game" is exactly the kind of claim that stops being true
## quietly** — the same shape as the enclosure this project already asserts for the
## mid-air traversal stop, and for the same reason: the day a tunable moves, the
## exemption would silently become an excuse and nothing would say so.
##
## Two conditions carry the whole argument:
##
## 1. **The player can reach the crowd inside the grace, at blend-walk.** Rule 3
##    defers because the player has not yet chosen where to stand; that is only
##    fair if they can choose within the window, without spending speed.
## 2. **The grace is a window and not an exemption.** A grace approaching the match
##    length would delete the rule while appearing to scope it.
extends GutTest


func test_the_grace_is_one_pass_plus_one_walk_and_nothing_else() -> void:
	# **DERIVED, NOT CHOSEN — ASSERTED SO IT STAYS DERIVED.** A literal here would
	# keep satisfying every other test in this file the first time
	# `TUN-CROWD-CLONE-LOCAL-RADIUS` is retuned, and the scope would quietly stop
	# matching the walk it is justified by.
	var walk: float = Tuning.crowd.clone_local_radius / Tuning.crowd.npc_speed_stroll
	assert_almost_eq(
		CloneParity.walk_seconds(), walk, 0.001, "the walk is not the radius at stroll"
	)
	assert_almost_eq(
		CloneParity.grace_seconds(),
		Tuning.crowd.director_interval + walk,
		0.001,
		"the grace is not one director pass plus one crossing of the local radius"
	)
	gut.p(
		(
			"grace %.2f s = %.2f s pass + %.2f s walk, %d ticks"
			% [
				CloneParity.grace_seconds(),
				Tuning.crowd.director_interval,
				walk,
				CloneParity.grace_ticks()
			]
		)
	)


func test_a_placed_player_can_walk_to_the_crowd_inside_the_grace() -> void:
	# **CONDITION 1, AND IT IS THE WHOLE JUSTIFICATION.** The rule defers because
	# the player has not yet chosen where they stand. If the grace expired before
	# they could cross their own local radius at blend-walk, rule 3 would bind on a
	# position they were still stuck in — and the only way out would be to run,
	# which design law 1 prices in exactly the anonymity the rule protects.
	var escape: float = Tuning.crowd.clone_local_radius / Tuning.movement.blend_walk
	gut.p(
		(
			"a blend-walk of the local radius takes %.2f s against a grace of %.2f s"
			% [escape, CloneParity.grace_seconds()]
		)
	)
	assert_gte(
		CloneParity.grace_seconds(),
		escape,
		(
			"the grace expires before a player can blend-walk out of a thin region, so rule 3 "
			+ "would bind on a position the match chose for them and the only escape would cost "
			+ "speed — which is the anonymity the rule exists to protect"
		)
	)


func test_the_two_walks_are_the_same_walk() -> void:
	# **WHY ONE NUMBER SERVES BOTH ENDS.** The grace is derived from the *clone's*
	# journey and justified by the *player's*, and those are the same duration only
	# because invariant 1 forces the two speeds equal. Restated here rather than
	# left implied: if the two ever diverged, the derivation would still compute and
	# would no longer mean what §5.1.5 says it means.
	assert_almost_eq(
		Tuning.crowd.npc_speed_stroll,
		Tuning.movement.blend_walk,
		0.0001,
		(
			"stroll and blend-walk have diverged, so the clone's journey and the player's are "
			+ "no longer the same walk and the grace derives from one while being justified "
			+ "by the other (invariant 1)"
		)
	)


func test_the_grace_is_a_window_and_not_an_exemption() -> void:
	# **CONDITION 2, AS THE DEGENERATE GUARD IT IS.** This is not a tight bound and
	# does not pretend to be — it refuses the case where scoping the rule has
	# deleted it. At the shipped values the grace is about 4 % of a match.
	var match_seconds: float = Tuning.match_rules.duration
	gut.p(
		(
			"the grace is %.1f %% of a %.0f s match"
			% [100.0 * CloneParity.grace_seconds() / match_seconds, match_seconds]
		)
	)
	assert_gt(CloneParity.grace_seconds(), 0.0, "the grace is zero, so nothing was scoped at all")
	assert_lt(
		CloneParity.grace_seconds(),
		match_seconds,
		"a grace as long as the match is an exemption wearing a scope's name"
	)


func test_the_seat_requirement_is_counted_and_not_written_down() -> void:
	# GDD-05 §2.7 rule 8's threshold, which is where the opening arrangement's
	# obligation went. Eight at the shipped values — and it must follow the floor
	# and the persona count, because a literal 8 would stop being the requirement
	# the day either moved and `test_spawn_points.gd` would grade the map against a
	# number no document held.
	assert_eq(
		CloneParity.seats_required(),
		int(Tuning.crowd.clone_local_min) * CrowdRoster.PLAYABLE.size(),
		"the seat requirement is not the floor times the playable personas"
	)
	assert_gt(CrowdRoster.PLAYABLE.size(), 0, "no playable personas, so the requirement is vacuous")
	gut.p(
		(
			"a spawn point must seat %d: %d personas x a floor of %d"
			% [
				CloneParity.seats_required(),
				CrowdRoster.PLAYABLE.size(),
				int(Tuning.crowd.clone_local_min)
			]
		)
	)
