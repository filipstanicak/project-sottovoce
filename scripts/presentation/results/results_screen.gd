## Full results surface; no world inference, phase clock or network access.
class_name ResultsScreen
extends Control

signal player_selected(actor: int)
signal skip_pressed

var vm: ResultsVm
var palette: Palette
var style: ResultsStyle

var _content: VBoxContainer
var _body: HBoxContainer
var _waiting: Label
var _footer: Label
var _skip: Button
var _buttons: Dictionary = {}


func _ready() -> void:
	style = ResultsStyle.new(palette)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backing := ColorRect.new()
	backing.color = Palette.with_alpha(palette.plate, 1.0)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	add_child(_content)
	_content.add_child(style.label(ResultsStyle.text(&"ui.results.title"), 32))
	_content.add_child(style.wrapped(ResultsStyle.text(&"ui.results.subtitle"), 19))
	_waiting = style.wrapped(ResultsStyle.text(&"ui.results.waiting"), 24)
	_content.add_child(_waiting)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 32)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_body)
	_build_footer()
	resized.connect(_layout)
	_content.minimum_size_changed.connect(_layout)
	_layout()
	refresh()


func refresh() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_waiting.visible = not vm.available
	if vm.available:
		_build_players()
		var details := ResultsDetails.new()
		details.vm = vm
		details.style = style
		_scroll(details, 1.8)
		details.render()
	refresh_state()


func refresh_state() -> void:
	_skip.disabled = not vm.available or not vm.skip_enabled or vm.requested or vm.voted
	var key := &"ui.results.skip"
	if vm.voted:
		key = &"ui.results.voted"
	elif vm.requested:
		key = &"ui.results.vote_sent"
	_skip.text = ResultsStyle.text(key)
	_footer.text = ResultsStyle.text(&"ui.results.unanimous")
	if vm.voters > 0:
		_footer.text = ResultsStyle.text(&"ui.results.votes") % [vm.votes, vm.voters]
	if vm.seconds_left >= 0:
		_footer.text += ResultsStyle.text(&"ui.results.remaining") % vm.seconds_left


func focus_player() -> void:
	if _buttons.has(vm.selected):
		(_buttons[vm.selected] as Button).grab_focus()


func _build_players() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_scroll(column, 1.0)
	column.add_child(style.label(ResultsStyle.text(&"ui.results.placements"), 24))
	for player: Dictionary in vm.players:
		_player_button(column, player)
	column.add_child(HSeparator.new())
	column.add_child(style.label(ResultsStyle.text(&"ui.results.your_killers"), 24))
	var killers := vm.killers()
	if killers.is_empty():
		column.add_child(style.wrapped(ResultsStyle.text(&"ui.results.no_deaths")))
	for row: Dictionary in killers:
		var player := vm.player_for(int(row["id"]))
		var name_text := str(player.get("name", ResultsStyle.text(&"ui.results.unavailable")))
		column.add_child(
			style.wrapped(ResultsStyle.text(&"ui.results.killer_count") % [name_text, row["count"]])
		)


func _player_button(column: VBoxContainer, player: Dictionary) -> void:
	var actor := int(player["id"])
	var rank := (
		str(player["placement"])
		if int(player.get("placement", 0)) > 0
		else ResultsStyle.text(&"ui.results.no_rank")
	)
	var name_text := str(player.get("name", ""))
	if actor == vm.local_actor:
		name_text = ResultsStyle.text(&"ui.results.you") % name_text
	var button := style.button("", actor == vm.selected)
	button.custom_minimum_size.y = 96
	button.name = "Player%d" % actor
	button.tooltip_text = (
		ResultsStyle.text(&"ui.results.player_row") % [rank, name_text, player["total"]]
	)
	button.pressed.connect(func() -> void: player_selected.emit(actor))
	column.add_child(button)
	_buttons[actor] = button
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -16
	row.offset_top = 8
	row.offset_bottom = -8
	var placement := style.label(rank, 48)
	placement.custom_minimum_size.x = 56
	row.add_child(placement)
	_player_summary(row, player, name_text)


func _player_summary(row: HBoxContainer, player: Dictionary, name_text: String) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var name_label := style.label(name_text)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	column.add_child(name_label)
	column.add_child(
		style.label(ResultsStyle.text(&"ui.results.player_points") % player["total"], 19)
	)
	var seconds := float(player.get("anonymous_seconds", -1.0))
	var duration := ResultsStyle.text(&"ui.results.unavailable")
	if seconds >= 0.0:
		duration = (
			ResultsStyle.text(&"ui.results.duration") % [int(seconds) / 60, int(seconds) % 60]
		)
	var key := &"ui.results.anonymous_short"
	if int(player.get("placement", 0)) == 1:
		key = &"ui.results.shared_winner_short" if vm.shared_win else &"ui.results.winner_short"
	column.add_child(style.label(ResultsStyle.text(key) % duration, 15))


func _scroll(child: Control, stretch: float) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = stretch
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 16)
	scroll.add_child(margin)
	margin.add_child(child)


func _build_footer() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_footer = style.wrapped(ResultsStyle.text(&"ui.results.unanimous"), 15)
	row.add_child(_footer)
	_skip = style.button(ResultsStyle.text(&"ui.results.skip"))
	_skip.name = "SkipResults"
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	row.add_child(_skip)
	_content.add_child(row)


func _layout() -> void:
	var band := minf(size.x, size.y * 16.0 / 9.0)
	_content.position = Vector2((size.x - band) * 0.5 + band * 0.05, size.y * 0.05)
	_content.size = Vector2(band * 0.9, size.y * 0.9)
