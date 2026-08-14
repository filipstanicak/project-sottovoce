## Systems tick in the declared order, not the tree's. TDD-01 §4, US-0027.
##
## Asserted against a **recorded call sequence** from fake systems registered in
## a deliberately scrambled order. A test that registered them in the right order
## and checked they ran in that order would pass on a director that simply ticked
## its dictionary.
extends GutTest

var _director: MatchDirector
var _calls: Array = []


class FakeSystem:
	extends GameSystem

	var _stage: StringName
	var _log: Array

	func _init(stage_name: StringName, call_log: Array) -> void:
		_stage = stage_name
		_log = call_log

	func stage() -> StringName:
		return _stage

	func tick(_ctx: MatchContext, _dt: float) -> void:
		_log.append(_stage)


func before_each() -> void:
	_calls = []
	_director = MatchDirector.new()
	add_child_autofree(_director)
	_director.ctx.phase = MatchPhase.Phase.ACTIVE


func _register(stage: StringName) -> FakeSystem:
	var system := FakeSystem.new(stage, _calls)
	add_child_autofree(system)
	_director.register(system)
	return system


## Mark the `push_error` a refusal raises as expected.
##
## GUT fails a test for any error raised during it, and three tests below exist
## to provoke exactly one. **The alternative was to downgrade the log to a
## warning, and that is the wrong trade**: a system registered under no stage
## never ticks, everything it owns silently stops happening, and the symptom is a
## rule that appears not to exist. That deserves to be loud in production. The
## test says so here instead of quietly making it quieter.
func _expect_a_loud_refusal() -> void:
	for err: Variant in gut.error_tracker.get_current_test_errors():
		err.handled = true


func _tick_once() -> void:
	for _i: int in 2:
		_director._physics_process(1.0 / Tuning.net.client_input_rate)


func test_the_declared_order_matches_the_document() -> void:
	# The list in `SystemOrder` is the one definition; `test_system_order_matches_
	# the_diagram.gd` compares it against TDD-01 §4 itself. Here we only assert it
	# is the shape the director can walk.
	assert_eq(SystemOrder.STAGES.size(), 10, "TDD-01 §4 declares ten stages")
	assert_eq(SystemOrder.position_of(&"crowd"), 2)
	assert_lt(
		SystemOrder.position_of(&"crowd"),
		SystemOrder.position_of(&"suspicion"),
		"suspicion would be computed against last tick's crowd"
	)


func test_systems_tick_in_the_declared_order_whatever_order_they_registered_in() -> void:
	# **REGISTERED BACKWARDS ON PURPOSE.** Scene-tree order is an invisible
	# dependency: correct until somebody drags a node, and then suspicion is
	# computed against last tick's crowd with nothing erroring.
	_register(&"score")
	_register(&"detection")
	_register(&"crowd")
	_register(&"suspicion")
	_tick_once()
	assert_eq(_calls, [&"crowd", &"suspicion", &"detection", &"score"])


func test_each_system_ticks_exactly_once_per_net_tick() -> void:
	_register(&"suspicion")
	_tick_once()
	_tick_once()
	assert_eq(_calls, [&"suspicion", &"suspicion"], "a system ticked at the physics rate")


func test_a_system_with_no_stage_is_refused() -> void:
	# A system that never ticks is worse than one that errors: everything it owns
	# silently stops happening, and the symptom is a rule that seems not to exist.
	var orphan := GameSystem.new()
	add_child_autofree(orphan)
	assert_false(_director.register(orphan), "a system with no stage was registered")
	_expect_a_loud_refusal()


func test_a_stage_that_is_not_a_system_is_refused() -> void:
	# `ingest`, `pawn` and `snapshot` are positions in the order, not places to
	# hang behaviour. Registering under one would run it in the right place by
	# accident and hide the fact that nothing owns it.
	for stage: StringName in SystemOrder.NOT_SYSTEMS:
		var system := FakeSystem.new(stage, _calls)
		add_child_autofree(system)
		assert_false(_director.register(system), "%s accepted a system" % stage)
	_expect_a_loud_refusal()


func test_two_systems_cannot_claim_one_stage() -> void:
	# Which of them runs would depend on registration order, which is exactly the
	# invisible dependency this whole file exists to remove.
	_register(&"suspicion")
	var second := FakeSystem.new(&"suspicion", _calls)
	add_child_autofree(second)
	assert_false(_director.register(second), "two systems claimed one stage")
	_expect_a_loud_refusal()


func test_setup_runs_before_the_first_tick_and_teardown_releases() -> void:
	var system := _register(&"suspicion")
	assert_eq(_director.system_for(&"suspicion"), system)
	_director.teardown()
	_tick_once()
	assert_eq(_calls, [], "a system ticked after teardown")
