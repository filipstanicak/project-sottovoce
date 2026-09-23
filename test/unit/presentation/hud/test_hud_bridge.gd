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
var _match_ticks: Array = []


func before_each() -> void:
	_tiers = []
	_compass = []
	_combat = []
	_portraits = []
	_match_ticks = []
	_bridge = HudBridge.new()
	add_child_autofree(_bridge)
	_bridge.match_time_changed.connect(func(ticks: int) -> void: _match_ticks.append(ticks))
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


func _on_portrait() -> void:
	_portraits.append(true)


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


func test_the_lock_completion_reaches_the_bus_carrying_nothing() -> void:
	# **THE SIGNAL IS PARAMETERLESS** (ADR-0021): the wire field is a per-contract
	# lock-completion latch, and the persona is known from assignment rather than
	# from this. It carried a `persona` the bridge could only fill with `&""` until
	# 2026-09-22 — a payload that says nothing is worse than none.
	var s := _snapshot()
	s.portrait_revealed = true
	_deliver(s)
	assert_eq(_portraits.size(), 1, "the lock completion never reached the bus")
	for row: Dictionary in EventBus.get_signal_list():
		if row["name"] == "contract_portrait_revealed":
			assert_eq(
				(row["args"] as Array).size(),
				0,
				"the signal grew a parameter; a lock completion has nothing to carry"
			)


func test_a_freed_bridge_stops_listening() -> void:
	# The autoload outlives the scene. A bridge still connected after the client
	# is freed emits into a bus whose listeners are gone.
	var extra := HudBridge.new()
	add_child(extra)
	assert_true(Net.snapshot_received.is_connected(extra._on_snapshot))
	extra.free()
	_deliver(_snapshot())
	assert_eq(_compass.size(), 1, "a freed bridge is still publishing")


## **THE MATCH CLOCK IS FORWARDED DURING PLAY, ON CHANGE, AND NOWHERE ELSE.** US-0073.
## The same local wiring as `results_time_changed`, for the phases whose remainder is
## the match's own clock; a lobby has no clock and the results screen has its own.
func test_the_match_clock_is_forwarded_during_play_and_only_on_change() -> void:
	var s := _snapshot()
	s.phase = MatchPhase.Phase.ACTIVE
	s.ticks_remaining = 300
	_deliver(s)
	_deliver(s)
	assert_eq(_match_ticks, [300], "an unchanged remainder was forwarded twice")
	s.ticks_remaining = 299
	_deliver(s)
	s.phase = MatchPhase.Phase.FINAL
	s.ticks_remaining = 298
	_deliver(s)
	assert_eq(_match_ticks, [300, 299, 298])


func test_the_match_clock_is_silent_outside_play() -> void:
	var s := _snapshot()
	s.ticks_remaining = 150
	for phase: int in [MatchPhase.Phase.LOBBY, MatchPhase.Phase.WARMUP, MatchPhase.Phase.RESULTS]:
		s.phase = phase
		_deliver(s)
	assert_eq(_match_ticks, [], "the match clock was forwarded outside play")
