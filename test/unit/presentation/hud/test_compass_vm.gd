## **THE COMPASS'S VIEW MODEL.** US-0072, UI_UX_SPEC §3.
##
## The story's own test note: *"asserts the period against the sampled table at
## every listed distance"*. That table is TUNABLES §4.2 and `CompassMath` is
## already tested against it — what is tested here is that **the view model reaches
## it correctly through a bucket**, which is the step where a client could get the
## cadence wrong while every Core test stayed green.
extends GutTest

var _vm: CompassVm


func before_each() -> void:
	_vm = CompassVm.new()


func _at(metres: float) -> void:
	_vm.bucket = Quantise.distance_to_bucket(metres)


func test_the_period_matches_the_authoritative_curve() -> void:
	# **THE PREMISE.** Every assertion below is satisfied by a view model that
	# returns the same period at every distance, and this is what stops the file
	# passing that way.
	_at(5.0)
	var near := _vm.period()
	_at(40.0)
	var far := _vm.period()
	assert_lt(near, far, "the period does not shorten as the contract gets closer")

	for metres: float in [2.0, 5.0, 10.0, 15.0, 20.0, 30.0, 40.0, 50.0]:
		_at(metres)
		var expected := CompassMath.period_for(
			Quantise.bucket_to_distance(Quantise.distance_to_bucket(metres)), Tuning.compass
		)
		assert_almost_eq(_vm.period(), expected, 0.0005, "period disagrees at %.0f m" % metres)


func test_no_contract_means_no_pulse_at_all() -> void:
	# **`NO_CONTRACT` IS 255, NEVER BUCKET 0.** Zero is a real reading — a hunter
	# standing on top of their contract — so a Compass that pulsed at maximum rate
	# during `TUN-CONTRACT-REASSIGN-DELAY` would turn the breath into three seconds
	# of the most urgent signal the instrument has.
	_vm.bucket = CompassBoard.NO_CONTRACT
	assert_false(_vm.has_contract())
	assert_eq(_vm.period(), 0.0, "a Compass with no contract still has a cadence")
	assert_false(_vm.advance(1.0), "it pulsed with nobody to point at")
	assert_eq(_vm.phase(), 0.0, "the phase advanced with no contract")


func test_the_phase_wraps_once_per_period_and_signals() -> void:
	_at(20.0)
	var period := _vm.period()
	# **A LAMBDA CAPTURES AN `int` BY VALUE**, so a counter incremented inside one
	# stays zero outside it — and the failure reads as *the signal never fired*
	# rather than as *the test cannot see it*. An array is captured by reference.
	var pulses: Array[int] = [0]
	_vm.pulsed.connect(func() -> void: pulses[0] += 1)
	# Sixty display frames per period, for three periods, plus one frame so the
	# third wrap lands rather than sitting a rounding error short of it.
	for _i: int in 181:
		_vm.advance(period / 60.0)
	assert_eq(pulses[0], 3, "expected exactly three pulses in three periods")


func test_a_frame_longer_than_a_period_does_not_leave_the_phase_over_one() -> void:
	# An alt-tab or a shader compile. A single subtraction would leave the phase
	# above 1.0 and the ring drawn inside out until the next frame caught up.
	_at(3.0)
	_vm.advance(_vm.period() * 4.5)
	assert_between(_vm.phase(), 0.0, 1.0, "the phase escaped its range after a long frame")


func test_onset_is_the_sharp_event() -> void:
	# **THE ONE ASSERTION THAT PROTECTS THE INSTRUMENT'S READABILITY.** Scale eases
	# out and alpha eases in, so the ring expands fast and fades slow. Matched
	# easings read as a throb rather than a beat and make the cadence — which is
	# the whole distance channel — much harder to judge.
	#
	# Measured as: in the first quarter of a period the ring has already covered
	# most of its travel, while it has lost only a little of its alpha.
	_at(20.0)
	var period := _vm.period()
	_vm.advance(period * 0.25)
	var travelled := (_vm.ring_scale() - 1.0) / 0.35
	var faded := 1.0 - _vm.ring_alpha() / 0.9
	assert_gt(travelled, 0.55, "the ring no longer leaves quickly; scale is not ease-out")
	assert_lt(faded, 0.15, "the ring no longer fades slowly; alpha is not ease-in")
	assert_gt(travelled, faded, "scale and alpha ease the same way — the pulse is a throb")


func test_the_cone_is_camera_relative() -> void:
	# **§3.3: a north-relative compass is a map**, and never-do #12 forbids one.
	_at(10.0)
	_vm.bearing = 0.0
	_vm.camera_yaw = 0.0
	assert_almost_eq(_vm.cone_radians(), 0.0, 0.0001, "a contract dead ahead is not drawn ahead")
	_vm.camera_yaw = PI * 0.5
	assert_almost_eq(
		_vm.cone_radians(), -PI * 0.5, 0.0001, "turning the camera did not turn the cone"
	)


func test_turning_the_camera_never_changes_the_bearing() -> void:
	# The cone moves; the reading does not. A view model that rotated its stored
	# bearing would drift a little further from the server on every frame, and the
	# error would look like wobble.
	_at(10.0)
	_vm.bearing = 1.0
	for i: int in 100:
		_vm.camera_yaw = float(i)
		_vm.cone_radians()
	assert_eq(_vm.bearing, 1.0, "the view model rewrote the authoritative bearing")
