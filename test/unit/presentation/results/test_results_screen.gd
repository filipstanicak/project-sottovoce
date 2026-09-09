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

	for button: Button in results.screen.get("_buttons").values():
		var row := button.get_child(0) as Control
		assert_lte(row.get_combined_minimum_size().y, button.size.y - 16.0)
	var font := results.screen.style.font
	var width := font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	for digit: int in 10:
		assert_almost_eq(
			font.get_string_size(str(digit), HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x, width, 0.01
		)


func test_received_wire_report_reaches_the_screen_without_a_live_score_feed() -> void:
	var results := ResultsRoot.new()
	add_child_autofree(results)
	var previous := GameState.local_peer_id
	GameState.local_peer_id = 2
	var events: Array[ScoreEvent] = [
		FIXTURE.event(1, 1, Ids.SCORE_CONTRACT, 100, 1),
		FIXTURE.event(2, 1, Ids.SCORE_SILENT, 200, 1),
		ScoreEvent.new(3, ScoreAward.new(10, Ids.SCORE_DEATH, 2, 1, 0), Tuning.match_rules),
	]
	var payload := MatchEndWire.pack(
		{1: 300, 2: 600},
		{1: [Ids.ABIL_LUNGE], 2: [Ids.ABIL_CINDERFALL]},
		events,
		func(id: int) -> int: return id
	)
	Net.events.s2c_match_end(payload)
	assert_false(results.visible, "delivery alone must not reveal results during play")
	EventBus.match_phase_changed.emit(MatchPhase.Phase.RESULTS, 1.0)
	assert_true(results.visible)
	assert_eq(results.vm.selected, 2, "the local identity is a wire slot")
	assert_eq(results.vm.player_for(1)["total"], 300)
	assert_eq(results.vm.killers(), [{"id": 1, "count": 1}])
	assert_eq(results.vm.player_for(2)["abilities"], [Ids.ABIL_CINDERFALL])
	assert_almost_eq(
		results.vm.player_for(2)["anonymous_seconds"], 600.0 / Tuning.match_rules.tick_rate, 0.001
	)
	assert_false(results.vm.player_for(1).has("placement"), "no invented placement")
	assert_false(results.vm.skip_enabled, "the server skip doorway is still absent")
	GameState.local_peer_id = previous
	EventBus.match_phase_changed.emit(MatchPhase.Phase.LOBBY, 1.0)
	assert_false(results.vm.available, "the next match cannot inherit the old result")
