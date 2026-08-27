## **THE TWO CONSTRAINTS AND THE FALLBACK THAT CANNOT FAIL.** GDD-05 §2.7 rules
## 2, 3 and 7, TDD-10 §6, US-0062.
##
## `SpawnRules` is pure, so the case that matters most — a lobby packed tightly
## enough to veto every spawn point — can be constructed here in three lines
## rather than waited for in a playtest. **ASM-0014: a spawn system that can fail
## is a crash waiting for a playtest**, and the way that stays true is that
## `choose()` has no failing branch to reach.
extends GutTest

## Six points on a line, 40 m apart. Not the real map — the real map is asserted
## by `test_spawn_points.gd`, and geometry that answers to arithmetic is what
## makes a constraint test readable.
const STEP := 40.0

var _points: Array[Vector3] = []
var _t: ContractTuning
var _rng: RandomNumberGenerator


func before_each() -> void:
	_t = Tuning.contract
	_points = []
	for i: int in 6:
		_points.append(Vector3(float(i) * STEP, 0.0, 0.0))
	_rng = RandomNumberGenerator.new()
	_rng.seed = 12345


func _at(index: int) -> Vector3:
	return _points[index]


func test_it_always_returns_a_point() -> void:
	# **THE PREMISE.** Every assertion below is about *which* point; this one is
	# about there being one at all, which is rule 7's whole content.
	var index := SpawnRules.choose(_points, SpawnRules.NO_KILLER, PackedVector3Array(), _t, _rng)
	assert_between(index, 0, _points.size() - 1, "choose() returned %d" % index)


func test_the_killer_pushes_the_spawn_beyond_forty_metres() -> void:
	var killer := _at(0)
	for _i: int in 20:
		var index := SpawnRules.choose(_points, killer, PackedVector3Array(), _t, _rng)
		assert_gte(
			_at(index).distance_to(killer),
			_t.respawn_min_dist_from_killer,
			"spawned %.1f m from the killer" % _at(index).distance_to(killer)
		)


func test_a_living_player_pushes_the_spawn_twelve_metres_clear() -> void:
	# Rule 3 is about *every* living player, not the nearest one, so the fixture
	# stands somebody on four of the six points.
	var others := PackedVector3Array([_at(0), _at(1), _at(2), _at(3)])
	for _i: int in 20:
		var index := SpawnRules.choose(_points, SpawnRules.NO_KILLER, others, _t, _rng)
		for other: Vector3 in others:
			assert_gte(
				_at(index).distance_to(other),
				_t.min_dist_from_any_player,
				"spawned %.1f m from a living player" % _at(index).distance_to(other)
			)


func test_the_two_constraints_apply_together() -> void:
	# The killer at one end and the rest of the lobby in the middle. Only the far
	# end satisfies both, and it is what must come back every time.
	var killer := _at(0)
	var others := PackedVector3Array([_at(1), _at(2), _at(3), _at(4)])
	var chosen: Dictionary = {}
	for _i: int in 30:
		chosen[SpawnRules.choose(_points, killer, others, _t, _rng)] = true
	assert_eq(chosen.keys(), [5], "the only legal point is 5; got %s" % [chosen.keys()])


func test_the_fallback_is_the_farthest_from_the_killer() -> void:
	# **THE CASE THAT CANNOT FAIL.** Somebody standing on every point vetoes all
	# six under rule 3, so the constraints are unsatisfiable and rule 7 decides.
	var everywhere := PackedVector3Array(_points)
	var killer := _at(0)
	assert_true(
		SpawnRules.candidates(_points, killer, everywhere, _t).is_empty(),
		"the fixture did not actually make the constraints unsatisfiable"
	)
	var index := SpawnRules.choose(_points, killer, everywhere, _t, _rng)
	assert_eq(index, 5, "the fallback did not pick the point furthest from the killer")


func test_the_fallback_is_deterministic() -> void:
	# It runs at the worst moment in a match, and the least bad answer is a
	# property of the world rather than a draw. A random pick here would make the
	# one case a seed cannot reproduce the one that matters most.
	var everywhere := PackedVector3Array(_points)
	var first := SpawnRules.choose(_points, _at(0), everywhere, _t, _rng)
	for _i: int in 20:
		assert_eq(
			SpawnRules.choose(_points, _at(0), everywhere, _t, _rng),
			first,
			"the fallback answered differently on an identical world"
		)


func test_with_no_killer_the_fallback_maximises_clearance_from_the_lobby() -> void:
	# A join rather than a respawn. "Furthest from the killer" has no meaning, so
	# the same question is asked of the lobby: get as far from the nearest person
	# as the map allows.
	var crowd := PackedVector3Array([_at(0), _at(1), _at(2), _at(3), _at(4), _at(5)])
	crowd[5] = _at(5) + Vector3(0.0, 0.0, 6.0)
	var index := SpawnRules.choose(_points, SpawnRules.NO_KILLER, crowd, _t, _rng)
	assert_eq(index, 5, "the fallback ignored the one point with room around it")


func test_no_killer_is_infinity_and_not_the_origin() -> void:
	# **THE ORIGIN IS A REAL PLACE ON THIS MAP.** `Vector3.ZERO` as the sentinel
	# would push every joining player away from the district's own corner for no
	# reason, and it would look like a spawn-distribution bug.
	assert_eq(SpawnRules.NO_KILLER, Vector3.INF, "the no-killer sentinel is a position")
	assert_true(
		SpawnRules.clear_of_killer(Vector3.ZERO, SpawnRules.NO_KILLER, _t),
		"standing at the origin was treated as standing on the killer"
	)


func test_a_map_with_no_spawn_points_answers_minus_one_rather_than_crashing() -> void:
	var empty: Array[Vector3] = []
	assert_eq(
		SpawnRules.choose(empty, SpawnRules.NO_KILLER, PackedVector3Array(), _t, _rng),
		-1,
		"an empty map produced a spawn index"
	)


func test_the_choice_is_seeded_and_reproducible() -> void:
	# Never-do #8: gameplay randomness comes from the seeded generator, so two
	# servers replaying one seed place the same death identically.
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 999
	b.seed = 999
	var first: Array[int] = []
	var second: Array[int] = []
	for _i: int in 25:
		first.append(SpawnRules.choose(_points, SpawnRules.NO_KILLER, PackedVector3Array(), _t, a))
		second.append(SpawnRules.choose(_points, SpawnRules.NO_KILLER, PackedVector3Array(), _t, b))
	assert_eq(first, second, "two servers on one seed placed the same respawn differently")
	assert_gt(
		_distinct(first), 1, "the choice never varies at all; it is not drawing from the generator"
	)


func _distinct(values: Array[int]) -> int:
	var seen: Dictionary = {}
	for v: int in values:
		seen[v] = true
	return seen.size()
