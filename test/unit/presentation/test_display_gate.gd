## **A PROCESS WITH NO SCREEN DRAWS NOTHING, AND A TEST CAN ASK FOR ONE.** ADR-0026.
extends GutTest


func after_each() -> void:
	DisplayGate.forced = false


func test_the_test_run_has_no_screen() -> void:
	# CI is headless; this is what keeps ninety figures from being animated in it.
	assert_eq(DisplayServer.get_name(), "headless")
	assert_false(DisplayGate.draws())


func test_a_test_can_force_the_drawn_path() -> void:
	DisplayGate.forced = true
	assert_true(DisplayGate.draws())


func test_a_figure_with_no_screen_is_built_and_not_animated() -> void:
	var body := PersonaBody.new()
	add_child_autofree(body)
	assert_gt(body.parts().size(), 10, "a headless client's figures still exist")
	assert_false(body.is_physics_processing())


func test_a_figure_with_a_screen_animates_itself() -> void:
	DisplayGate.forced = true
	var body := PersonaBody.new()
	add_child_autofree(body)
	assert_true(body.is_physics_processing())
