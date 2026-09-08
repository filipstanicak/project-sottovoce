## Player-facing placement and readability, independently of debug overlays.
extends GutTest


func test_the_instruments_stay_in_the_centred_band_on_ultrawide() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2560, 1080)
	add_child_autofree(viewport)
	var hud := HudRoot.new()
	viewport.add_child(hud)
	var frame := hud.get_node("InstrumentFrame") as Control
	assert_eq(frame.position, Vector2(320.0, 0.0))
	assert_eq(frame.size, Vector2(1920.0, 1080.0))
	_assert_placements(frame)
	var vignette := hud.get_node("Vignette") as Control
	assert_eq(vignette.get_parent(), hud, "vignette must reach the physical edges")


func test_the_approved_layout_leaves_the_centre_clear() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	add_child_autofree(viewport)
	var hud := HudRoot.new()
	viewport.add_child(hud)
	var frame := hud.get_node("InstrumentFrame") as Control
	_assert_placements(frame)
	var centre := Rect2(384.0, 216.0, 1152.0, 648.0)
	for child_name: String in ["Portrait", "Tier"]:
		var widget := frame.get_node(child_name) as Control
		assert_false(centre.intersects(widget.get_rect()), "widget covers the crowd-reading area")


func _assert_placements(frame: Control) -> void:
	var portrait := frame.get_node("Portrait") as Control
	var tier := frame.get_node("Tier") as Control
	assert_eq(portrait.position, Vector2(96.0, 56.0))
	assert_eq(portrait.size, Vector2(180.0, 220.0))
	assert_gt(tier.position.y, frame.size.y * 0.5, "tier belongs in the lower left")
	assert_gte(tier.position.x, 96.0, "tier is outside the safe area")
	assert_lte(tier.get_rect().end.y, frame.size.y - 64.0, "tier touches the bottom edge")


func test_normal_text_survives_a_white_world_behind_its_plate() -> void:
	var palette := Palette.fallback()
	var backing := Color.WHITE.blend(palette.plate)
	for ink: Color in [palette.text, palette.text_dim, palette.score]:
		assert_gte(_contrast(backing.blend(ink), backing), 7.0, "text contrast is below spec")
	assert_gte(TierWidget.LIST_SIZE, 15)
	assert_gte(ScoreFeedWidget.NAME_SIZE, 24)
	assert_gte(PortraitWidget.LABEL_SIZE, 15)
	var penalty_backing := Color.WHITE.blend(palette.penalty_plate)
	assert_gte(_contrast(penalty_backing.blend(palette.score_penalty), penalty_backing), 7.0)


func _contrast(a: Color, b: Color) -> float:
	var first := a.srgb_to_linear().get_luminance()
	var second := b.srgb_to_linear().get_luminance()
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)
