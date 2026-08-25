## **THE CONTRACT CYCLE'S PROPERTIES, ONE PER TEST.** US-0049, GDD-03 §7, TDD-10.
##
## The fuzz run lives in `test_contract_cycle_fuzz.gd` and the self-assignment
## guarantee in `test_contract_never_self.gd`; this file holds the named properties
## GDD-03 §7.4's proof rests on, each asserted on its own so a failure says which
## clause broke rather than "ten thousand sequences went wrong somewhere".
extends GutTest

const SEED := 20260821


## Records what it is given, so a test can ask whether telemetry actually fired.
## **`TelemetrySink` is an interface with a discarding default**, which means a
## system that never raises an event and a system whose events go nowhere look
## identical from outside — this is the difference.
class Recorder:
	extends TelemetrySink

	var events: Array = []

	func append(id: StringName, fields: Dictionary) -> void:
		events.append([id, fields])

	func count(id: StringName) -> int:
		var found := 0
		for event: Array in events:
			if event[0] == id:
				found += 1
		return found


func _rng(offset: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + offset
	return rng


func _open(count: int, offset: int = 0) -> ContractCycle:
	var cycle := ContractCycle.new(_rng(offset))
	var players := PackedInt32Array()
	for index: int in count:
		players.append(100 + index)
	cycle.open(players)
	return cycle


func test_contract_and_pursuer_are_successor_and_predecessor() -> void:
	var cycle := _open(6)
	var order := cycle.living()
	for index: int in order.size():
		var here: int = order[index]
		assert_eq(
			cycle.contract_of(here),
			order[(index + 1) % order.size()],
			"contract_of is not the cyclic successor"
		)
		assert_eq(
			cycle.pursuer_of(here),
			order[(index - 1 + order.size()) % order.size()],
			"pursuer_of is not the cyclic predecessor"
		)


func test_every_player_is_hunted_by_exactly_one_player() -> void:
	# The other half of "exactly one incoming edge". Successor being a bijection is
	# what makes the graph a cycle rather than a tree with a loop in it.
	var cycle := _open(6)
	var hunted: Dictionary = {}
	for peer: int in cycle.living():
		var prey := cycle.contract_of(peer)
		assert_false(hunted.has(prey), "peer %d is hunted by two players" % prey)
		hunted[prey] = peer
	assert_eq(hunted.size(), cycle.size(), "somebody is hunted by nobody")


func test_the_repair_is_the_removal() -> void:
	# **THE PROPERTY THAT MOTIVATED CHOOSING A CYCLE OVER A MATCHING**, GDD-03 §7.4.
	# The victim's pursuer inherits the victim's contract with no reassignment pass,
	# so nobody is contractless at any instant — which is the thing a matching would
	# have to run code between the kill and the next tick to achieve.
	var cycle := _open(6)
	var victim: int = cycle.living()[2]
	var pursuer := cycle.pursuer_of(victim)
	var inherited := cycle.contract_of(victim)
	assert_true(cycle.remove(victim), "the victim was not in the cycle")
	assert_eq(cycle.size(), 5, "removal did not shorten the cycle by one")
	assert_eq(
		cycle.contract_of(pursuer),
		inherited,
		"the victim's pursuer did not inherit the victim's contract"
	)
	assert_eq(cycle.assert_valid(), "", "the cycle is not valid after a removal")


func test_nobody_is_contractless_at_any_point_of_a_teardown() -> void:
	# Removals down to one player, checking after every single one. A rule that
	# holds at six and at two can still have a hole at four.
	var cycle := _open(6)
	while cycle.size() > 1:
		cycle.remove(cycle.living()[0])
		assert_eq(cycle.assert_valid(), "", "invalid at %d players" % cycle.size())
		if cycle.size() < 2:
			break
		for peer: int in cycle.living():
			assert_ne(
				cycle.contract_of(peer), ContractCycle.NOBODY, "peer %d has no contract" % peer
			)


func test_removing_somebody_who_is_not_there_changes_nothing() -> void:
	var cycle := _open(5)
	var before := cycle.living()
	assert_false(cycle.remove(999), "a stranger was reported as removed")
	assert_eq(cycle.living(), before, "the cycle changed anyway")


func test_a_peer_cannot_be_inserted_twice() -> void:
	# GDD-03 §7.4's insertion precondition. A duplicate would put one player at two
	# places in the cycle, which is two contracts and two pursuers.
	var cycle := _open(5)
	var existing: int = cycle.living()[0]
	assert_false(cycle.insert(existing), "an existing peer was inserted again")
	assert_eq(cycle.size(), 5, "the cycle grew")
	assert_eq(cycle.assert_valid(), "", "the cycle is invalid")


func test_a_respawn_avoids_being_hunted_by_its_killer() -> void:
	# GDD-03 §7.2: the killer must not immediately re-hunt. With six players there
	# are five insertion points and only one is adjacent to the killer, so the
	# constraint never has to relax and the property is exact.
	for offset: int in 40:
		var cycle := _open(6, offset)
		var victim: int = cycle.living()[3]
		var killer := cycle.pursuer_of(victim)
		cycle.remove(victim)
		assert_true(cycle.insert(victim, killer), "the respawn was refused")
		assert_ne(
			cycle.pursuer_of(victim),
			killer,
			"seed %d handed the killer their victim straight back" % offset
		)
		assert_eq(cycle.assert_valid(), "", "the cycle is invalid after a constrained respawn")


func test_a_join_lands_somewhere_legal_and_keeps_the_cycle_valid() -> void:
	var cycle := _open(4)
	assert_true(cycle.insert(200), "the joiner was refused")
	assert_eq(cycle.size(), 5, "the cycle did not grow")
	assert_true(cycle.has(200), "the joiner is not in the cycle")
	assert_eq(cycle.assert_valid(), "", "the cycle is invalid after a join")


func test_a_batch_applies_every_removal_before_any_insertion() -> void:
	# **GDD-03 §7.3's debounce, and the reason for the ordering.** A respawn placed
	# beside somebody who leaves in the same batch is a contract handed to a corpse.
	var cycle := _open(6)
	var order := cycle.living()
	var leaving := PackedInt32Array([order[1], order[2]])
	cycle.apply(leaving, [[300, order[0]], [301, ContractCycle.NOBODY]])
	assert_eq(cycle.size(), 6, "six minus two plus two is not six")
	for gone: int in leaving:
		assert_false(cycle.has(gone), "peer %d was removed and is still here" % gone)
	assert_true(cycle.has(300) and cycle.has(301), "an insertion was lost")
	assert_eq(cycle.assert_valid(), "", "the cycle is invalid after a batch")


func test_two_players_is_valid_mutual_and_reported() -> void:
	# GDD-03 §7.4: n = 2 is a fixed-point-free 2-cycle, so the invariant holds and
	# the game is over as a game. Reported rather than prevented — preventing it
	# would mean refusing a death.
	var recorder := Recorder.new()
	var cycle := ContractCycle.new(_rng(), recorder)
	cycle.open(PackedInt32Array([1, 2, 3, 4]))
	assert_eq(recorder.count(&"TEL-DEGENERATE-CYCLE"), 0, "four players is not degenerate")
	cycle.remove(cycle.living()[0])
	cycle.remove(cycle.living()[0])
	assert_eq(cycle.size(), 2, "the teardown did not reach two")
	assert_eq(cycle.assert_valid(), "", "a two-cycle is valid and was reported invalid")
	var pair := cycle.living()
	assert_eq(cycle.contract_of(pair[0]), pair[1], "the two players do not hunt each other")
	assert_eq(cycle.contract_of(pair[1]), pair[0], "the two players do not hunt each other")
	assert_eq(recorder.count(&"TEL-DEGENERATE-CYCLE"), 1, "the degeneracy was not reported")


func test_the_degeneracy_is_reported_once_per_descent() -> void:
	# A match that sits at two players must not emit one event per repair. It is a
	# state the analysis wants to count, not a tick to sample.
	var recorder := Recorder.new()
	var cycle := ContractCycle.new(_rng(), recorder)
	cycle.open(PackedInt32Array([1, 2, 3, 4]))
	cycle.remove(1)
	cycle.remove(2)
	assert_eq(recorder.count(&"TEL-DEGENERATE-CYCLE"), 1, "the first descent went unreported")
	cycle.insert(5)
	cycle.remove(5)
	assert_eq(recorder.count(&"TEL-DEGENERATE-CYCLE"), 2, "a second descent went unreported")
	cycle.insert(6)
	cycle.insert(7)
	cycle.remove(6)
	cycle.remove(7)
	assert_eq(recorder.count(&"TEL-DEGENERATE-CYCLE"), 3, "recovery did not rearm the report")


func test_one_player_issues_no_contract_and_does_not_error() -> void:
	var cycle := _open(2)
	cycle.remove(cycle.living()[0])
	assert_eq(cycle.size(), 1, "the cycle is not down to one")
	var alone: int = cycle.living()[0]
	assert_eq(cycle.contract_of(alone), ContractCycle.NOBODY, "the last player hunts somebody")
	assert_eq(cycle.pursuer_of(alone), ContractCycle.NOBODY, "the last player is hunted")
	assert_eq(cycle.assert_valid(), "", "a one-player cycle is not an invalid one")


func test_an_empty_cycle_answers_nobody() -> void:
	var cycle := ContractCycle.new(_rng())
	cycle.open(PackedInt32Array())
	assert_eq(cycle.size(), 0, "an empty cycle is not empty")
	assert_eq(cycle.contract_of(1), ContractCycle.NOBODY, "a stranger was given a contract")
	assert_eq(cycle.assert_valid(), "", "an empty cycle is not an invalid one")


func test_the_same_seed_deals_the_same_contracts() -> void:
	# GDD-03 §6.3 rule 4's neighbourhood: two servers given one seed must produce
	# one match. `open` shuffles, and `Array.shuffle()` would draw from the global
	# RNG — both never-do #8 and non-deterministic.
	assert_eq(_open(6).living(), _open(6).living(), "one seed dealt two different cycles")
	assert_ne(_open(6, 1).living(), _open(6).living(), "two seeds dealt the same cycle")


func test_the_shuffle_is_not_the_identity() -> void:
	# The vacuous-success guard for the one above: an `open` that returned its input
	# untouched would satisfy determinism perfectly.
	var players := PackedInt32Array([100, 101, 102, 103, 104, 105])
	var moved := 0
	for offset: int in 8:
		var cycle := ContractCycle.new(_rng(offset))
		cycle.open(players)
		if cycle.living() != players:
			moved += 1
	assert_gt(moved, 0, "open never reordered anybody across eight seeds")


func test_assert_valid_catches_what_it_claims_to() -> void:
	# **FALSIFIED AGAINST PLANTED DEFECTS.** A validity check nobody has broken on
	# purpose is a check that has never been shown to detect anything.
	var cycle := _open(5)
	assert_eq(cycle.assert_valid(), "", "a sound cycle was called invalid")
	var duplicated := ContractCycle.new(_rng())
	duplicated.open(PackedInt32Array([1, 2, 2, 3]))
	assert_string_contains(duplicated.assert_valid(), "twice", "a duplicate peer passed")
	var nobody := ContractCycle.new(_rng())
	nobody.open(PackedInt32Array([1, 0, 2]))
	assert_string_contains(nobody.assert_valid(), "NOBODY", "a zero peer passed")
	# **THE FIXED-POINT AND ONE-CYCLE BRANCHES CANNOT BE REACHED THROUGH THE PUBLIC
	# API, AND ARE KEPT ANYWAY.** With an ordered list, `contract(p) == p` requires p
	# to appear twice, which the duplicate check above catches first. They are
	# defence for the day the representation becomes a map of edges — said here so
	# the next reader does not mistake an unexercised branch for dead code.
