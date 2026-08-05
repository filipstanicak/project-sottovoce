## The reconciliation buffer holds what the server has not yet answered.
##
## The second of the two buffers US-0016 delivers, and the one that is CLIENT
## ONLY — the mirror image of `PawnInputBuffer`, which must exist on both peers
## because it changes the simulation. This one exists because the client has
## predicted forward past the server's last word, and when a correction lands
## everything after it is replayed.
##
## Replay itself is US-0033. What is asserted here is that the storage cannot
## lose an unacked command, and cannot keep one that no longer matters.
extends GutTest

var _history: InputHistory


func before_each() -> void:
	_history = InputHistory.new()


func _push(seq: int) -> void:
	_history.push(InputCommand.empty(seq))


func test_capacity_comes_from_the_tunable() -> void:
	assert_eq(_history.capacity(), Tuning.net.input_buffer_size)
	assert_eq(_history.capacity(), 32, "TUN-NET-INPUT-BUFFER-SIZE moved without this test noticing")


func test_it_keeps_commands_in_replay_order() -> void:
	for seq: int in range(1, 6):
		_push(seq)
	var pending := _history.unacked()
	assert_eq(pending.size(), 5)
	assert_eq(pending[0].seq, 1, "the oldest unacked command is not first")
	assert_eq(pending[4].seq, 5)


func test_it_stores_copies_and_not_references() -> void:
	# The sampler reuses ONE command object. A history holding live references
	# would rewrite its own past every frame, and the replay would apply this
	# frame's input to every unacked tick.
	var live := InputCommand.empty(1)
	live.sprint = true
	_history.push(live)
	live.sprint = false
	live.seq = 99

	var stored := _history.unacked()[0]
	assert_true(stored.sprint, "the stored command followed the live one")
	assert_eq(stored.seq, 1)


func test_an_ack_drops_everything_up_to_and_including_it() -> void:
	for seq: int in range(1, 6):
		_push(seq)
	_history.ack(3)
	assert_eq(_history.size(), 2)
	assert_eq(_history.oldest_seq(), 4, "an acked command is still awaiting replay")
	assert_eq(_history.newest_seq(), 5)


func test_an_ack_for_something_older_than_everything_changes_nothing() -> void:
	# Duplicate and out-of-order acks are normal on an unreliable channel.
	_push(10)
	_push(11)
	_history.ack(4)
	assert_eq(_history.size(), 2)


func test_an_ack_past_the_newest_empties_it() -> void:
	_push(1)
	_push(2)
	_history.ack(99)
	assert_true(_history.is_empty())
	assert_eq(_history.oldest_seq(), -1)


func test_overflow_drops_the_oldest_and_says_so() -> void:
	# 32 commands is about 530 ms. A command older than that cannot be reconciled
	# against anything — the server either acked it long ago or the connection is
	# failing, and holding the input does not fix the second case.
	for seq: int in range(1, _history.capacity() + 4):
		_push(seq)
	assert_eq(_history.size(), _history.capacity(), "the buffer grew past its bound")
	assert_eq(_history.overflowed, 3, "dropped commands were not counted")
	assert_eq(_history.oldest_seq(), 4, "overflow dropped the wrong end")


func test_the_overflow_count_is_cumulative() -> void:
	# It is a connection-health figure. A counter that reset would hide a stall
	# that happened between two glances at it.
	for seq: int in range(1, _history.capacity() + 2):
		_push(seq)
	var first := _history.overflowed
	_history.ack(99)
	for seq: int in range(100, 100 + _history.capacity() + 2):
		_push(seq)
	assert_gt(_history.overflowed, first, "the overflow counter was reset")


func test_clear_discards_everything() -> void:
	# A respawn or a rejoin makes the authoritative state unrelated to anything
	# the client predicted, so there is nothing left worth replaying.
	for seq: int in range(1, 6):
		_push(seq)
	_history.clear()
	assert_true(_history.is_empty())
	assert_eq(_history.newest_seq(), -1)
