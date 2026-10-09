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


func test_an_older_slot_cannot_rewind_the_velocity() -> void:
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10, 0, 10), 100))
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10.28, 0, 10), 106))
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(30, 0, 10), 103))
	# Standing on the slot: only the slot's own pace moves the player, east at 1.4.
	var command := InputCommand.empty(1)
	command.look_yaw = PI / 2.0
	_follow.steer(command, Vector3(10.28, 0, 10), 0.0)
	assert_gt(command.move.y, 0.0, "the stale slot 20 m away turned the walk round")
	assert_lt(command.move.length(), 1.01)


func test_a_new_connection_starts_the_tick_count_again() -> void:
	_in_a_group()
	_follow.reset()
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10, 0, 10), 5))
	_follow.observe(_snapshot(BlendKind.Kind.GROUP, Vector3(10.14, 0, 10), 8))
	var command := InputCommand.empty(1)
	_follow.steer(command, Vector3(9.5, 0, 10), 0.1)
	assert_true(command.follow, "a new server's low ticks were taken for stale ones")
