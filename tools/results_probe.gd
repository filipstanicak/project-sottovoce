## Reproducible RESULTS captures. Run as results_probe.tscn, never with -s.
## Uses fixture deliveries only; the shipping client never manufactures results.
extends Node

const FIXTURE = preload("res://test/unit/presentation/results/results_fixture.gd")

var _results: ResultsRoot


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_results = ResultsRoot.new()
	add_child(_results)
	EventBus.match_phase_changed.emit(MatchPhase.Phase.RESULTS, 1.0)
	await _capture("waiting")
	var roster := FIXTURE.roster()
	roster[0]["name"] = "Alessandra del Vetraio"
	roster[1]["name"] = "Luca"
	var events: Array[ScoreEvent] = []
	for i: int in 12:
		events.append(FIXTURE.event(i + 1, 1, ScoreKinds.ALL[i], 100 + i * 25, 1))
	events.append(FIXTURE.event(20, 2, Ids.SCORE_CONTRACT, 100, 2))
	events.append(FIXTURE.event(21, 2, Ids.SCORE_PATIENT, 150, 2))
	events.append(FIXTURE.event(22, 2, Ids.SCORE_SILENT, 200, 2))
	events.append(
		ScoreEvent.new(23, ScoreAward.new(10, Ids.SCORE_DEATH, 2, 1, 0), Tuning.match_rules)
	)
	_results.present(events, roster, 2)
	_results.skip_requested.connect(func() -> void: pass)
	_results.apply_skip_state(2, 6, false, 25)
	await _capture("local")
	_results.vm.select(1)
	await _capture("winner")
	roster[0]["name"] = "A deliberately very long player name to verify wrapping and clipping"
	_results.present([], roster, 1)
	await _capture("empty_long_name")
	get_tree().quit()


func _capture(label: String) -> void:
	for _i: int in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "user://results_%s.png" % label
	get_viewport().get_texture().get_image().save_png(path)
	print(ProjectSettings.globalize_path(path))
