## **THE DEAL IS SEEDED, DUPLICATES ARE LEGAL, AND EVERY PLAYER GETS ONE.**
## US-0100, owner decision 13.
##
## The property that matters is **reproducibility**: a recorded seed must deal the
## same district twice, or no playtest can be re-run against a tuning change. That
## is why the generator is `MatchContext.rng` and never `randi` (never-do #8), and
## it is asserted here rather than trusted, because a `randi` call would pass every
## other assertion in this file.
extends GutTest

## Six players, the design centre. Not a `const`: `PackedInt32Array(...)` is a
## constructor call and GDScript refuses it as a constant expression.
var _peers := PackedInt32Array([7, 8, 9, 10, 11, 12])


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_every_peer_is_dealt_a_playable_persona() -> void:
	var dealt := PersonaDeal.deal(_peers, _rng(4242))
	assert_eq(dealt.size(), _peers.size(), "somebody was left without a persona")
	for peer: int in _peers:
		assert_true(dealt.has(peer), "peer %d was skipped" % peer)
		assert_true(
			CrowdRoster.PLAYABLE.has(dealt[peer]),
			"peer %d was dealt something that is not playable: %s" % [peer, dealt[peer]]
		)


## **THE SAME SEED DEALS THE SAME DISTRICT.** Planted, a deal that reaches for
## `randi` passes everything above and fails exactly this.
func test_the_deal_is_reproducible_from_the_seed() -> void:
	var first := PersonaDeal.deal(_peers, _rng(99))
	var second := PersonaDeal.deal(_peers, _rng(99))
	assert_eq(first, second, "the same seed dealt two different districts")


func test_a_different_seed_deals_a_different_district() -> void:
	# Not a guarantee for any one pair of seeds — four personas over six players
	# collide often — so this sweeps until it finds a difference and says so if it
	# never does, rather than pinning a seed that happens to differ today.
	var baseline := PersonaDeal.deal(_peers, _rng(1))
	var differing := 0
	for candidate: int in range(2, 40):
		if PersonaDeal.deal(_peers, _rng(candidate)) != baseline:
			differing += 1
	assert_gt(differing, 0, "thirty-eight seeds all dealt the same district; the seed is not read")


## **DUPLICATES ARE THE RULE.** US-0078: *"duplicate personas are GOOD: they add a
## candidate to each other's crowd."* With six players and four personas a deal
## that refused duplicates could not complete at all, so this asserts the property
## over enough seeds to be sure the deal is not quietly distinct-by-construction.
func test_duplicates_are_permitted() -> void:
	var with_a_duplicate := 0
	for candidate: int in range(1, 60):
		var dealt := PersonaDeal.deal(_peers, _rng(candidate))
		var seen: Dictionary = {}
		for peer: int in dealt:
			if seen.has(dealt[peer]):
				with_a_duplicate += 1
				break
			seen[dealt[peer]] = true
	assert_gt(
		with_a_duplicate,
		0,
		"fifty-nine deals over six players and four personas produced no duplicate"
	)


## A caller that forgot to seed gets a **playable** persona rather than nothing:
## `CrowdRoster` argues clones of an unplayed persona are harmless, while a player
## with no clones is GDD-03 §6.3 rule 5's marked man.
func test_a_null_generator_still_deals_something_playable() -> void:
	var dealt := PersonaDeal.deal(_peers, null)
	for peer: int in _peers:
		assert_true(CrowdRoster.PLAYABLE.has(dealt[peer]), "the safe fallback is not playable")


func test_an_empty_lobby_deals_nothing_rather_than_erroring() -> void:
	assert_eq(PersonaDeal.deal(PackedInt32Array(), _rng(3)).size(), 0)


## The late joiner draws from the same generator as the countdown, so one match
## stays one sequence. A second source of randomness for *the same thing, later*
## is how a replay stops replaying.
func test_the_single_draw_is_the_same_rule_as_the_deal() -> void:
	var swept: Dictionary = {}
	for candidate: int in range(1, 40):
		swept[PersonaDeal.one(_rng(candidate))] = true
	assert_eq(
		swept.size(), CrowdRoster.PLAYABLE.size(), "the single draw cannot reach every persona"
	)
