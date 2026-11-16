## **THE CLIENT THAT HAS A SCREEN DRESSES THE DISTRICT IT LOADED.** ADR-0026.
##
## Every other test of the dressing calls it directly. This is the one hop none of
## them sees: `client_root.tscn` loading a map and handing it over. CI is headless
## and a headless client dresses nothing, so the boot is forced here.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"

var _root: Node


func after_each() -> void:
	DisplayGate.forced = false
	FigurePlaces.clear()


func _boot() -> void:
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	await get_tree().physics_frame


func test_a_client_with_a_screen_dresses_the_map_it_loaded() -> void:
	DisplayGate.forced = true
	await _boot()
	var dressing := _root.get_node_or_null("World/Map/Dressing") as DistrictDressing
	assert_not_null(dressing, "client_root loaded a map and dressed nothing")
	assert_gt(dressing.triangles, 10000)
	assert_not_null(dressing.get_node_or_null("Detail"))
	assert_not_null(dressing.get_node_or_null("Backdrop"))
	assert_not_null(dressing.get_node_or_null("Water"))
	# And the figures in it are directed, and know where the benches are.
	assert_not_null(_root.get_node_or_null("FigureDirector"))
	assert_gt(FigurePlaces.count(), 20)
	var piazza := _root.get_node("World/Map").get_child(0).get_node("Geometry/PiazzaDelVetro/Mesh")
	assert_true((piazza as MeshInstance3D).material_override is ShaderMaterial)


func test_a_headless_client_is_given_nothing_to_draw() -> void:
	# A bot is a headless client. It walks the same district and never sees it.
	assert_eq(DisplayServer.get_name(), "headless", "this suite is expected to run headless")
	await _boot()
	assert_null(_root.get_node_or_null("World/Map/Dressing"))
	assert_null(_root.get_node_or_null("FigureDirector"))
	var body := _root.get_node("World/PawnLocal/PersonaVisuals") as PersonaBody
	assert_false(body.is_physics_processing(), "a figure nobody sees is being animated")
	var piazza := _root.get_node("World/Map").get_child(0).get_node("Geometry/PiazzaDelVetro/Mesh")
	assert_eq((piazza as MeshInstance3D).material_override.resource_name, "MAT-GREY-FLOOR")


func test_the_light_is_there_either_way() -> void:
	await _boot()
	assert_not_null(_root.get_node_or_null("World/WorldLook/Sun"))
	assert_not_null(_root.get_node_or_null("World/WorldLook/WorldEnvironment"))
