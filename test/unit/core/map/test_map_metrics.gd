## No traversable surface sits inside a metrics boundary band. GDD-05 §4.1.
##
## THE BOUNDARY BANDS ARE THE IMPORTANT COLUMN of that table. Geometry built at
## 1.10 m resolves as a vault or a mantle depending on sub-centimetre position,
## so the same wall behaves differently on two approaches — which reads to a
## player not as a subtle rule but as the game being broken.
##
## A player must never have to guess whether geometry is traversable. Guessing
## costs attention, and attention is the resource the game is actually about.
extends GutTest


func test_no_declared_height_is_in_a_boundary_band() -> void:
	var violations: PackedStringArray = []
	for entry: Array in VetraioLayout.traversable_heights():
		if VetraioLayout.in_boundary_band(float(entry[1])):
			violations.append("%s at %.2f m" % [entry[0], entry[1]])
	violations.sort()
	assert_eq(
		violations.size(),
		0,
		(
			"Geometry sits in a traversal boundary band.\n"
			+ "It will resolve differently by sub-centimetre position, which reads as\n"
			+ "the game being broken. Bands: %s\n" % str(VetraioLayout.BOUNDARY_BANDS)
			+ "\n".join(violations)
		)
	)


func test_the_band_check_actually_rejects_something() -> void:
	# Guards the guard. If in_boundary_band() always returned false the assertion
	# above would pass over any geometry at all.
	assert_true(VetraioLayout.in_boundary_band(1.10), "1.10 m is the vault/mantle boundary")
	assert_true(VetraioLayout.in_boundary_band(4.00), "4.00 m is the drop-stagger boundary")
	assert_false(VetraioLayout.in_boundary_band(0.90), "0.90 m is the authored vault height")
	assert_false(VetraioLayout.in_boundary_band(1.80), "1.80 m is the authored mantle height")


func test_vault_and_mantle_heights_are_the_authored_ones() -> void:
	assert_eq(VetraioLayout.H_VAULT, 0.9, "vault must be 0.9 m — free, 0.55 s")
	assert_eq(VetraioLayout.H_MANTLE, 1.8, "mantle must be 1.8 m — 0.95 s commitment")


func test_every_stall_is_vaultable() -> void:
	# Stall counters are the market's escape geometry. One built at mantle height
	# would silently cost 0.4 s more in exactly the place a hunter closes.
	assert_gt(VetraioLayout.STALLS.size(), 0, "no stalls declared")
	assert_false(VetraioLayout.in_boundary_band(VetraioLayout.H_VAULT), "stall height is in a band")


func test_climb_heights_clear_the_limit_band() -> void:
	# 8.9-9.1 m is the climb-height limit band. A facade there is a climb that
	# sometimes completes and sometimes drops you.
	for height: float in [
		VetraioLayout.H_FACADE_STREET_TO_BALCONY,
		VetraioLayout.H_FACADE_BALCONY_TO_ROOF,
		VetraioLayout.H_FACADE_STREET_TO_ROOF,
	]:
		assert_false(VetraioLayout.in_boundary_band(height), "%.2f m facade is in a band" % height)


func test_mat_void_appears_nowhere() -> void:
	# MAT-VOID is the magenta out-of-bounds material. GDD-05 §7.4: it must never
	# appear in a playtest build, because a player who sees it has found a hole.
	var offenders: PackedStringArray = []
	for table: Array in [VetraioLayout.BLOCKS, VetraioLayout.FLOORS]:
		for row: Array in table:
			if String(row[row.size() - 1]) == "MAT-VOID":
				offenders.append(String(row[0]))
	assert_eq(offenders.size(), 0, "MAT-VOID is applied to: " + ", ".join(offenders))
