## Results typography and controls, using the shared injectable palette.
class_name ResultsStyle
extends RefCounted

var palette: Palette
var font: FontVariation


func _init(colours: Palette) -> void:
	palette = colours
	font = FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.opentype_features = {"tnum": 1}


func label(text: String, size: int = 19, dim: bool = false) -> Label:
	var out := Label.new()
	out.text = text
	out.add_theme_font_override("font", font)
	out.add_theme_font_size_override("font_size", size)
	out.add_theme_color_override("font_color", palette.text_dim if dim else palette.text)
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


func wrapped(text: String, size: int = 19) -> Label:
	var out := label(text, size)
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return out


func button(text: String, selected: bool = false) -> Button:
	var out := Button.new()
	out.text = text
	out.custom_minimum_size.y = 48
	out.add_theme_font_override("font", font)
	out.add_theme_font_size_override("font_size", 19)
	out.add_theme_color_override("font_color", palette.text)
	out.add_theme_color_override("font_hover_color", palette.text)
	out.add_theme_color_override("font_focus_color", palette.text)
	out.add_theme_color_override("font_disabled_color", palette.text_dim)
	out.add_theme_stylebox_override("normal", plate(selected))
	out.add_theme_stylebox_override("hover", plate(true))
	out.add_theme_stylebox_override("focus", plate(true))
	out.add_theme_stylebox_override("pressed", plate(true))
	out.add_theme_stylebox_override("disabled", plate(false))
	return out


func plate(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.with_alpha(palette.plate, 1.0)
	box.border_color = palette.text if selected else palette.text_dim
	box.set_border_width_all(2 if selected else 0)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func text(key: StringName) -> String:
	return Strings.get_text(key)


static func named(id: StringName) -> String:
	var bits := String(id).split("-")
	if bits.size() != 2:
		return text(&"ui.results.unavailable")
	var namespaces := {"PERS": "persona", "PASV": "passive", "ABIL": "ability"}
	var space := str(namespaces.get(bits[0], "persona"))
	var key := StringName(space + "." + bits[1].to_lower() + ".name")
	return text(key) if Strings.has(key) else text(&"ui.results.unavailable")


static func bonus(kind: StringName) -> String:
	var key := ScoreKinds.string_key(kind)
	return text(key) if Strings.has(key) else text(&"ui.results.other_bonus")
