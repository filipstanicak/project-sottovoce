## The buffer remembers what it predicted, and forgets what was answered.
## TDD-04 §4.2, US-0032.
extends GutTest

var _history: InputHistory


func before_each() -> void:
	_history = InputHistory.new()


func _push(seq: int, x: float) -> void:
	var state := PredictedState.new()
	state.position = Vector3(x, 0.0, 0.0)
	_history.push(InputCommand.empty(seq), state)


func test_it_remembers_what_it_predicted_for_a_sequence() -> void:
	_push(1, 1.0)
	_push(2, 2.0)
	assert_almost_eq(_history.state_at(2).position.x, 2.0, 0.001)


func test_an_unknown_sequence_reads_as_nothing() -> void:
	# **NULL IS THE ORDINARY ANSWER, NOT AN ERROR.** A snapshot acking a command
	# already discarded has nothing to compare against, and the reconciler must
	# smooth rather than guess.
	_push(1, 1.0)
	assert_null(_history.state_at(99))


func test_acknowledging_forgets_the_command_and_its_prediction() -> void:
	_push(1, 1.0)
	_push(2, 2.0)
	_push(3, 3.0)
	_history.ack(2)
	assert_eq(_history.size(), 1, "the acked commands are still pending")
	assert_null(_history.state_at(2), "an acked prediction survived")
	assert_not_null(_history.state_at(3), "an unacked prediction was discarded")


func test_acknowledging_works_across_the_sequence_wrap() -> void:
	# **`seq` IS A `u16` SENT 60 TIMES A SECOND**, so it rolls over about every 18
	# minutes — inside a match. A plain `<=` stops discarding at the wrap and the
	# buffer fills with commands the server answered long ago; the replay then
	# re-runs eighteen minutes of input on every snapshot.
	_push(65534, 1.0)
	_push(65535, 2.0)
	_push(0, 3.0)
	_push(1, 4.0)
	_history.ack(0)
	assert_eq(_history.size(), 1, "the wrap stopped the buffer draining")
	assert_almost_eq(_history.state_at(1).position.x, 4.0, 0.001)


func test_the_states_are_dropped_with_the_commands_on_overflow() -> void:
	# Two arrays kept in step. If only one were trimmed, `state_at` would answer
	# with a neighbour's prediction — a plausible number, and the worst kind.
	for i: int in _history.capacity() + 5:
		_push(i, float(i))
	assert_eq(_history.size(), _history.capacity())
	assert_null(_history.state_at(0), "a dropped command left its prediction behind")
	assert_almost_eq(
		_history.state_at(_history.newest_seq()).position.x, float(_history.newest_seq()), 0.001
	)


func test_clearing_forgets_both() -> void:
	_push(1, 1.0)
	_history.clear()
	assert_true(_history.is_empty())
	assert_null(_history.state_at(1))


func test_a_predicted_state_carries_no_gameplay_state() -> void:
	# **NOTHING GAMEPLAY-RELEVANT IS PREDICTED** (ADR-0002 point 5), and the way
	# to keep that true is to have nowhere to put it. A client-side suspicion
	# estimate "just for the HUD" would drift, and a HUD that disagrees with the
	# server about your own tier is worse than no HUD.
	var state := PredictedState.new()
	for forbidden: String in ["suspicion", "tier", "cooldown_a_tick", "score", "contract"]:
		assert_false(forbidden in state, "PredictedState has a `%s` field" % forbidden)
