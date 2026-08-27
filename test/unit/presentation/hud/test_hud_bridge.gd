## **THE SNAPSHOT BECOMES AN EVENT EXACTLY ONCE.** ADR-0006, US-0072.
##
## `EventBus` was declared at M0, guarded ever since, and **had zero emitters until
## this bridge** — twenty signals wired to nothing. So the first thing worth
## asserting is that the bus now carries traffic at all; the second is that it
## carries it *on change*, because a snapshot lands thirty times a second and
## almost nothing in it moves.
extends GutTest

var _bridge: HudBridge
var _tiers: Array = []
var _compass: Array = []
var _combat: Array = []
var _portraits: Array = []


func before_each() -> void:
	_tiers = []
	_compass = []
	_combat = []
	_portraits = []
	_bridge = HudBridge.new()
	add_child_autofree(_bridge)
	EventBus.suspicion_tier_changed.connect(_on_tier)
	EventBus.compass_updated.connect(_on_compass)
	EventBus.kill_ready_changed.connect(_on_combat)
	EventBus.contract_portrait_revealed.connect(_on_portrait)


func after_each() -> void:
	# **THE BUS IS AN AUTOLOAD AND OUTLIVES THIS TEST.** A listener left connected
	# is handed to whatever runs next — US-0037's lesson, one layer up.
	EventBus.suspicion_tier_changed.disconnect(_on_tier)
	EventBus.compass_updated.disconnect(_on_compass)
	EventBus.kill_ready_changed.disconnect(_on_combat)
	EventBus.contract_portrait_revealed.disconnect(_on_portrait)


func _on_tier(tier: int, sources: int) -> void:
	_tiers.append([tier, sources])


func _on_compass(bearing: float, bucket: int, lock: float) -> void:
	_compass.append([bearing, bucket, lock])


func _on_combat(kill: bool, stun: bool) -> void:
	_combat.append([kill, stun])


func _on_portrait(persona: StringName) -> void:
	_portraits.append(persona)


func _snapshot() -> Snapshot:
	var s := Snapshot.new()
	s.tier = 0
	s.bearing = 64
	s.distance_bucket = 40
	s.lock_fraction = 0
	return s


func _deliver(s: Snapshot) -> void:
	Net.snapshot_received.emit(s)


func test_the_bus_carries_traffic_at_all() -> void:
	# **THE PREMISE.** Every "emitted once" assertion below is satisfied by a
	# bridge that emits nothing ever, and this is what stops the file passing that
	# way. It is also the assertion that would have failed on every day of this
	# project before today.
	_deliver(_snapshot())
	assert_eq(_compass.size(), 1, "the compass block never reached the bus")
	assert_eq(_tiers.size(), 1, "the first snapshot did not announce a tier")


func test_the_first_snapshot_is_always_a_change() -> void:
	# **`NOTHING` IS −1, NOT 0.** Zero is a real tier and a real bearing, so a
	# bridge seeded with zero would swallow the opening state of a match — and the
	# HUD would stay blank until the player's suspicion happened to move.
	var s := _snapshot()
	s.tier = 0
	s.active_sources = 0
	_deliver(s)
	assert_eq(_tiers.size(), 1, "a tier of zero was mistaken for 'nothing yet'")


func test_an_unchanged_tier_is_not_re_announced() -> void:
	for _i: int in 30:
		_deliver(_snapshot())
	assert_eq(_tiers.size(), 1, "the tier was re-announced on every packet")
	assert_eq(_combat.size(), 0, "combat readiness was announced without changing")


func test_the_compass_is_the_deliberate_exception() -> void:
	# Its bearing changes almost every tick *by construction* — the wobble is a
	# function of the tick — so a change test there would pass every time and cost
	# a comparison to do it.
	for _i: int in 5:
		_deliver(_snapshot())
	assert_eq(_compass.size(), 5, "the compass is being change-gated; it must not be")


func test_the_wire_is_decoded_here_and_not_in_a_widget() -> void:
	# A widget that decoded a yaw byte would be a second place that knows the
	# protocol, and the first one to drift from it.
	var s := _snapshot()
	s.bearing = 192
	s.lock_fraction = 255
	_deliver(s)
	assert_almost_eq(
		float(_compass[0][0]), Quantise.u8_to_yaw(192), 0.0001, "the bearing was not decoded"
	)
	assert_almost_eq(float(_compass[0][2]), 1.0, 0.0001, "a full lock did not decode to 1.0")


func test_the_portrait_reveal_carries_no_persona() -> void:
	# **ASM-0030.** The persona is not on the wire and must not be guessed: a
	# client learns its contract's appearance by *looking*, and the reveal is the
	# moment it is allowed to. An invented value here would be the anonymity leak
	# the whole lock exists to price.
	var s := _snapshot()
	s.portrait_revealed = true
	_deliver(s)
	assert_eq(_portraits.size(), 1, "the reveal never reached the bus")
	assert_eq(_portraits[0], &"", "the bridge invented a persona it was never sent")


func test_a_freed_bridge_stops_listening() -> void:
	# The autoload outlives the scene. A bridge still connected after the client
	# is freed emits into a bus whose listeners are gone.
	var extra := HudBridge.new()
	add_child(extra)
	assert_true(Net.snapshot_received.is_connected(extra._on_snapshot))
	extra.free()
	_deliver(_snapshot())
	assert_eq(_compass.size(), 1, "a freed bridge is still publishing")
