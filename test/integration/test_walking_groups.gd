## **THE FOUR PROCESSIONS ACTUALLY WALK, AND `WALKING_GROUP` IS REACHABLE.**
## US-0043, GDD-03 §4.1.2.
##
## **THIS IS THE VACUOUS-SUCCESS GUARD FOR THE WHOLE STORY.** Every unit test in
## `test_walking_group.gd` passes against a formation nothing ever joins: the
## slots are in the right places, one of them is free, and the group walks its
## route — with nobody in it. `WALKING_GROUP` was a state nothing could enter
## before this story, and the only assertion that can tell whether that changed is
## one that counts brains in it, in a running crowd.
extends GutTest

const MAP_COLLISION := "res://scenes/map/map_vetraio_collision.tscn"
const MAP_DATA := "res://data/maps/map_vetraio.tres"

## Enough that `CrowdFormations.form()` can staff at least two circuits and still
## leave more civilians standing than walking.
const CROWD := 24

const SEED := 20260816

## Two rebalances at `TUN-CROWD-DIRECTOR-INTERVAL`, plus room to walk.
const TICKS := 70

var _world: Node3D
var _pool: NpcPool
var _director: CrowdDirector
var _ctx: MatchContext
var _map: RID


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_world.add_child((load(MAP_COLLISION) as PackedScene).instantiate())
	_map = get_tree().get_root().get_world_3d().navigation_map

	_pool = NpcPool.new()
	_world.add_child(_pool)
	_director = CrowdDirector.new()
	_world.add_child(_director)

	_ctx = MatchContext.new()
	_ctx.map = load(MAP_DATA) as MapData
	_ctx.match_seed = SEED
	_ctx.rng = RandomNumberGenerator.new()
	_ctx.rng.seed = SEED
	_ctx.crowd = _pool


## The same navigation-map wait as every other crowd test: an unsynced map
## answers with the origin, and `before_each` cannot hold an `await`.
func _stand_up() -> void:
	var started: int = NavigationServer3D.map_get_iteration_id(_map)
	for _i: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_map) >= started + 2:
			break

	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, 6)
	var spots := CrowdPlacement.positions(CROWD, SEED, _ctx.map.idle_anchors, _map)
	for index: int in spots.size():
		_pool.set_position(index, spots[index])
	_director.setup(_ctx)
	_director.form_groups()
	await get_tree().physics_frame


func _run(ticks: int) -> void:
	for _tick: int in ticks:
		_director.tick(_ctx, MatchContext.net_dt())
		await get_tree().physics_frame
		await get_tree().physics_frame


func _slotted() -> int:
	var held := 0
	for group: WalkingGroup in _director.formations().groups:
		held += group.npc_count()
	return held


func _walking() -> int:
	var count := 0
	for index: int in CROWD:
		if _pool.brain_of(index).state == NpcBrain.State.WALKING_GROUP:
			count += 1
	return count


func test_one_group_per_circuit() -> void:
	await _stand_up()
	assert_eq(
		_director.formations().groups.size(),
		_ctx.map.circuits.size(),
		"the director did not build one group per circuit"
	)
	assert_eq(_ctx.map.circuits.size(), int(Tuning.crowd.group_count), "TUN-CROWD-GROUP-COUNT")


func test_npcs_actually_enter_walking_group() -> void:
	# **THE STORY'S REASON TO EXIST.** Before US-0043 this number was zero for
	# every match ever run, and every other crowd test was green.
	await _stand_up()
	await _run(TICKS)
	gut.p("%d of %d NPCs are walking a circuit" % [_walking(), CROWD])
	assert_gt(_slotted(), 0, "no NPC was ever given a formation slot")
	assert_eq(_walking(), _slotted(), "a slot was assigned to a brain that never entered the state")


func test_the_crowd_can_spare_the_processions() -> void:
	# More civilians standing than walking. A district that traded every blend
	# pocket for a travelling corridor would have one hiding strategy, not four.
	await _stand_up()
	await _run(TICKS)
	assert_lt(_slotted() * 2, CROWD + 1, "the processions took more than half the crowd")


func test_the_joinable_slot_is_never_taken_by_an_npc() -> void:
	await _stand_up()
	await _run(TICKS)
	for group: WalkingGroup in _director.formations().groups:
		assert_eq(
			group.occupants[group.joinable_slot()],
			WalkingGroup.EMPTY,
			"an NPC took the slot a player is supposed to be able to rely on"
		)


func test_the_formation_travels_and_its_members_stay_in_it() -> void:
	await _stand_up()
	var groups := _director.formations().groups
	var before := groups[0].slot_position(0)
	await _run(TICKS)
	var travelled := before.distance_to(groups[0].slot_position(0))
	gut.p("group 0 travelled %.2f m in %d ticks" % [travelled, TICKS])
	assert_gt(travelled, 1.0, "the formation did not move")

	# **AND NOBODY WAS LEFT BEHIND.** A slot that outruns its member is a group
	# that sheds people it can never take back, because a civilian may not jog to
	# catch up. `CrowdFormations._pace` is what holds this true.
	var strays: PackedStringArray = []
	for group: WalkingGroup in groups:
		for slot: int in group.slot_count() - 1:
			var npc: int = group.occupants[slot]
			if npc == WalkingGroup.EMPTY:
				continue
			var away := _pool.body_of(npc).global_position - group.slot_position(slot)
			away.y = 0.0
			if away.length() > Tuning.crowd.group_spacing:
				strays.append("npc %d is %.2f m from slot %d" % [npc, away.length(), slot])
	assert_eq(strays.size(), 0, "members fell out of formation:\n" + "\n".join(strays))


func test_a_group_never_outpaces_the_crowd() -> void:
	# The same law `test_crowd_moves.gd` asserts for a strolling NPC, applied to a
	# formation: the walking group is the one blend that lets a player *travel*,
	# and at any speed above `TUN-SPEED-BLENDWALK` it would be a speed cheat
	# wearing a crowd.
	await _stand_up()
	var groups := _director.formations().groups
	var fastest := 0.0
	var dt := MatchContext.net_dt()
	for _tick: int in TICKS:
		var before := groups[0].slot_position(0)
		_director.tick(_ctx, dt)
		await get_tree().physics_frame
		await get_tree().physics_frame
		fastest = maxf(fastest, before.distance_to(groups[0].slot_position(0)) / dt)
	gut.p(
		(
			"fastest formation speed %.3f m/s against a stroll of %.3f"
			% [fastest, Tuning.crowd.npc_speed_stroll]
		)
	)
	assert_lt(fastest, Tuning.crowd.npc_speed_stroll * 1.05, "a walking group outran blend-walk")


func test_a_player_can_take_and_release_the_joinable_slot() -> void:
	# **US-0043's last criterion.** Nothing in a shipping scene calls this yet —
	# `INPUT-BLEND` reaches it through `SYS-BLEND`, which is US-0053 — so the test
	# is what a blend system would do, against the real director.
	await _stand_up()
	var group := _director.formations().groups[0]
	var here := group.slot_position(group.joinable_slot())

	assert_eq(_director.joinable_group(here), 0, "the group beside the player was not offered")
	assert_true(_director.claim_slot(4242, 0), "the slot could not be claimed")
	assert_almost_eq(_director.slot_position_of(4242), here, Vector3.ONE * 0.001)

	# A claimed slot is not offered again, and cannot be stolen.
	assert_eq(_director.joinable_group(here), -1, "a taken slot was offered to somebody else")
	assert_false(_director.claim_slot(77, 0), "a second peer took a slot that was held")

	# It moves with the procession, which is what makes it a *travelling* blend.
	await _run(20)
	assert_gt(
		_director.slot_position_of(4242).distance_to(here), 0.5, "the player's slot did not travel"
	)

	_director.release_slot(4242)
	assert_eq(_director.slot_position_of(4242), Vector3.INF, "a released slot still reported one")
	assert_eq(_director.joinable_group(group.slot_position(group.joinable_slot())), 0)


func test_a_far_away_player_is_offered_nothing() -> void:
	# The join radius is `TUN-BLEND-GROUP-JOIN-RADIUS`, and it matches
	# `TUN-KILL-RANGE` deliberately: the distance at which you can join a group is
	# the distance at which you can be killed in it.
	await _stand_up()
	var group := _director.formations().groups[0]
	var far := group.slot_position(group.joinable_slot()) + Vector3(30.0, 0.0, 30.0)
	assert_eq(_director.joinable_group(far), -1, "a group 42 m away was offered")
