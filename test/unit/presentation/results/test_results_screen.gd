extends GutTest

const FIXTURE = preload("res://test/unit/presentation/results/results_fixture.gd")

var _requests: int = 0
var _bindings: Dictionary = {}


func before_each() -> void:
	_bindings.clear()
	for action: StringName in InputActions.all_action_names():
		if InputMap.has_action(action):
			_bindings[action] = InputMap.action_get_events(action).duplicate()


func after_each() -> void:
	for action: StringName in _bindings:
		InputMap.action_erase_events(action)
		for event: InputEvent in _bindings[action]:
			InputMap.action_add_event(action, event)


func test_real_client_uses_snapshot_phase_and_releases_gameplay_input() -> void:
	var client := (load("res://scenes/client_root.tscn") as PackedScene).instantiate()
	add_child_autofree(client)
	var results := client.get_node("Results") as ResultsRoot
	var sampler := client.get_node("InputSampler") as InputSampler
	assert_not_null(results)
	var snapshot := Snapshot.new()
	snapshot.phase = MatchPhase.Phase.RESULTS
	snapshot.ticks_remaining = 0
	Net.snapshot_received.emit(snapshot)
	assert_true(results.visible)
	assert_false((client.get_node("Hud") as CanvasLayer).visible)
	assert_false(sampler.mouse_captured())
	var action := InputActions.action_names(Ids.INPUT_MOVE)[0]
	Input.action_press(action)
	assert_eq(sampler.sample(0.1).move, Vector2.ZERO)
	Input.action_release(action)
	var click := InputEventMouseButton.new()
	click.pressed = true
	sampler._unhandled_input(click)
	assert_false(sampler.mouse_captured())
	snapshot.phase = MatchPhase.Phase.LOBBY
	Net.snapshot_received.emit(snapshot)
	assert_false(results.visible)
	assert_true((client.get_node("Hud") as CanvasLayer).visible)
	assert_true(sampler.mouse_captured())


func test_skip_button_requires_a_transport_and_only_requests_once() -> void:
	_requests = 0
	var results := ResultsRoot.new()
	add_child_autofree(results)
	EventBus.match_phase_changed.emit(MatchPhase.Phase.RESULTS, 1.0)
	results.present([], FIXTURE.roster(), 1)
	results.apply_skip_state(0, 6, false, 25)
	results.screen.skip_pressed.emit()
	assert_false(results.vm.requested)
	results.skip_requested.connect(_requested)
	results.apply_skip_state(0, 6, false, 25)
	results.screen.skip_pressed.emit()
	results.screen.skip_pressed.emit()
	assert_eq(_requests, 1)
	assert_true(results.visible)
	results.apply_skip_state(6, 6, true, 0)
	assert_true(results.visible)


func test_all_result_strings_and_multiline_kit_are_loaded() -> void:
	assert_true(Strings.has(&"ui.results.kit"))
	var kit := ResultsStyle.text(&"ui.results.kit") % ["A", "B", "C"]
	assert_true(kit.contains("C"))
	assert_eq(ResultsStyle.named(Ids.PERSONA_VETRAIO), Strings.get_text(&"persona.vetraio.name"))


func _requested() -> void:
	_requests += 1


func test_wrapping_cannot_push_the_footer_outside_the_safe_area() -> void:
	var results := ResultsRoot.new()
	add_child_autofree(results)
	EventBus.match_phase_changed.emit(MatchPhase.Phase.RESULTS, 1.0)
	results.present([], FIXTURE.roster(), 1)
	for _i: int in 6:
		await get_tree().process_frame
	var content := results.screen.get("_content") as Control
	assert_lte(content.get_rect().end.y, results.screen.size.y * 0.95 + 1.0)
	assert_gt(content.size.y, 0.0)
	for key: StringName in Strings.keys():
		assert_false(Strings.get_text(key).contains(String.chr(0xfffd)))
