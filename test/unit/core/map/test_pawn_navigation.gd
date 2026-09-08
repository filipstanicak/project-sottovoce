## The shared capsule must survive the navmesh baker's cell quantisation unchanged.
extends GutTest


func test_capsule_and_step_dimensions_are_exact_cell_multiples() -> void:
	for span: float in [PawnNavigation.NAV_AGENT_RADIUS, PawnNavigation.NAV_AGENT_HEIGHT]:
		var cells := span / PawnNavigation.NAV_CELL_SIZE
		assert_almost_eq(cells, roundf(cells), 0.00001)
	assert_almost_eq(
		PawnNavigation.NAV_MAX_CLIMB / PawnNavigation.NAV_CELL_HEIGHT,
		roundf(PawnNavigation.NAV_MAX_CLIMB / PawnNavigation.NAV_CELL_HEIGHT),
		0.00001
	)


func test_the_bake_band_fits_the_capsule_at_street_level() -> void:
	assert_lt(PawnNavigation.NAV_BAKE_FLOOR, 0.0)
	assert_gt(PawnNavigation.NAV_BAKE_CEILING, PawnNavigation.NAV_AGENT_HEIGHT)
	assert_lt(PawnNavigation.NAV_MAX_SLOPE, 90.0)
