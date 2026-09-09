## Read-only results projection. Totals and bonus points share ScoreFold.
## The delivery adapter supplies complete immutable events and final player metadata.
## No live-feed reconstruction, ranking rule or results-phase clock lives here.
class_name ResultsVm
extends RefCounted

signal changed
signal state_changed

var players: Array[Dictionary] = []
var selected: int = 0
var local_actor: int = 0
var available: bool = false
var active: bool = false
var finished: bool = false
var shared_win: bool = false
var votes: int = 0
var voters: int = 0
var seconds_left: int = -1
var voted: bool = false
var requested: bool = false
var skip_enabled: bool = false
var best_actor: int = 0
var best_points: int = 0
var best_stack: Array[Dictionary] = []

var _events: Array[ScoreEvent] = []
var _phase: int = -1


## Metadata keys: id, name, placement, persona, abilities, passive,
## anonymous_seconds. Placement is always the shared ScorePlacement rule.
func present(events: Array[ScoreEvent], roster: Array[Dictionary], own_id: int) -> void:
	_events = events.duplicate()
	players = roster.duplicate(true)
	local_actor = own_id
	_place_players()
	selected = own_id if not player_for(own_id).is_empty() else 0
	if selected == 0 and not players.is_empty():
		selected = int(players[0]["id"])
	available = not players.is_empty()
	_find_best()
	changed.emit()
	state_changed.emit()


func phase_changed(phase: int) -> void:
	if phase == _phase:
		return
	if active and phase != MatchPhase.Phase.RESULTS:
		_clear()
	_phase = phase
	active = phase == MatchPhase.Phase.RESULTS
	state_changed.emit()


func select(actor: int) -> void:
	if actor == selected or player_for(actor).is_empty():
		return
	selected = actor
	changed.emit()


func player_for(actor: int) -> Dictionary:
	for player: Dictionary in players:
		if int(player["id"]) == actor:
			return player
	return {}


## Counts annotate the fold; they never multiply a tunable into another total.
func breakdown(actor: int) -> Array[Dictionary]:
	return _breakdown(actor, _events)


static func _breakdown(actor: int, events: Array[ScoreEvent]) -> Array[Dictionary]:
	var points := ScoreFold.breakdown(events, actor)
	var counts := ScoreFold.counts(events, actor)
	var rows: Array[Dictionary] = []
	for kind: StringName in points:
		if kind != Ids.SCORE_DEATH:
			rows.append({"kind": kind, "count": counts[kind], "points": points[kind]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["kind"] < b["kind"])
	return rows


## Only the local player's killers are shown. No time or position leaves this query.
func killers() -> Array[Dictionary]:
	var counts := ScoreFold.killers_of(_events, local_actor)
	var rows: Array[Dictionary] = []
	for actor: int in counts:
		rows.append({"id": actor, "count": counts[actor]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	return rows


## Transport calls this with the server's tally and RESULTS time, not match time.
func skip_state(count: int, eligible: int, own_vote: bool, remaining: int, connected: bool) -> void:
	votes = count
	voters = eligible
	voted = own_vote
	seconds_left = remaining
	skip_enabled = connected and eligible > 0
	state_changed.emit()


func request_skip() -> bool:
	if not active or finished or not available or not skip_enabled or requested or voted:
		return false
	requested = true
	state_changed.emit()
	return true


func _find_best() -> void:
	best_actor = 0
	best_points = 0
	best_stack.clear()
	var best := ScoreFold.best_kill(_events)
	if not best.is_empty():
		best_actor = int(best["actor"])
		best_points = int(best["points"])
		best_stack = _breakdown(best_actor, best["events"])


## The shared rule owns both ordering and place, including slots without events.
func _place_players() -> void:
	var slots: Array = []
	for player: Dictionary in players:
		slots.append(int(player["id"]))
	shared_win = ScorePlacement.is_shared_win(_events, slots)
	var ordered: Array[Dictionary] = []
	for row: Dictionary in ScorePlacement.standings(_events, slots):
		var player := player_for(int(row["slot"]))
		player["total"] = int(row["points"])
		player["placement"] = int(row["place"])
		ordered.append(player)
	players = ordered


## Only a RESULTS snapshot may call this; zero is authoritative completion.
func results_time(ticks: int, tick_rate: float) -> void:
	if not active:
		return
	var seconds := int(ceil(float(maxi(ticks, 0)) / maxf(tick_rate, 1.0)))
	var complete := finished or ticks <= 0
	if seconds == seconds_left and complete == finished:
		return
	seconds_left = seconds
	finished = complete
	state_changed.emit()


func _clear() -> void:
	_events.clear()
	players.clear()
	best_stack.clear()
	available = false
	finished = false
	shared_win = false
	selected = 0
	best_actor = 0
	best_points = 0
	requested = false
	voted = false
	skip_enabled = false
	votes = 0
	voters = 0
	seconds_left = -1
	changed.emit()
