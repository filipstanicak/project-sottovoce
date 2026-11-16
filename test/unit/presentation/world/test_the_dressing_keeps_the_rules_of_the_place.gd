## **THE DISTRICT'S ART OBEYS THE DISTRICT'S RULES.** ADR-0026, ART_BIBLE §3–§4.
##
## Three rules the art bible states and nothing checked, because there was no art:
## the reserved hues stay reserved (§3), eye height stays quiet (§4.1), and a roof
## a pawn can stand on stays a clean line against the sky (§4).
extends GutTest

## How near a persona's hue a surface may come, in degrees, before it has to be
## clearly greyer than that persona.
const HUE_TOLERANCE := 18.0
## "Clearly greyer": at most this much of the persona's own saturation.
const SATURATION_SHARE := 0.75
## ART_BIBLE §4.1.
const EYE_BAND := Vector2(1.4, 1.9)
## What may not sit in the band: glass, cloth, iron and roof tile — everything
## with a glint, a stripe or a light in it.
const LOUD: Array[StringName] = [
	WorldMaterials.GLASS, WorldMaterials.CLOTH, WorldMaterials.IRON, WorldMaterials.ROOF
]

var _survey: DressingSurvey
var _batch: MeshBatch


func before_all() -> void:
	var map: Node3D = (load(MapCatalogue.client_scene("vetraio")) as PackedScene).instantiate()
	add_child(map)
	var host := Node3D.new()
	add_child(host)
	var palette := WorldPalette.new()
	_survey = DressingSurvey.new(map)
	_batch = DistrictDressing.detail_of(_survey, WorldMaterials.new(palette), palette, host)
	map.queue_free()
	host.queue_free()


func _persona_hues() -> Array[Color]:
	var out: Array[Color] = []
	var palette := Palette.fallback()
	for persona: StringName in CrowdRoster.PLAYABLE:
		out.append(palette.for_persona(persona))
	return out


func test_no_surface_wears_a_persona_hue() -> void:
	# §3.1: a market awning in a persona's hue makes the Noticed tint unreadable in
	# that market, a dead zone made by set dressing.
	var clashes: PackedStringArray = []
	for surface: Color in WorldPalette.new().surfaces():
		for hue: Color in _persona_hues():
			var apart := absf(angle_difference(surface.h * TAU, hue.h * TAU)) * 360.0 / TAU
			if apart < HUE_TOLERANCE and surface.s > hue.s * SATURATION_SHARE:
				clashes.append("%s is %0.f deg from %s and as vivid" % [surface, apart, hue])
	assert_eq(clashes.size(), 0, "\n".join(clashes))


func test_the_scan_has_personas_and_surfaces_to_compare() -> void:
	assert_eq(_persona_hues().size(), 4)
	assert_gt(WorldPalette.new().surfaces().size(), 20)


func test_nothing_loud_hangs_at_eye_height() -> void:
	# **BY TRIANGLE, NOT BY VERTEX.** A window from 1.3 m to 3.0 m has no corner in
	# the band and covers all of it; the first version of this test passed over one.
	var found: PackedStringArray = []
	for key: StringName in LOUD:
		var vertices := _batch.vertices_of(key)
		for i: int in range(0, vertices.size(), 3):
			var low := minf(vertices[i].y, minf(vertices[i + 1].y, vertices[i + 2].y))
			var high := maxf(vertices[i].y, maxf(vertices[i + 1].y, vertices[i + 2].y))
			if low < EYE_BAND.y and high > EYE_BAND.x:
				found.append("%s from %.2f to %.2f m at %s" % [key, low, high, vertices[i]])
				break
	assert_eq(found.size(), 0, "in the band players are read in: %s" % ", ".join(found))


func test_the_loud_keys_were_actually_built() -> void:
	# The guard above passes over a district with no windows in it.
	for key: StringName in LOUD:
		assert_gt(_batch.vertices_of(key).size(), 0, "no %s was built to check" % key)


func test_nothing_rises_above_a_roof_a_pawn_can_stand_on() -> void:
	# Only the bell tower's head breaks a roof line; nobody stands 22 m up.
	var above: PackedStringArray = []
	for key: StringName in _batch.keys():
		for vertex: Vector3 in _batch.vertices_of(key):
			var roof := _roof_over(vertex)
			if roof > 0.0 and roof < FacadeDresser.TOWER_HEIGHT and vertex.y > roof + 0.01:
				above.append("%s at %s over a %.1f m roof" % [key, vertex, roof])
				break
	assert_eq(above.size(), 0, "\n".join(above))


## The top of the tallest block `at` stands on or hangs from, 0 for none.
func _roof_over(at: Vector3) -> float:
	var roof := 0.0
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.BLOCK):
		if part.rect().grow(1.0).has_point(Vector2(at.x, at.z)):
			roof = maxf(roof, part.top())
	return roof


func test_the_water_lies_below_every_street() -> void:
	assert_lt(GroundDresser.WATER_Y, 0.0)
	for part: DressingSurvey.Part in _survey.of(DressingSurvey.Role.FLOOR):
		assert_gt(part.bottom(), GroundDresser.WATER_Y, "%s stands in the water" % part.name)
