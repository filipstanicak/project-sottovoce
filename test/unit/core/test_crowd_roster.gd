## **THE ROSTER EVERY PEER DERIVES.** US-0039, GDD-03 §6.3, TDD-08 §2.
##
## Pure, so the question "do three peers agree?" is asked directly rather than by
## standing three peers up — which is also the only way to ask it a thousand times
## across a thousand seeds.
##
## **THE FAILURE THIS FILE EXISTS FOR IS SILENT.** A roster that differed between
## peers would not error, crash or desync the simulation: NPC identity is *visual*
## and derived, so the two clients would simply be looking at different cities.
## The symptom is a player saying "I saw a Lucerna by the furnace" and being
## wrong, which reads as a lying teammate rather than a bug.
extends GutTest

const SEED := 20260815

var _personas: Array = [
	Ids.PERSONA_CANTATRICE, Ids.PERSONA_LUCERNA, Ids.PERSONA_PESATORE, Ids.PERSONA_VETRAIO
]


func test_the_clone_quota_reproduces_tunables_three_documented_defaults() -> void:
	# **THE NUMBERS ARE NOT INVENTED HERE.** TUNABLES gives 66/72/78 as the 4, 5
	# and 6-player crowds, decomposed as 40/44/48 clones plus filler — 10, 11 and
	# 12 per persona. The rule is derived from existing tunables rather than a new
	# ratio, and this asserts it lands on all three.
	assert_eq(CrowdRoster.clones_per_persona(6), 12, "the 6-player quota is not TUNABLES' 12")
	assert_eq(CrowdRoster.clones_per_persona(5), 11, "the 5-player quota is not TUNABLES' 11")
	assert_eq(CrowdRoster.clones_per_persona(4), 10, "the 4-player quota is not TUNABLES' 10")


func test_the_quota_never_leaves_the_range_rule_3_makes_a_blocker() -> void:
	# GDD-03 §6.3 rule 3 is a release blocker in **both** directions: below 8 a
	# persona can be locally depleted and the player wearing it becomes unique;
	# above 12 the crowd reads as a police lineup of repeats.
	for players: int in range(1, 12):
		var quota := CrowdRoster.clones_per_persona(players)
		assert_between(
			quota,
			Tuning.crowd.clones_per_persona_min,
			Tuning.crowd.clones_per_persona_max,
			"a %d-player lobby produced a quota of %d" % [players, quota]
		)


func test_three_peers_derive_the_same_roster() -> void:
	# **US-0039's LAST CRITERION.** Three independent derivations from one seed.
	var a := CrowdRoster.derive(78, SEED, _personas, 6)
	var b := CrowdRoster.derive(78, SEED, _personas, 6)
	var c := CrowdRoster.derive(78, SEED, _personas, 6)
	assert_eq(CrowdRoster.fingerprint(a), CrowdRoster.fingerprint(b), "peers A and B disagree")
	assert_eq(CrowdRoster.fingerprint(b), CrowdRoster.fingerprint(c), "peers B and C disagree")


func test_a_different_seed_gives_a_different_roster() -> void:
	# The other half. A derivation that ignored the seed would make every peer
	# agree perfectly and every match identical — and would pass the test above.
	var a := CrowdRoster.derive(78, SEED, _personas, 6)
	var b := CrowdRoster.derive(78, SEED + 1, _personas, 6)
	assert_ne(
		CrowdRoster.fingerprint(a),
		CrowdRoster.fingerprint(b),
		"two seeds produced the same roster — the seed is not being used"
	)


func test_adjacent_seeds_do_not_produce_nearly_identical_rosters() -> void:
	# **WHY THE SEED IS MIXED RATHER THAN USED RAW.** Sequential match seeds are
	# the ordinary case; if they differed in one draw, every match in a session
	# would look like the last one and nobody would be able to say why.
	var a := CrowdRoster.derive(78, 1000, _personas, 6)
	var b := CrowdRoster.derive(78, 1001, _personas, 6)
	var same := 0
	for i: int in a.size():
		if a[i] == b[i]:
			same += 1
	gut.p("adjacent seeds share %d of %d slots" % [same, a.size()])
	assert_lt(same, a.size() / 2, "adjacent seeds produce nearly the same roster")


func test_every_persona_in_use_gets_its_full_quota() -> void:
	# **GDD-03 §6.3 RULE 5 IS A RELEASE BLOCKER.** A player whose persona has no
	# clones is a marked man — the one thing the crowd exists to prevent.
	var roster := CrowdRoster.derive(78, SEED, _personas, 6)
	var census := CrowdRoster.census(roster)
	for persona: StringName in _personas:
		assert_eq(
			int(census.get(persona, 0)),
			CrowdRoster.clones_per_persona(6),
			"%s did not get its full clone quota" % persona
		)


func test_the_remainder_is_filler_archetypes() -> void:
	var roster := CrowdRoster.derive(78, SEED, _personas, 6)
	var census := CrowdRoster.census(roster)
	var clones := CrowdRoster.clones_per_persona(6) * _personas.size()
	var filler := roster.size() - clones
	assert_eq(filler, 30, "78 minus 48 clones is not TUNABLES' 30 filler")

	var filler_seen := 0
	for id: StringName in CrowdRoster.ARCHETYPES:
		filler_seen += int(census.get(id, 0))
	assert_eq(filler_seen, filler, "the remainder is not made of filler archetypes")


func test_clones_are_not_clustered_at_the_low_indices() -> void:
	# **THE SHUFFLE IS NOT COSMETIC.** The pool hands index 0 the first spawn
	# point, so an unshuffled roster would put every clone in one quarter of the
	# district and every filler in another — visible in one glance, and it would
	# make the clone quota locally meaningless everywhere else.
	var roster := CrowdRoster.derive(78, SEED, _personas, 6)
	var clones_in_first_half := 0
	for i: int in roster.size() / 2:
		if _personas.has(roster[i]):
			clones_in_first_half += 1
	gut.p("clones in the first half: %d of 48" % clones_in_first_half)
	assert_between(clones_in_first_half, 14, 34, "clones are clustered rather than spread")


func test_the_roster_is_exactly_the_count_asked_for() -> void:
	for count: int in [60, 66, 72, 78, 90]:
		assert_eq(
			CrowdRoster.derive(count, SEED, _personas, 6).size(),
			count,
			"a roster of %d was not %d long" % [count, count]
		)


func test_a_count_too_small_for_the_quota_still_fills_what_it_can() -> void:
	# Not a case the tuning ranges allow — `TUN-CROWD-COUNT-MIN` is 60 against a
	# 48-clone maximum — but a derivation that ran off the end would corrupt the
	# roster rather than shorten it, and the failure would be a crash in the pool.
	var roster := CrowdRoster.derive(10, SEED, _personas, 6)
	assert_eq(roster.size(), 10, "a count below the clone quota did not truncate cleanly")


func test_no_persona_appears_that_nobody_is_wearing_and_was_not_asked_for() -> void:
	# Rule 5's converse is explicitly *allowed* — clones of an unplayed persona
	# are harmless — but they must not appear by accident, because the roster is
	# built from the in-use list and nothing else.
	var solo: Array = [Ids.PERSONA_LUCERNA]
	var census := CrowdRoster.census(CrowdRoster.derive(78, SEED, solo, 6))
	for persona: StringName in _personas:
		if persona != Ids.PERSONA_LUCERNA:
			assert_eq(int(census.get(persona, 0)), 0, "%s appeared uninvited" % persona)


func test_the_fingerprint_actually_discriminates() -> void:
	# Guards every parity assertion above. A fingerprint that collapsed to a
	# constant would make three disagreeing peers look identical.
	var a := CrowdRoster.derive(78, SEED, _personas, 6)
	var b := a.duplicate()
	b[0] = Ids.ARCH_PORTER if b[0] != Ids.ARCH_PORTER else Ids.ARCH_CHILD
	assert_ne(
		CrowdRoster.fingerprint(a),
		CrowdRoster.fingerprint(b),
		"one changed slot did not change the fingerprint"
	)
