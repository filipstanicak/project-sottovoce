## The reconciliation buffer: unacknowledged `InputCommand`s, oldest first.
##
## **CLIENT ONLY**, and that is the difference between this buffer and the action
## buffer (`PawnInputBuffer`). This one exists because the client has predicted
## forward past what the server has answered; when a correction arrives for
## `seq`, everything after `seq` is replayed on top of the authoritative state.
## The server never needs it, because the server was never ahead.
##
## Bounded at `TUN-NET-INPUT-BUFFER-SIZE` 32 commands — about 530 ms at
## `TUN-NET-CLIENT-INPUT-RATE` 60 Hz. **Overflow drops the OLDEST**, because a
## command that old can no longer be reconciled against anything: the server
## either acked it long ago or the connection is failing, and in the second case
## holding the input does not fix it. `overflowed` counts the drops rather than
## hiding them; a non-zero count is a connection diagnostic, not a buffer tuning
## problem.
##
## Replay itself is US-0033. This is the storage, and the storage is US-0016's
## half of "dual input buffering".
class_name InputHistory
extends RefCounted

## Commands dropped because the buffer was full. Never reset — it is a
## cumulative connection-health figure, and a counter that resets hides a stall.
var overflowed: int = 0

## Oldest first. `Array` and not a fixed ring because the size is 32 and the
## clarity is worth more than the allocation, which happens 60 times a second
## against a budget measured in thousands.
var _pending: Array[InputCommand] = []

## The predicted state after each pending command, by index. Kept beside the
## commands rather than inside them: an `InputCommand` is what the wire carries,
## and a field the server never sees does not belong in it.
var _states: Array = []


func capacity() -> int:
	return Tuning.net.input_buffer_size


func size() -> int:
	return _pending.size()


func is_empty() -> bool:
	return _pending.is_empty()


## Store a command that has been sent but not acknowledged. Stores a COPY: the
## sampler reuses its command object, and a history holding live references would
## rewrite its own past every frame.
func push(command: InputCommand, state: PredictedState = null) -> void:
	_pending.append(command.duplicate_command())
	_states.append(state)
	while _pending.size() > capacity():
		_pending.pop_front()
		_states.pop_front()
		overflowed += 1


## Drop everything at or before `acked_seq`. The server acks the last command it
## processed, so that command is authoritative and no longer needs replaying.
##
## **COMPARED ACROSS THE WRAP, NOT WITH `<=`.** `seq` is a `u16` sent 60 times a
## second, so it rolls over about every 18 minutes — inside a match. A plain
## comparison stops discarding at the wrap and the buffer fills with commands the
## server answered long ago; the replay then re-runs eighteen minutes of input
## every snapshot. `SequenceGate.is_newer()` is the same arithmetic the server's
## gate uses, which is the point: both ends must agree on what "already answered"
## means.
func ack(acked_seq: int) -> void:
	while not _pending.is_empty() and not SequenceGate.is_newer(_pending[0].seq, acked_seq):
		_pending.pop_front()
		_states.pop_front()


## Everything still awaiting an answer, oldest first — the replay order.
func unacked() -> Array[InputCommand]:
	return _pending.duplicate()


## The oldest unacked sequence number, or -1 when nothing is pending.
func oldest_seq() -> int:
	return -1 if _pending.is_empty() else _pending[0].seq


func newest_seq() -> int:
	return -1 if _pending.is_empty() else _pending[-1].seq


## What the client predicted after the command with this sequence, or null.
##
## Null is the ordinary answer, not an error: the buffer only holds what is still
## unacked, so a snapshot acking something already discarded — or something never
## sent — has nothing to compare against, and the caller must smooth rather than
## guess.
func state_at(seq: int) -> PredictedState:
	for i: int in _pending.size():
		if _pending[i].seq == seq:
			return _states[i] as PredictedState
	return null


## Discard everything. Called on a hard reset — a respawn or a rejoin — where the
## authoritative state is unrelated to anything the client predicted.
func clear() -> void:
	_pending.clear()
	_states.clear()
