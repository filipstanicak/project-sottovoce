## **UI_UX_SPEC §3.3's FOUR PROHIBITIONS, AS GUARDS.** US-0072.
##
## That section's own framing: *"the protocol prevents leaks; these prevent
## **invention**."* The server already refuses to send a position, an exact
## distance or an unwobbled bearing. What no protocol can prevent is a client
## **deriving** something it was not given, and each of the four is a way to do
## exactly that while every netcode test stays green.
##
## `test_compass_no_wobble_clientside.gd` and `test_compass_no_position.gd` are the
## two the story names; both live here, because they are the same argument applied
## to two fields and splitting them would leave two files each proving a quarter of
## a rule.
extends GutTest

const VM := "res://scripts/presentation/hud/compass_vm.gd"
const WIDGET := "res://scripts/presentation/hud/compass_widget.gd"


func test_the_files_were_actually_read() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** Every `assert_false` below passes over an
	# empty string, so a typo'd path would report four prohibitions upheld by a
	# file that does not exist.
	assert_gt(SourceScanner.read(VM).length(), 500, "compass_vm.gd did not load")
	assert_gt(SourceScanner.read(WIDGET).length(), 500, "compass_widget.gd did not load")


func test_the_view_model_holds_no_world_position() -> void:
	# It has a bucket, not a position, and **must not acquire one**. A `Vector3`
	# field here is the first step to computing a distance the server deliberately
	# quantised away.
	assert_false(
		SourceScanner.code_contains(VM, "Vector3"),
		"CompassVm gained a Vector3 — it holds a bucket, not a position"
	)
	var vm := CompassVm.new()
	for name: String in ["position", "origin", "world_position", "contract_position"]:
		assert_false(name in vm, "CompassVm gained a `%s` field" % name)


func test_the_client_applies_no_wobble() -> void:
	# **Wobble is server-side and deterministic per contract**, so two players
	# standing together are lied to identically and cannot average it away. A
	# second, client-side wobble would be uncorrelated with the first — and
	# therefore unlearnable, which is the one thing design law 6 forbids.
	for path: String in [VM, WIDGET]:
		assert_false(
			SourceScanner.code_contains(path, "wobble"),
			"%s applies or reads a wobble; it is the server's" % path
		)
	# **THE COUNTERFACTUAL, AND IT HAD TO BE AIMED TWICE.** Without it the four
	# `assert_false`s above pass just as happily in a game that wobbles nowhere at
	# all. It first pointed at `detection_system.gd` and went red: every mention of
	# wobble in that file is a *comment*, and `SourceScanner.code_contains` strips
	# comments and string literals by design. The application is
	# `CompassMath.shown_bearing`, and that is what to assert on.
	assert_true(
		SourceScanner.code_contains(
			"res://scripts/systems/detection/detection_system.gd", "shown_bearing"
		),
		"nothing server-side applies the wobble any more, so this guard asserts over nothing"
	)
	assert_true(
		SourceScanner.code_contains("res://scripts/core/compass/compass_math.gd", "wobble"),
		"CompassMath no longer holds the wobble"
	)


func test_the_bearing_is_never_extrapolated() -> void:
	# **The Compass must never contain information newer than the simulation.**
	# `advance()` moves the phase; nothing moves the bearing. A widget that
	# predicted the cone forward by the interpolation delay would be showing a
	# contract where it is *about* to be.
	var vm := CompassVm.new()
	vm.bucket = Quantise.distance_to_bucket(15.0)
	vm.bearing = 0.75
	for _i: int in 240:
		vm.advance(1.0 / 60.0)
	assert_eq(vm.bearing, 0.75, "four seconds of frames moved the bearing")
	for term: String in ["velocity", "extrapolat", "predict"]:
		assert_false(SourceScanner.code_contains(VM, term), "CompassVm mentions `%s`" % term)


func test_the_drawn_bearing_never_leads_the_one_it_was_given() -> void:
	# **THIS REPLACED A BAN ON THE WORD `lerp_angle`, AND IS STRICTLY STRONGER.**
	# The drawn angle now eases toward the authoritative one over
	# `TUN-NET-INTERP-BUFFER`, because the wire quantises the bearing to 1.41
	# degrees and drawing that raw is a staircase. A name-ban could not tell that
	# apart from extrapolation, and could not have caught extrapolation written
	# without the banned word. **The property is what matters: the chase starts
	# behind, converges, and never crosses to the other side.**
	var vm := CompassVm.new()
	vm.bucket = Quantise.distance_to_bucket(30.0)
	vm.bearing = 0.0
	vm.advance(1.0 / 60.0)
	vm.bearing = 1.0
	var previous := 0.0
	for _i: int in 600:
		vm.advance(1.0 / 60.0)
		var reached := vm.cone_radians()
		assert_between(reached, previous - 0.0001, 1.0, "the drawn bearing passed the target")
		previous = reached
	assert_almost_eq(previous, 1.0, 0.0001, "the drawn bearing never arrived")


func test_turning_the_camera_is_not_smoothed_at_all() -> void:
	# **THE HALF THAT MUST STAY INSTANT.** Only the world bearing is chased; the
	# camera's own yaw is applied on the frame it is read. Smoothing that would put
	# the one HUD element whose job is to track the player's head behind their
	# mouse, which is the defect the server-side bearing exists to avoid.
	var vm := CompassVm.new()
	vm.bucket = Quantise.distance_to_bucket(30.0)
	vm.bearing = 0.0
	vm.advance(1.0 / 60.0)
	vm.camera_yaw = 1.0
	assert_almost_eq(vm.cone_radians(), -1.0, 0.0001, "the camera yaw is being smoothed")


func test_no_numeric_distance_reaches_the_screen() -> void:
	# Showing metres deletes the entire point of a cadence-encoded channel. The
	# widget draws no text at all, which is the strongest version of this: there is
	# no `draw_string` to accidentally hand a number to.
	assert_false(
		SourceScanner.code_contains(WIDGET, "draw_string"),
		"the Compass draws text; the one thing it must never show is a number"
	)
	assert_false(SourceScanner.code_contains(WIDGET, "Label"), "the Compass gained a Label")


func test_nothing_is_encoded_in_hue() -> void:
	# **Distance is cadence, direction is position, lock is arc fill.** Colour
	# carries no meaning, which is why UI_UX_SPEC §7.3 needs no colourblind-safe
	# Compass palette — there is nothing to be blind to. The guard: every colour in
	# the widget is a near-neutral, so none of them can be a signal.
	# **ASSERTED ON THE PALETTE, NOT THE WIDGET** — as of US-0073 the widget names
	# no colour at all (UI_UX_SPEC §7), so the four Compass entries in `Palette`
	# are where this can still be checked. It has to hold for **every** palette
	# `US-0083` adds, which is why it reads the fields rather than four constants.
	var palette := Palette.fallback()
	for property: String in ["compass_cone", "compass_ring", "compass_lock", "compass_dot"]:
		var colour: Color = palette.get(property)
		assert_lt(colour.s, 0.12, "%s is saturated — the Compass encodes meaning in hue" % property)


func test_the_widget_reaches_for_nothing() -> void:
	# **Never-do #7.** A widget reads its view model; it does not fetch. A
	# `get_node` here is how the Compass would acquire the camera, and then the
	# pawn, and then a world position.
	assert_false(
		SourceScanner.code_contains(WIDGET, "get_node"),
		"the Compass widget reaches outside its own subtree"
	)
	assert_false(
		SourceScanner.code_contains(WIDGET, "get_tree"), "the Compass widget walks the tree"
	)
