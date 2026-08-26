## **THE CROWD HIDES YOU BY BEING CONFUSING, NEVER BY BEING SOLID.** US-0056,
## GDD-03 §9.2, TDD-07 §4.2.
##
## A wall of ten NPCs between two players does not block line of sight. This is
## counterintuitive and it is the whole difference between social stealth and
## cover shooting: if NPCs occluded sight, a dense crowd would be *mechanically*
## opaque, and the skill of picking a person out of one would be replaced by a
## visibility calculation the player cannot see.
##
## **THE RULE IS THE COLLISION MASK, NOT A FILTER.** `has_los` masks `WORLD` only,
## and every NPC, player and corpse sits on `PAWN` or `NPC` — so the query cannot
## see them however it is written, and a later caller cannot get it wrong.
extends GutTest

const FAR := Vector3(0.0, 0.0, 20.0)

var _system: DetectionSystem
var _ctx: MatchContext


func before_each() -> void:
	_system = DetectionSystem.new()
	add_child_autofree(_system)
	_ctx = MatchContext.new()
	_system.setup(_ctx)


## A `StaticBody3D` on `layer` with a 2 m box at `at`. Layer 1 is `WORLD`, 2 is
## `PAWN`, 3 is `NPC` — `project.godot`'s names, and the reason the mask is a rule.
func _body_at(at: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (layer - 1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# **TALL ENOUGH TO STAND IN THE RAY'S WAY.** The sight line runs at
	# `TUN-TRAVERSE-PROBE-HEIGHT-CHEST` 1.35 m, so a 2 m box centred on the ground
	# passes *under* it — the first version of this test did exactly that and read
	# "a wall did not block line of sight", which looks like a defect in the query.
	box.size = Vector3(2.0, 6.0, 2.0)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = at
	return body


func _look() -> bool:
	await get_tree().physics_frame
	return _system.has_los(
		DetectionSystem.sight_point(Vector3.ZERO), DetectionSystem.sight_point(FAR)
	)


func test_an_empty_street_is_clear() -> void:
	# **THE PREMISE.** Without it every assertion below could pass on a query that
	# always answers false, and "the crowd does not block" would be true of a
	# system in which nothing is ever visible.
	assert_true(await _look(), "an empty street blocked line of sight")


func test_a_wall_blocks() -> void:
	# The other premise, and the counterfactual for the crowd tests: a query that
	# always answered true would satisfy those perfectly.
	_body_at(Vector3(0.0, 0.0, 10.0), 1)
	assert_false(await _look(), "a wall did not block line of sight")


func test_a_wall_of_ten_npcs_does_not_block() -> void:
	for i: int in 10:
		_body_at(Vector3(float(i) * 0.4 - 1.8, 0.0, 10.0), 3)
	assert_true(await _look(), "a crowd blocked line of sight — the crowd became solid")


func test_another_player_does_not_block_either() -> void:
	# A body standing between two players is not cover. Neither the pawn layer nor
	# a corpse on it may hide anybody: hiding is the crowd's job and it does it by
	# confusion.
	_body_at(Vector3(0.0, 0.0, 10.0), 2)
	assert_true(await _look(), "another player blocked line of sight")


func test_the_mask_is_world_and_nothing_else() -> void:
	# The structural half. A mask that had grown a bit would pass every behavioural
	# test above the moment the extra layer happened to be empty.
	var probe := PhysicsRayQueryParameters3D.new()
	probe.collision_mask = 1
	assert_eq(
		_query_mask(),
		probe.collision_mask,
		"has_los no longer masks WORLD alone — NPCs or players can block sight"
	)


## The mask the system actually configured, read back off it.
func _query_mask() -> int:
	var query := _system.get("_query") as PhysicsRayQueryParameters3D
	return query.collision_mask if query != null else -1


func test_a_cinder_cloud_blocks_and_an_expired_one_does_not() -> void:
	# `TUN-CINDERFALL-BLOCKS-LOS` is the one thing that stops sight and is not
	# geometry, and it is checked against the **segment** rather than the endpoints:
	# a cloud placed in the gap touches neither player, which is the point of area
	# denial.
	assert_true(await _look(), "the premise failed")
	_system.cinderfall.add(FAR * 0.5, 0)
	assert_false(await _look(), "a cinder cloud across the line did not block it")

	# **A CLOUD IS ALIVE AT A TICK, NOT SIMPLY ALIVE** (US-0060). Advancing the
	# context is what puts the query past the cloud's expiry — the volume list is
	# consulted with a tick now, so that a rewound kill validation can ask about a
	# cloud that has since gone out. Asking at tick 0 forever would answer "lit".
	var duration := Tuning.ticks(&"TUN-CINDERFALL-DURATION")
	_ctx.tick = duration + 1
	assert_eq(_system.cinderfall.count_at(_ctx.tick), 0, "an expired cloud was still alight")
	assert_true(await _look(), "an expired cloud still blocked")


func test_a_burnt_out_cloud_is_kept_until_no_rewind_can_reach_it() -> void:
	# **`expire()` LAGS THE REWIND CEILING RATHER THAN THE EXPIRY**, and that is
	# what makes ADR-0010's rule implementable: *"one that has expired must still
	# have blocked"* a kill validated `TUN-NET-LAGCOMP-MAX` in the past. Dropping
	# the cloud on the tick it went out would answer that half wrongly, and there
	# would be nothing left to ask.
	_system.cinderfall.add(FAR * 0.5, 0)
	var duration := Tuning.ticks(&"TUN-CINDERFALL-DURATION")
	_system.cinderfall.expire(duration + 1)
	assert_eq(_system.cinderfall.count(), 1, "the cloud was dropped while a rewind could reach it")
	assert_eq(_system.cinderfall.count_at(duration + 1), 0, "it was still alight after its expiry")
	assert_true(
		_system.cinderfall.contains_at(FAR * 0.5, duration - 1),
		"a rewind to before the expiry could not see it"
	)

	# And it does go eventually, or a long match would accumulate every cloud.
	_system.cinderfall.expire(duration + RewindClamp.max_ticks())
	assert_eq(_system.cinderfall.count(), 0, "a cloud no rewind can reach was kept forever")


func test_a_cloud_beside_the_line_does_not_block() -> void:
	# The counterfactual for the test above: a `blocks()` that always answered true
	# would satisfy it.
	_system.cinderfall.add(Vector3(40.0, 0.0, 10.0), 0)
	assert_true(await _look(), "a cloud 40 m to one side blocked the line")


func test_the_rewound_form_is_refused_rather_than_faked() -> void:
	# **A REWOUND QUERY AGAINST THE WORLD ALONE WOULD LOOK CORRECT.** The geometry
	# does not move, so it would answer exactly as a current one — while the players
	# it is really about sat at today's positions. `SYS-KILL` (US-0060) is what
	# pairs this with `RewoundWorld`; until then the argument is refused.
	assert_false(
		_system.has_los(Vector3.ZERO, FAR, 40), "a rewound line of sight answered as if it worked"
	)
	assert_eq(_system.rewinds_refused, 1, "the refusal was silent — nothing would report it")
