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
## anonymous_seconds. Placement and duration are authoritative, never inferred.
func present(events: Array[ScoreEvent], roster: Array[Dictionary], own_id: int) -> void:
	_events = events.duplicate()
	players = roster.duplicate(true)
	local_actor = own_id
	var totals := ScoreFold.fold(_events)
	for player: Dictionary in players:
		player["total"] = int(totals.get(int(player["id"]), 0))
	players.sort_custom(_before)
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
	var counts: Dictionary = {}
	for event: ScoreEvent in events:
		if event.actor_id == actor:
			counts[event.kind] = int(counts.get(event.kind, 0)) + 1
	var rows: Array[Dictionary] = []
	for kind: StringName in points:
		if kind != Ids.SCORE_DEATH:
			rows.append({"kind": kind, "count": counts[kind], "points": points[kind]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["kind"] < b["kind"])
	return rows


## Only the local player's killers are shown. No time or position leaves this query.
func killers() -> Array[Dictionary]:
	var counts: Dictionary = {}
	for event: ScoreEvent in _events:
		if event.kind == Ids.SCORE_DEATH and event.actor_id == local_actor:
			counts[event.subject_id] = int(counts.get(event.subject_id, 0)) + 1
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
	if not active or not available or not skip_enabled or requested or voted:
		return false
	requested = true
	state_changed.emit()
	return true


func _find_best() -> void:
	best_actor = 0
	best_points = 0
	best_stack.clear()
	for event: ScoreEvent in _events:
		if event.kind != Ids.SCORE_CONTRACT or event.group_id <= 0:
			continue
		var group := ScoreFold.group(_events, event.group_id)
		var points := ScoreFold.total_for(group, event.actor_id)
		if best_actor == 0 or points > best_points:
			best_actor = event.actor_id
			best_points = points
			best_stack = _breakdown(event.actor_id, group)


## Use supplied placement; an absent placement stays unknown, never guessed by kills.
static func _before(a: Dictionary, b: Dictionary) -> bool:
	var left := int(a.get("placement", 0))
	var right := int(b.get("placement", 0))
	if left == right:
		return int(a["id"]) < int(b["id"])
	if left <= 0:
		return false
	return right <= 0 or left < right


func _clear() -> void:
	_events.clear()
	players.clear()
	best_stack.clear()
	available = false
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
