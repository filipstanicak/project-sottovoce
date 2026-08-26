## **A KILL IS VALID AGAINST YOUR CONTRACT AND NOBODY ELSE.** US-0060, TDD-10 §3,
## GDD-03 §7.
##
## The rule that makes the whole match a cycle rather than a deathmatch: you may
## remove exactly one person, and it is not the one who is bothering you.
##
## Every assertion here drives `KillRules` against a hand-built `RewoundWorld`,
## which is the only world it can measure. There is no district, no physics and no
## context — the point of the pure/system split is that the awkward cases get
## written.
extends GutTest

const KILLER := 11
const CONTRACT := 12
const STRANGER := 13

var _t: CombatTuning


func before_each() -> void:
	_t = Tuning.combat


## Everybody at the origin facing +Z unless placed otherwise. Yaw 0 is +Z, which
## is `ProbeLayout.forward`'s convention and `CompassMath.bearing_to`'s.
func _world(places: Dictionary) -> RewoundWorld:
	var world := RewoundWorld.new()
	world.tick = 100
	for peer: int in places:
		var row: Array = places[peer]
		world.add(peer, row[0] as Vector3, float(row[1]))
	return world


func _ahead(metres: float) -> Vector3:
	return Vector3(0.0, 0.0, metres)


func _resolve(world: RewoundWorld, contract: int, others: Array) -> Array:
	return KillRules.resolve(world, KILLER, contract, PackedInt32Array(others), _t)


func test_the_contract_in_range_and_cone_is_allowed() -> void:
	# **THE PREMISE.** Every rejection below would be true of a rule that never
	# allowed anything.
	var world := _world({KILLER: [Vector3.ZERO, 0.0], CONTRACT: [_ahead(2.0), 0.0]})
	var out := _resolve(world, CONTRACT, [CONTRACT])
	assert_eq(out[0], KillVerdict.V.ALLOWED, KillVerdict.name_of(out[0]))
	assert_eq(out[1], CONTRACT, "the wrong target was named")


func test_a_stranger_at_point_blank_is_rejected() -> void:
	# `TUN-KILL-INVALID-TARGET-PENALTY`'s own sentence: *you cannot safely test
	# whether a stranger is your contract.* The stranger is nearer than the
	# contract and it makes no difference.
	var world := _world(
		{KILLER: [Vector3.ZERO, 0.0], STRANGER: [_ahead(1.0), 0.0], CONTRACT: [_ahead(2.0), 0.0]}
	)
	var out := _resolve(world, CONTRACT, [STRANGER, CONTRACT])
	assert_eq(out[0], KillVerdict.V.WRONG_TARGET, KillVerdict.name_of(out[0]))
	assert_eq(out[1], STRANGER, "the whiff was aimed at somebody else")
	assert_true(KillVerdict.costs_suspicion(out[0]), "probing for your contract was free")


func test_the_nearest_body_is_the_target_not_the_first_one_listed() -> void:
	# **NEAREST, NOT FIRST.** Iteration order over peers is join order, so taking
	# the first match would let a bystander absorb the press only when they
	# happened to join earlier — and the same press would resolve differently in
	# two matches with the same geometry.
	var world := _world(
		{KILLER: [Vector3.ZERO, 0.0], CONTRACT: [_ahead(1.0), 0.0], STRANGER: [_ahead(2.0), 0.0]}
	)
	var out := _resolve(world, CONTRACT, [STRANGER, CONTRACT])
	assert_eq(out[0], KillVerdict.V.ALLOWED, "the further stranger absorbed the press")


func test_no_announced_contract_rejects_everything() -> void:
	# `TUN-CONTRACT-REASSIGN-DELAY` points a killer at nobody for three seconds
	# after their own kill. **The graph has already been repaired and the ANNOUNCED
	# contract has not** — reading the graph here would let a hunter kill somebody
	# they have not been told about, which is worse than harsh: it would pay
	# pressing the button at random during the breath.
	var world := _world({KILLER: [Vector3.ZERO, 0.0], STRANGER: [_ahead(1.5), 0.0]})
	var out := _resolve(world, ContractCycle.NOBODY, [STRANGER])
	assert_eq(out[0], KillVerdict.V.NO_CONTRACT, KillVerdict.name_of(out[0]))
	assert_true(KillVerdict.costs_suspicion(out[0]), "a press during the breath was free")


func test_out_of_range_names_the_range() -> void:
	# The reason, not merely the refusal: the whiff is the only feedback a rejected
	# kill gets (GDD-02 §9 failure mode 7), and "two metres too far" and "you
	# pressed at an empty street" are different mistakes.
	var reach := KillRules.reach(_t)
	var world := _world({KILLER: [Vector3.ZERO, 0.0], CONTRACT: [_ahead(reach + 0.5), 0.0]})
	assert_eq(_resolve(world, CONTRACT, [CONTRACT])[0], KillVerdict.V.OUT_OF_RANGE)


func test_out_of_cone_names_the_cone() -> void:
	var world := _world({KILLER: [Vector3.ZERO, 0.0], CONTRACT: [Vector3(2.0, 0.0, 0.0), 0.0]})
	assert_eq(_resolve(world, CONTRACT, [CONTRACT])[0], KillVerdict.V.OUT_OF_CONE)


func test_an_empty_street_is_not_the_same_as_a_missed_contract() -> void:
	var world := _world({KILLER: [Vector3.ZERO, 0.0]})
	assert_eq(_resolve(world, CONTRACT, [])[0], KillVerdict.V.NO_TARGET)


func test_the_validation_grace_is_added_and_is_not_a_range_extension() -> void:
	# `TUN-KILL-VALIDATION-GRACE` absorbs quantisation and sub-tick timing so a
	# legitimate kill is not denied by 4 cm. It is small on purpose, so the two
	# numbers are asserted apart: a grace that had quietly grown into a second
	# range would satisfy every other test in this file.
	assert_almost_eq(KillRules.reach(_t), _t.kill_range + _t.kill_validation_grace, 0.0001)
	assert_lt(_t.kill_validation_grace, _t.kill_range * 0.25, "the grace is a range extension now")

	var just_inside := _world(
		{KILLER: [Vector3.ZERO, 0.0], CONTRACT: [_ahead(_t.kill_range + 0.01), 0.0]}
	)
	assert_eq(
		_resolve(just_inside, CONTRACT, [CONTRACT])[0],
		KillVerdict.V.ALLOWED,
		"a kill 1 cm past the bare range was denied — the grace is not being applied"
	)


func test_a_killer_missing_from_the_rewind_costs_nothing() -> void:
	# The ring did not hold them. Not a mistake the player made, so `BUSY` rather
	# than a penalised verdict — and `plays_a_whiff` is false, because the game
	# declining to hear a press must not also perform one.
	var world := _world({CONTRACT: [_ahead(1.0), 0.0]})
	var out := _resolve(world, CONTRACT, [CONTRACT])
	assert_eq(out[0], KillVerdict.V.BUSY, KillVerdict.name_of(out[0]))
	assert_false(KillVerdict.costs_suspicion(out[0]), "a rewind gap charged the player")
	assert_false(KillVerdict.plays_a_whiff(out[0]), "a rewind gap played a whiff")


func test_a_stratum_above_you_is_out_of_reach() -> void:
	# **THE RANGE IS THREE-DIMENSIONAL AND THE CONE IS NOT.** The two are different
	# questions, and getting the range wrong is the more dangerous of the two: the
	# roof stratum sits 3.5 m up, so a horizontal reach would put everybody
	# standing on it inside `TUN-KILL-RANGE` of everybody standing under it.
	var overhead := _world({KILLER: [Vector3.ZERO, 0.0], CONTRACT: [Vector3(0.0, 3.5, 1.0), 0.0]})
	assert_eq(
		_resolve(overhead, CONTRACT, [CONTRACT])[0],
		KillVerdict.V.OUT_OF_RANGE,
		"a contract one stratum up was killable from the street"
	)

	# And a step is not a stratum: half a metre of kerb must not deny a kill.
	var on_a_step := _world({KILLER: [Vector3.ZERO, 0.0], CONTRACT: [Vector3(0.0, 0.5, 1.5), 0.0]})
	assert_eq(_resolve(on_a_step, CONTRACT, [CONTRACT])[0], KillVerdict.V.ALLOWED)


func test_a_dead_target_is_simply_absent() -> void:
	# `KillRules` has no concept of death, and that is deliberate: the caller
	# filters the living into `others`, so there is no second place for the rule to
	# be got wrong. This asserts the omission rather than trusting it.
	var world := _world({KILLER: [Vector3.ZERO, 0.0], CONTRACT: [_ahead(1.0), 0.0]})
	assert_eq(
		_resolve(world, CONTRACT, [])[0],
		KillVerdict.V.NO_TARGET,
		"a target absent from the living list was still killable"
	)
