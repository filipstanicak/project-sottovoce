## Selected player's teaching breakdown. All numbers are read from ResultsVm.
class_name ResultsDetails
extends VBoxContainer

var vm: ResultsVm
var style: ResultsStyle


func render() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 16)
	var player := vm.player_for(vm.selected)
	if player.is_empty():
		return
	_header(player)
	_kit(player)
	_anonymous(player)
	add_child(style.label(ResultsStyle.text(&"ui.results.breakdown"), 24))
	_table(vm.breakdown(vm.selected))
	add_child(style.wrapped(ResultsStyle.text(&"ui.results.fold_note"), 15))
	_best()


func _header(player: Dictionary) -> void:
	var row := HBoxContainer.new()
	var name_label := style.wrapped(str(player.get("name", "")), 32)
	row.add_child(name_label)
	row.add_child(style.label(str(player["total"]), 48))
	add_child(row)


func _kit(player: Dictionary) -> void:
	var persona := ResultsStyle.named(StringName(player.get("persona", &"")))
	var kit: PackedStringArray = []
	for ability: StringName in player.get("abilities", []):
		kit.append(ResultsStyle.named(ability))
	var abilities := (
		", ".join(kit) if not kit.is_empty() else ResultsStyle.text(&"ui.results.unavailable")
	)
	var passive := ResultsStyle.named(StringName(player.get("passive", &"")))
	add_child(style.wrapped(ResultsStyle.text(&"ui.results.kit") % [persona, abilities, passive]))


func _anonymous(player: Dictionary) -> void:
	var seconds := float(player.get("anonymous_seconds", -1.0))
	var duration := ResultsStyle.text(&"ui.results.unavailable")
	if seconds >= 0.0:
		duration = (
			ResultsStyle.text(&"ui.results.duration") % [int(seconds) / 60, int(seconds) % 60]
		)
	var key := &"ui.results.anonymous"
	if int(player.get("placement", 0)) == 1:
		key = &"ui.results.winner_anonymous"
	add_child(style.wrapped(ResultsStyle.text(key) % duration, 24))


func _table(rows: Array[Dictionary]) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	for key: StringName in [&"ui.results.bonus", &"ui.results.count", &"ui.results.points"]:
		grid.add_child(style.label(ResultsStyle.text(key), 15, true))
	for row: Dictionary in rows:
		var title := style.wrapped(ResultsStyle.bonus(row["kind"]))
		grid.add_child(title)
		grid.add_child(style.label(str(row["count"])))
		var points := style.label(str(row["points"]))
		points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(points)
	add_child(grid)
	if rows.is_empty():
		add_child(style.wrapped(ResultsStyle.text(&"ui.results.no_bonuses")))


func _best() -> void:
	add_child(HSeparator.new())
	add_child(style.label(ResultsStyle.text(&"ui.results.best_kill"), 24))
	if vm.best_actor == 0:
		add_child(style.wrapped(ResultsStyle.text(&"ui.results.no_kill")))
		return
	var player := vm.player_for(vm.best_actor)
	var name_text := str(player.get("name", ResultsStyle.text(&"ui.results.unavailable")))
	add_child(style.wrapped(ResultsStyle.text(&"ui.results.best_by") % [vm.best_points, name_text]))
	_table(vm.best_stack)
