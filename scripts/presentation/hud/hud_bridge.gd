## **THE ONE PLACE A SNAPSHOT BECOMES AN EVENT.** ADR-0006, US-0072. CLIENT ONLY.
##
## `SIGNAL_AND_EVENT_BUS.md` has said since M0 that this bridge *"belongs to the
## first presentation node that wants it"*. The HUD is that node, and until now
## **every one of `EventBus`'s twenty signals had zero emitters** — the bus was
## declared, guarded and wired to nothing.
##
## **IT EXISTS SO THAT NOTHING ELSE READS A SNAPSHOT.** ADR-0006's one-way flow is
## `Net` → here → `EventBus` → view model → widget, and the value of a single
## doorway is that a widget cannot reach past its view model for a field the
## designer chose not to expose. A second bridge would be a second doorway.
##
## **IT EMITS ON CHANGE, NEVER ON ARRIVAL.** A snapshot lands 30 times a second and
## almost nothing in it moves: a tier changes a handful of times a match, a
## portrait once. Emitting unconditionally would make every widget's redraw
## condition *"a packet arrived"*, which is the shape that makes a HUD cost frame
## time in an empty district.
##
## **THE COMPASS IS THE ONE EXCEPTION AND IT IS DELIBERATE.** Its bearing changes
## almost every tick by construction — the wobble is a function of the tick — so a
## change test there would pass every time and cost an extra comparison to do it.
class_name HudBridge
extends Node

## Nothing has arrived yet. **Not zero**, because zero is a real tier and a real
## bearing; the first snapshot must always be treated as a change.
const NOTHING := -1

var _tier: int = NOTHING
var _sources: int = NOTHING
var _blend: int = NOTHING
var _kill_ready: bool = false
var _stun_ready: bool = false
var _portrait: bool = false
var _phase: int = NOTHING
var _multiplier: int = NOTHING
var _hunting: int = NOTHING
var _hunted: int = NOTHING


func _ready() -> void:
	Net.snapshot_received.connect(_on_snapshot)
	Net.events.score_reported.connect(_on_score)


func _exit_tree() -> void:
	# **ENet REUSES NOTHING HERE, BUT THE AUTOLOAD OUTLIVES THE SCENE.** A bridge
	# left connected after the client scene is freed emits into a bus whose
	# listeners are gone, which is US-0037's lesson in a presentation costume.
	if Net.snapshot_received.is_connected(_on_snapshot):
		Net.snapshot_received.disconnect(_on_snapshot)
	if Net.events.score_reported.is_connected(_on_score):
		Net.events.score_reported.disconnect(_on_score)


func _on_snapshot(snapshot: Snapshot) -> void:
	_publish_suspicion(snapshot)
	_publish_compass(snapshot)
	_publish_combat(snapshot)
	_publish_pursuit(snapshot)
	_publish_match(snapshot)


## Tier and its source list travel together, because the tier indicator shows both
## and a reader that got them from two signals could paint a tier with the previous
## tier's reasons for one frame.
##
## **THE NUMERIC VALUE GOES OUT SEPARATELY AND NO SHIPPING WIDGET SUBSCRIBES.**
## UI_UX_SPEC §4 forbids it on screen; the signal exists for the debug overlay,
## which is stripped from every release preset.
func _publish_suspicion(snapshot: Snapshot) -> void:
	EventBus.suspicion_value_changed.emit(snapshot.suspicion)
	if _tier == snapshot.tier and _sources == snapshot.active_sources:
		return
	_tier = snapshot.tier
	_sources = snapshot.active_sources
	EventBus.suspicion_tier_changed.emit(_tier, _sources)


## **DECODED HERE, NEVER IN THE WIDGET.** The wire carries a yaw byte, a bucket and
## a lock byte; a widget that decoded them would be a second place that knows the
## protocol, and the first one to drift.
func _publish_compass(snapshot: Snapshot) -> void:
	var bearing := Quantise.u8_to_yaw(snapshot.bearing)
	EventBus.compass_updated.emit(bearing, snapshot.distance_bucket, snapshot.lock_fraction / 255.0)
	if _portrait == snapshot.portrait_revealed:
		return
	_portrait = snapshot.portrait_revealed
	if _portrait:
		# **THE PERSONA IS NOT ON THE WIRE AND MUST NOT BE GUESSED.** ASM-0030: a
		# client learns its contract's appearance by *looking*, and the reveal is
		# the moment it is allowed to. `&""` says "revealed, ask the mesh", which
		# is US-0073's problem and not a value this bridge may invent.
		EventBus.contract_portrait_revealed.emit(&"")


func _publish_combat(snapshot: Snapshot) -> void:
	if _kill_ready == snapshot.kill_ready and _stun_ready == snapshot.stun_ready:
		return
	_kill_ready = snapshot.kill_ready
	_stun_ready = snapshot.stun_ready
	EventBus.kill_ready_changed.emit(_kill_ready, _stun_ready)


## **THE CHANGE TEST EARNS ITS KEEP HERE MORE THAN ANYWHERE ELSE IN THIS CLASS.**
## While a chase is live the bytes move on most ticks — 255 steps over the 322 the
## bar lasts — so this looks like the Compass, which is the documented exception.
## It is not: **most of a match has no chase at all**, and the two bytes are then
## zero and stay zero. The comparison suppresses the common case and passes the
## rare one straight through, which is the opposite way round from the bearing.
##
## **COMPARED AS BYTES, EMITTED AS FRACTIONS.** Comparing the divided floats would
## be a float equality test on a value that arrived as an integer, which is a
## comparison that is true by luck rather than by construction.
func _publish_pursuit(snapshot: Snapshot) -> void:
	if _hunting == snapshot.hunt_fraction and _hunted == snapshot.hunted_fraction:
		return
	_hunting = snapshot.hunt_fraction
	_hunted = snapshot.hunted_fraction
	EventBus.pursuit_changed.emit(_hunting / 255.0, _hunted / 255.0)


func _publish_match(snapshot: Snapshot) -> void:
	if _blend != snapshot.blend_state:
		_blend = snapshot.blend_state
		EventBus.blend_state_changed.emit(_blend)
	if _phase == snapshot.phase and _multiplier == snapshot.multiplier:
		return
	_phase = snapshot.phase
	_multiplier = snapshot.multiplier
	EventBus.match_phase_changed.emit(_phase, float(_multiplier))


## **THE ONE THING HERE THAT IS NOT A SNAPSHOT, AND IT IS FORWARDED UNCHANGED.**
## Everything else in this class exists to answer *did this field change since the
## last packet*; a score event has no previous value to compare against — it either
## happened or it did not. `EventBus`'s own taxonomy calls this a **moment** rather
## than a state, and moments are re-emitted verbatim.
##
## **THE DECODING ALREADY HAPPENED**, in `ScoreWire`, which is why this is one
## line: the rule that a widget must not know the protocol is served by the wire
## owning its own layout rather than by this class translating a second format.
func _on_score(report: ScoreReport) -> void:
	EventBus.score_event_appended.emit(report)
