## **THE PURSUIT BARS ON THE CLIENT.** US-0097's last criterion, UI_UX_SPEC §1.1 H.
##
## Three things are worth asserting here and one of them is not about drawing:
## the pulse fires on a **rise** and not on a drain, the two arcs share the
## Compass's centre by derivation rather than by two people typing 174, and
## **nothing in this path can name a player**.
extends GutTest

const VM_SRC := "res://scripts/presentation/hud/chase_vm.gd"
const WIDGET_SRC := "res://scripts/presentation/hud/chase_ring_widget.gd"

var _vm: ChaseVm
var _bridge: HudBridge
var _seen: Array = []


func before_each() -> void:
	_vm = ChaseVm.new()
	_seen = []
	_bridge = HudBridge.new()
	add_child_autofree(_bridge)
	EventBus.pursuit_changed.connect(_on_pursuit)


func after_each() -> void:
	# The bus is an autoload and outlives this test — US-0037's lesson, one layer up.
	EventBus.pursuit_changed.disconnect(_on_pursuit)


func _on_pursuit(hunting: float, hunted: float) -> void:
	_seen.append([hunting, hunted])


func _snapshot(hunt: int, hunted: int) -> Snapshot:
	var s := Snapshot.new()
	s.hunt_fraction = hunt
	s.hunted_fraction = hunted
	return s


# --- the view model -------------------------------------------------------


func test_a_quiet_client_draws_neither_bar() -> void:
	assert_true(_vm.is_quiet())
	assert_false(_vm.is_hunting())
	assert_false(_vm.is_hunted())


func test_hunting_and_being_hunted_are_independent() -> void:
	# **THE CASE THAT IS NOT AN EDGE CASE.** A cycle makes every player both.
	_vm.apply(1.0, 0.25)
	assert_true(_vm.is_hunting())
	assert_true(_vm.is_hunted())
	assert_false(_vm.is_quiet())


## **THE PULSE IS THE ANSWER TO A PEGGED BAR.** Sight refreshes to full every tick
## it lasts, so a hunter holding their prey in view holds the value at 1.0 with no
## motion — and a motionless instrument reads as a dead one. The rise is the event.
func test_a_rise_pulses_and_a_drain_does_not() -> void:
	_vm.apply(0.0, 0.4)
	assert_gt(_vm.flash(), 0.0, "the first sighting did not pulse")
	_vm.advance(ChaseVm.FLASH_SECONDS)
	assert_eq(_vm.flash(), 0.0, "the pulse did not decay")
	_vm.apply(0.0, 0.3)
	assert_eq(_vm.flash(), 0.0, "a draining bar pulsed as though it had been refreshed")


func test_a_re_acquisition_pulses_again() -> void:
	_vm.apply(0.0, 0.4)
	_vm.advance(ChaseVm.FLASH_SECONDS)
	_vm.apply(0.0, 1.0)
	assert_gt(_vm.flash(), 0.0, "being seen again did not pulse")


func test_the_pulse_never_goes_negative() -> void:
	_vm.apply(0.0, 0.4)
	_vm.advance(ChaseVm.FLASH_SECONDS * 10.0)
	assert_eq(_vm.flash(), 0.0)


# --- the bridge -----------------------------------------------------------


func test_the_bridge_emits_fractions_not_bytes() -> void:
	_bridge._on_snapshot(_snapshot(255, 0))
	assert_eq(_seen.size(), 1, "the bridge said nothing about a live chase")
	assert_almost_eq(float(_seen[0][0]), 1.0, 0.001)
	assert_almost_eq(float(_seen[0][1]), 0.0, 0.001)


## **ON CHANGE, NEVER ON ARRIVAL** — and the comparison earns more here than
## anywhere else in that class, because most of a match has no chase at all.
func test_the_bridge_is_silent_while_nothing_moves() -> void:
	_bridge._on_snapshot(_snapshot(120, 30))
	_bridge._on_snapshot(_snapshot(120, 30))
	_bridge._on_snapshot(_snapshot(120, 30))
	assert_eq(_seen.size(), 1, "an unchanged pair was republished")


func test_either_bar_moving_is_enough_to_republish() -> void:
	_bridge._on_snapshot(_snapshot(120, 30))
	_bridge._on_snapshot(_snapshot(120, 31))
	assert_eq(_seen.size(), 2, "the hunted bar moved and nobody was told")


func test_the_two_bars_reach_the_bridge_the_right_way_round() -> void:
	_bridge._on_snapshot(_snapshot(255, 51))
	assert_almost_eq(float(_seen[0][0]), 1.0, 0.001, "hunting arrived as hunted")
	assert_almost_eq(float(_seen[0][1]), 0.2, 0.01, "hunted arrived as hunting")


# --- the widget -----------------------------------------------------------


## **THE TWO ELEMENTS SHARE A CENTRE BY DERIVATION, NOT BY TWO PEOPLE TYPING 174.**
## `ChaseRingWidget` computes its offsets from `CompassWidget`'s own constants, so
## moving the Compass moves the bars with it. Retuning either diameter and leaving
## the other reddens this.
func test_the_ring_is_concentric_with_the_compass() -> void:
	var compass := CompassWidget.new()
	var ring := ChaseRingWidget.new()
	add_child_autofree(compass)
	add_child_autofree(ring)
	assert_almost_eq(
		(compass.offset_top + compass.offset_bottom) * 0.5,
		(ring.offset_top + ring.offset_bottom) * 0.5,
		0.001,
		"the chase ring and the Compass do not share a centre"
	)
	assert_almost_eq(
		(compass.offset_left + compass.offset_right) * 0.5,
		(ring.offset_left + ring.offset_right) * 0.5,
		0.001
	)


## Both arcs sit outside the lock arc and its stroke, or a full lock and a full
## chase read as one thick ring rather than as two instruments.
func test_neither_bar_overlaps_the_lock_arc() -> void:
	var lock_outer: float = CompassWidget.LOCK_RADIUS + CompassWidget.LOCK_WIDTH * 0.5
	var hunted_inner: float = ChaseRingWidget.HUNTED_RADIUS - ChaseRingWidget.WIDTH * 0.5
	assert_gt(hunted_inner, lock_outer, "the hunted bar is drawn on top of the lock arc")
	assert_gt(
		ChaseRingWidget.HUNT_RADIUS - ChaseRingWidget.WIDTH * 0.5,
		ChaseRingWidget.HUNTED_RADIUS + ChaseRingWidget.WIDTH * 0.5 + ChaseRingWidget.FLASH_WIDTH,
		"a pulsing hunted bar reaches the hunt bar"
	)


## **NEVER-DO #12, STRUCTURALLY.** A bar that named its owner would be a nameplate
## on a player the prey has earned nothing about. The wire carries two fractions
## and there is no identity anywhere in this path to leak — asserted rather than
## observed, so adding one is a deliberate act.
func test_the_chase_path_can_name_nobody() -> void:
	var offenders: PackedStringArray = []
	for path: String in [VM_SRC, WIDGET_SRC]:
		for needle: String in ["peer", "slot", "persona", "contract_of", "pursuer"]:
			if SourceScanner.code_contains(path, needle):
				offenders.append("%s names `%s`" % [path.get_file(), needle])
	assert_eq(offenders.size(), 0, "\n".join(offenders))
