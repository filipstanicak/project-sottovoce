## **THE HASH AGREES WITH BRUTE FORCE, A THOUSAND TIMES.** US-0042, TDD-08 §6.
##
## The whole point of this structure is that it gives the *same* answer as the
## O(pawns × NPCs) scan it replaces, faster. So the test is not a description of
## the grid — it is the scan, run beside it, on random input.
##
## **A COMPARISON OF TWO EMPTY ANSWERS PASSES.** Every equivalence test here
## therefore counts how many of its queries actually found somebody and refuses
## to pass if that number is small: a hash that returned nothing at all would
## otherwise agree with brute force whenever brute force found nothing, which on
## random points is most of the time. Trap 3's family, and the reason this file
## opens with it.
extends GutTest

const BOUNDS := AABB(Vector3.ZERO, Vector3(120.0, 12.0, 120.0))
const CROWD := 90
const SEED := 20260816

var _hash: SpatialHash
var _rng: RandomNumberGenerator
var _points: PackedVector3Array
var _roster: Array[StringName] = []


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = SEED
	_points = PackedVector3Array()
	_roster = []
	for i: int in CROWD:
		_points.append(Vector3(_rng.randf_range(0.0, 120.0), 0.0, _rng.randf_range(0.0, 120.0)))
		_roster.append(CrowdRoster.PLAYABLE[i % CrowdRoster.PLAYABLE.size()])
	_hash = SpatialHash.new()
	_hash.setup(BOUNDS, CROWD)
	_hash.rebuild(_points, _roster, CROWD)


## Brute force. Horizontal, like the hash — see `_flat_distance_squared`.
func _brute(centre: Vector3, radius: float) -> Array:
	var out: Array = []
	for i: int in CROWD:
		var flat := Vector2(_points[i].x - centre.x, _points[i].z - centre.z)
		if flat.length() <= radius:
			out.append(i)
	return out


func test_the_cell_size_is_the_open_ground_radius() -> void:
	# **NOT "IS 6.0".** The criterion is that the hottest query in the project —
	# is any NPC within `TUN-SUSPICION-OPEN-RADIUS` — touches at most four cells,
	# and that stays true only while the two numbers are the same number.
	assert_almost_eq(_hash.cell_size, Tuning.suspicion.open_radius, 0.0001)


func test_query_matches_brute_force_over_a_thousand_random_queries() -> void:
	# The story's own criterion, and the file's reason to exist.
	var found_something := 0
	for _i: int in 1000:
		var centre := Vector3(_rng.randf_range(-10.0, 130.0), 0.0, _rng.randf_range(-10.0, 130.0))
		var radius := _rng.randf_range(0.5, 20.0)
		var expected := _brute(centre, radius)
		var actual := Array(_hash.query(centre, radius))
		expected.sort()
		actual.sort()
		if not expected.is_empty():
			found_something += 1
		assert_eq(actual, expected, "hash and brute force disagree at %v r=%.2f" % [centre, radius])
	gut.p("%d of 1000 random queries found at least one NPC" % found_something)
	assert_gt(found_something, 500, "almost no query found anybody — the comparison is vacuous")


func test_count_within_matches_brute_force() -> void:
	var non_empty := 0
	for _i: int in 300:
		var centre := Vector3(_rng.randf_range(0.0, 120.0), 0.0, _rng.randf_range(0.0, 120.0))
		var radius := _rng.randf_range(1.0, 12.0)
		var expected: int = _brute(centre, radius).size()
		if expected > 0:
			non_empty += 1
		assert_eq(_hash.count_within(centre, radius), expected, "count_within disagreed")
	assert_gt(non_empty, 100, "almost no query counted anybody — the comparison is vacuous")


func test_count_persona_counts_only_that_persona() -> void:
	var target: StringName = CrowdRoster.PLAYABLE[0]
	var total := 0
	for _i: int in 200:
		var centre := Vector3(_rng.randf_range(0.0, 120.0), 0.0, _rng.randf_range(0.0, 120.0))
		var radius := _rng.randf_range(5.0, 25.0)
		var expected := 0
		for i: int in _brute(centre, radius):
			if _roster[i] == target:
				expected += 1
		total += expected
		assert_eq(_hash.count_persona(centre, radius, target), expected, "count_persona disagreed")
	assert_gt(total, 50, "no persona was ever counted — the comparison is vacuous")


func test_count_persona_is_not_just_count_within() -> void:
	# The roster is a quarter of each persona, so the two must differ somewhere.
	# Without this, a `count_persona` that ignored the identity would pass above
	# whenever the neighbourhood happened to be all one persona.
	var differed := false
	for _i: int in 200:
		var centre := Vector3(_rng.randf_range(0.0, 120.0), 0.0, _rng.randf_range(0.0, 120.0))
		if (
			_hash.count_persona(centre, 20.0, CrowdRoster.PLAYABLE[0])
			!= _hash.count_within(centre, 20.0)
		):
			differed = true
			break
	assert_true(differed, "count_persona never differed from count_within — it ignores identity")


func test_nearest_distance_matches_brute_force_when_somebody_is_inside() -> void:
	var inside := 0
	for _i: int in 300:
		var centre := Vector3(_rng.randf_range(0.0, 120.0), 0.0, _rng.randf_range(0.0, 120.0))
		var within := 6.0
		var expected := INF
		for i: int in _brute(centre, within):
			var flat := Vector2(_points[i].x - centre.x, _points[i].z - centre.z)
			expected = minf(expected, flat.length())
		var actual := _hash.nearest_distance(centre, within)
		if expected < INF:
			inside += 1
			assert_almost_eq(actual, expected, 0.001, "nearest_distance disagreed at %v" % centre)
		else:
			assert_eq(actual, INF, "nearest_distance found somebody brute force did not")
	assert_gt(inside, 50, "nobody was ever within 6 m — the comparison is vacuous")


func test_nearest_distance_is_bounded_rather_than_unbounded() -> void:
	# The deliberate deviation from TDD-08 §6's signature. An empty district must
	# answer INF rather than widening its search until it finds somebody, because
	# that is the O(n) scan this whole file exists to avoid — and it would arrive
	# exactly when the map is emptiest.
	var lonely := SpatialHash.new()
	lonely.setup(BOUNDS, 2)
	var far := PackedVector3Array([Vector3(5.0, 0.0, 5.0), Vector3(110.0, 0.0, 110.0)])
	lonely.rebuild(far, [], 2)
	assert_eq(lonely.nearest_distance(Vector3(60.0, 0.0, 60.0), 6.0), INF)
	assert_almost_eq(lonely.nearest_distance(Vector3(7.0, 0.0, 5.0), 6.0), 2.0, 0.001)


func test_distance_is_horizontal_so_a_balcony_does_not_empty_the_street() -> void:
	# **HEIGHT MUST NOT COUNT.** A player 3.5 m up on the Loggia balcony is not
	# alone for `TUN-SUSPICION-GAIN-OPEN` — the rule that charges them for being up
	# there is `TUN-SUSPICION-GAIN-ROOF`, and a 3D radius would charge it twice.
	var stacked := SpatialHash.new()
	stacked.setup(BOUNDS, 1)
	stacked.rebuild(PackedVector3Array([Vector3(60.0, 0.0, 60.0)]), [], 1)
	assert_eq(stacked.count_within(Vector3(60.0, 8.5, 60.0), 1.0), 1, "height emptied the radius")


func test_somebody_outside_the_map_is_still_found_next_to_them() -> void:
	# The grid clamps out-of-bounds entities into a border cell rather than
	# refusing them. Refusing would make an NPC invisible to a query standing
	# right beside it — a silent hole at the map edge, where the canal is.
	var edge := SpatialHash.new()
	edge.setup(BOUNDS, 1)
	edge.rebuild(PackedVector3Array([Vector3(-4.0, 0.0, 60.0)]), [], 1)
	assert_eq(edge.count_within(Vector3(-3.0, 0.0, 60.0), 2.0), 1, "an out-of-map entity vanished")
	assert_eq(edge.count_within(Vector3(20.0, 0.0, 60.0), 2.0), 0, "it was found where it is not")


func test_rebuilding_replaces_rather_than_accumulates() -> void:
	# A counting sort that forgot to zero `_starts` would keep last tick's crowd
	# alongside this one, and the symptom would be blend pockets that never
	# dissolve — a player safe in a pocket that has walked away.
	_hash.rebuild(PackedVector3Array([Vector3(10.0, 0.0, 10.0)]), [], 1)
	assert_eq(_hash.count(), 1)
	assert_eq(_hash.count_within(Vector3(10.0, 0.0, 10.0), 60.0), 1, "old entries survived")


func test_a_shorter_count_hides_the_inactive_tail() -> void:
	# The pool is sized to 90 and a four-player match activates 66. The other 24
	# sit at the origin, and indexing them would put a phantom pocket in the
	# corner of the district.
	_hash.rebuild(_points, _roster, 10)
	assert_eq(_hash.count(), 10)
	for i: int in _hash.query(Vector3(60.0, 0.0, 60.0), 200.0):
		assert_lt(i, 10, "an inactive NPC was indexed")


func test_a_rebuild_costs_less_than_the_budgeted_tick() -> void:
	# **US-0042's fifth criterion: 0.15 ms for 90 NPCs.** Measured over a thousand
	# rebuilds, because one is far below the clock's resolution.
	#
	# The bound asserted is deliberately looser than the budget and the *measured*
	# figure is printed beside it. A timing assertion at exactly the budget on
	# shared CI hardware is a flaky test, and a flaky test gets a wider threshold
	# until it means nothing — which is how a real regression ships. The number in
	# the log is the evidence; the assertion is only a tripwire for an
	# order-of-magnitude change.
	var started := Time.get_ticks_usec()
	for _i: int in 1000:
		_hash.rebuild(_points, _roster, CROWD)
	var each := float(Time.get_ticks_usec() - started) / 1000.0
	gut.p("rebuild of %d NPCs: %.4f ms, against a 0.15 ms budget" % [CROWD, each / 1000.0])
	assert_lt(each / 1000.0, 1.5, "a rebuild is an order of magnitude over TDD-08 §11.2's budget")


func test_an_empty_hash_answers_rather_than_crashes() -> void:
	# Every client and the integration harness hold a context with no crowd.
	var empty := SpatialHash.new()
	assert_eq(empty.count_within(Vector3.ZERO, 5.0), 0)
	assert_eq(empty.count_persona(Vector3.ZERO, 5.0, &"anything"), 0)
	assert_eq(empty.nearest_distance(Vector3.ZERO, 5.0), INF)
	assert_eq(empty.query(Vector3.ZERO, 5.0).size(), 0)
