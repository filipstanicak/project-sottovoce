## Presentation entry point for the authoritative end-of-match delivery adapter.
## Phase arrives exclusively through HudBridge's existing EventBus signal.
class_name ResultsRoot
extends CanvasLayer

signal active_changed(active: bool)
signal skip_requested

var vm := ResultsVm.new()
var palette: Palette = Palette.fallback()
var screen: ResultsScreen

var _shown: bool = false


func _ready() -> void:
	layer = 20
	visible = false
	screen = ResultsScreen.new()
	screen.vm = vm
	screen.palette = palette
	screen.player_selected.connect(_select)
	screen.skip_pressed.connect(_request_skip)
	add_child(screen)
	vm.changed.connect(_refresh)
	vm.state_changed.connect(_refresh_state)
	EventBus.match_phase_changed.connect(_phase_changed)
	Net.events.match_ended.connect(_match_ended)
	_refresh_state()


func _exit_tree() -> void:
	if Net.events.match_ended.is_connected(_match_ended):
		Net.events.match_ended.disconnect(_match_ended)
	if EventBus.match_phase_changed.is_connected(_phase_changed):
		EventBus.match_phase_changed.disconnect(_phase_changed)
	if _shown:
		active_changed.emit(false)


## Called once the full, validated end-of-match delivery is available.
func present(events: Array[ScoreEvent], roster: Array[Dictionary], local_actor: int) -> void:
	vm.present(events, roster, local_actor)


## Connect skip_requested before supplying a server tally. No sender, no enabled button.
func apply_skip_state(votes: int, voters: int, voted: bool, seconds_left: int = -1) -> void:
	vm.skip_state(
		votes, voters, voted, seconds_left, not skip_requested.get_connections().is_empty()
	)


func _phase_changed(phase: int, _multiplier: float) -> void:
	vm.phase_changed(phase)


func _refresh() -> void:
	if is_instance_valid(screen):
		screen.refresh()
		if vm.active:
			screen.focus_player()


func _refresh_state() -> void:
	visible = vm.active
	if is_instance_valid(screen):
		screen.refresh_state()
	if _shown == visible:
		return
	_shown = visible
	active_changed.emit(_shown)
	if _shown:
		screen.focus_player()


func _select(actor: int) -> void:
	vm.select(actor)
	screen.focus_player()


func _request_skip() -> void:
	if vm.request_skip():
		skip_requested.emit()


## The report uses wire slots, as does GameState's historical local_peer_id name.
## Missing identity metadata stays unavailable until the server supplies it.
func _match_ended(report: MatchEndReport) -> void:
	var roster: Array[Dictionary] = []
	for slot: int in report.slots():
		(
			roster
			. append(
				{
					"id": slot,
					"name": ResultsStyle.text(&"ui.results.player_slot") % slot,
					"abilities": report.kits.get(slot, []),
					"anonymous_seconds": report.anonymous_seconds(slot, Tuning.match_rules),
				}
			)
		)
	present(report.events, roster, GameState.local_peer_id)
