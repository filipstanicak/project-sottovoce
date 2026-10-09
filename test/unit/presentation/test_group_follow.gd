## **THE CLIENT WALKS THE PLAYER ONLY WHILE THEY KEEP THEIR HANDS OFF.** US-0107.
extends GutTest

var _follow: GroupFollow


func before_each() -> void:
	_follow = GroupFollow.new()


func _snapshot(kind: int, slot: Vector3, tick: int) -> Snapshot:
	var snapshot := Snapshot.new()
	snapshot.blend_state = kind
	snapshot.blend_slot = slot
	snapshot.server_tick = tick
	return snapshot


func _in_a_group() -> void:
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10, 0, 10), 100))
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10.14, 0, 10), 103))


func test_in_a_group_an_idle_command_is_steered_and_marked() -> void:
	_in_a_group()
	var command := InputCommand.empty(1)
	_follow.steer(command, Vector3(9.5, 0, 10), 0.1)
	assert_true(command.follow)
	assert_true(command.wants_movement(), "a player behind the slot was not walked toward it")


func test_touching_the_stick_hands_control_back() -> void:
	_in_a_group()
	var command := InputCommand.empty(1)
	command.move = Vector2(-1, 0)
	_follow.steer(command, Vector3(9.5, 0, 10), 0.1)
	assert_false(command.follow)
	assert_eq(command.move, Vector2(-1, 0), "the player's own stick was overwritten")


func test_an_action_is_aimed_where_the_player_looks() -> void:
	_in_a_group()
	for bit: int in [InputBits.KILL, InputBits.STUN, InputBits.BLEND, InputBits.ABILITY_1]:
		var command := InputCommand.empty(1)
		command.buttons = bit
		_follow.steer(command, Vector3(9.5, 0, 10), 0.1)
		assert_false(command.follow, "bit %d was steered, so the pawn faced its travel" % bit)


func test_outside_a_group_nothing_is_touched() -> void:
	_follow.observe(_snapshot(BlendKind.Kind.POCKET, Vector3(10, 0, 10), 100))
	var command := InputCommand.empty(1)
	_follow.steer(command, Vector3(9.5, 0, 10), 0.1)
	assert_false(command.follow)
	assert_false(command.wants_movement())


func test_the_slot_velocity_is_read_from_consecutive_snapshots() -> void:
	_in_a_group()
	# 0.14 m in three ticks of 30 Hz is 1.4 m/s: standing on the slot, the player is
	# walked at the group's pace rather than left standing.
	var command := InputCommand.empty(1)
	_follow.steer(command, Vector3(10.14, 0, 10), 0.0)
	assert_true(command.wants_movement(), "a player on a moving slot was left standing")


## **A LATE GROUP SNAPSHOT DOES NOT PUT THE PLAYER BACK IN THE GROUP** (review of
## #253). The state channel is unordered: GROUP at 103 arriving after NONE at 104
## switched the walking back on after the server had ended the blend.
func test_a_stale_group_snapshot_after_the_exit_is_ignored() -> void:
	_in_a_group()
	_follow.observe(_snapshot(BlendKind.Kind.NONE, Vector3.ZERO, 104))
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10.14, 0, 10), 103))
	var command := InputCommand.empty(1)
	_follow.steer(command, Vector3(9.5, 0, 10), 0.1)
	assert_false(command.follow, "the exit was undone by a packet older than it")
	assert_false(command.wants_movement())


## Standing on the newest slot, facing east: the command `follow` produces.
func _standing_on(follow: GroupFollow, here: Vector3) -> InputCommand:
	var command := InputCommand.empty(1)
	command.look_yaw = PI / 2.0
	follow.steer(command, here, 0.0)
	return command


## **A STALE SLOT OF THE SAME GROUP IS IGNORED TOO** (second review of #253): an
## older slot ahead of the real one still points east, so only a comparison with a
## clean sequence tells the two apart. 0.28 m in six ticks is 1.4 m/s, blend-walk.
func test_an_older_slot_cannot_rewind_the_velocity() -> void:
	var clean := GroupFollow.new()
	for follow: GroupFollow in [_follow, clean]:
		follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10, 0, 10), 100))
		follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10.28, 0, 10), 106))
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10.5, 0, 10), 103))
	var command := _standing_on(_follow, Vector3(10.28, 0, 10))
	var control := _standing_on(clean, Vector3(10.28, 0, 10))
	assert_eq(command.move, control.move, "an older slot changed the walk")
	assert_eq(command.slow, control.slow, "an older slot changed the walking pace")
	assert_true(command.slow, "the group's 1.4 m/s was not walked at blend-walk")
	assert_almost_eq(command.move.length() * Tuning.movement.blend_walk, 1.4, 0.02)
	# And the next real slot is measured from 106, not from the stale one.
	for follow: GroupFollow in [_follow, clean]:
		follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10.42, 0, 10), 109))
	command = _standing_on(_follow, Vector3(10.42, 0, 10))
	control = _standing_on(clean, Vector3(10.42, 0, 10))
	assert_eq(command.move, control.move, "the velocity was measured from the stale slot")


func test_a_new_connection_starts_the_tick_count_again() -> void:
	_in_a_group()
	_follow.reset()
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10, 0, 10), 5))
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10.14, 0, 10), 8))
	var command := InputCommand.empty(1)
	_follow.steer(command, Vector3(9.5, 0, 10), 0.1)
	assert_true(command.follow, "a new server's low ticks were taken for stale ones")
