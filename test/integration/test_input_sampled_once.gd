## **ONE COMMAND PER PHYSICS FRAME.** TDD-03 §1.2 and §2.1.
##
## The client loop in §1.2's diagram has exactly one box that samples, and
## `TUN-NET-CLIENT-INPUT-RATE` is the rate it runs at. For three stories it ran
## at twice that: `InputSampler._physics_process` emitted a sample and
## `LocalPawnDriver._physics_process` took another, and both fired every frame.
##
## Nothing looked wrong. `_command` is one reused object holding absolute look
## values, so the two invocations agreed on everything a human could see. What
## they did not agree on is anything COUNTED — and the sprint gate counts.
##
## `TUN-SPEED-SPRINT-HOLD` is 0.4 s, which GDD-02 §1.5 spends a page justifying:
## sprint is the only deliberately awkward input in the game, and the friction is
## the point. At two samples a frame the hold opened in 0.21 s. Half the friction
## the design argued for, spent silently, by a wire that was connected twice.
##
## This is the same family as trap 9 — a duration halved by a rate nobody
## checked, arriving as a plausible integer rather than as an error.
##
## Deliberately end-to-end through `client_root.tscn`: a unit test on
## `SprintGate` cannot see how often anything calls it.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

## Comfortably past the hold threshold (24 step-ticks) even when it opens late.
const FRAMES := 60

var _root: Node
var _driver: LocalPawnDriver
var _commands: Array[InputCommand] = []


func before_each() -> void:
	_release_everything()
	_commands = []
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_driver = _root.get_node("LocalPawnDriver")
	_driver.command_sampled.connect(_on_command_sampled)
	await get_tree().physics_frame


func after_each() -> void:
	_release_everything()


func _release_everything() -> void:
	for id: StringName in InputActions.ids():
		for name: StringName in InputActions.action_names(id):
			if InputMap.has_action(name):
				Input.action_release(name)


## Kept, not counted, because the ordering questions below need the fields and
## `_command` is one reused object — so every entry is a copy.
func _on_command_sampled(command: InputCommand) -> void:
	_commands.append(command.duplicate_command())


func _run(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame


# --------------------------------------------------- the rate, measured directly --


func test_one_command_is_sampled_per_physics_frame() -> void:
	await _run(20)
	# Not `assert_eq(size, 20)`: GutTest's own awaits do not guarantee the frame
	# count is exact to the one. The RATIO is the assertion, and it is what pins the
	# emission to the PHYSICS clock — a driver announcing from `_process` instead
	# would run at the display rate and read wrong on exactly one machine.
	assert_between(
		float(_commands.size()) / 20.0,
		0.9,
		1.1,
		"the client is not sampling input once per physics frame"
	)


func test_the_sequence_number_advances_once_per_frame() -> void:
	# `seq` and `client_tick` are what US-0033 reconciles against. A seq that
	# advances at 120 Hz against a server applying commands at 60 would ask the
	# server for acknowledgements of commands that were never sent.
	await _run(20)
	assert_gt(_commands.size(), 2, "nothing was sampled at all")
	var first: InputCommand = _commands[0]
	var last: InputCommand = _commands[_commands.size() - 1]
	assert_eq(
		last.seq - first.seq,
		_commands.size() - 1,
		"seq advanced more than once per emitted command — something samples unobserved"
	)
	assert_eq(last.client_tick, last.seq, "client_tick and seq have come apart")


# ------------------------------------------------------- what the rate bought us --


func test_sprint_opens_on_the_hold_the_design_asked_for() -> void:
	# **THE ASSERTION THE FILE IS FOR.** Read 13 before the fix; TUN-SPEED-SPRINT-HOLD
	# is 24 step-ticks. Design law 1 says speed is spent anonymity, and §1.5 prices
	# the entry — a gate that opens in half the time is a price nobody agreed to.
	Input.action_press(&"input_sprint")
	await _run(FRAMES)
	assert_eq(
		_frames_until_sprint(),
		Tuning.step_ticks(&"TUN-SPEED-SPRINT-HOLD"),
		"the sustained-hold gate did not open on the tick TUN-SPEED-SPRINT-HOLD specifies"
	)


func test_the_hold_gate_is_still_shut_one_frame_early() -> void:
	# The other side of the same edge, so the test above cannot be satisfied by a
	# gate that opens early and a count that happens to land.
	Input.action_press(&"input_sprint")
	await _run(FRAMES)
	var opened := _frames_until_sprint()
	assert_gt(opened, 1, "sprint never opened")
	assert_false(_commands[opened - 2].sprint, "sprint was already open the frame before")


## How many commands were emitted up to and including the first one asking to
## sprint. 0 if none ever did.
func _frames_until_sprint() -> int:
	for i: int in _commands.size():
		if _commands[i].sprint:
			return i + 1
	return 0
