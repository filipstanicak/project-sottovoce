## Samples the physical controls into one `InputCommand` per physics frame.
##
## **CLIENT ONLY, AND THE ONLY PLACE THAT TOUCHES `Input`.** Everything below the
## presentation layer receives an `InputCommand` and cannot tell a keyboard from
## a gamepad, which is what lets `step()` be replayed identically on a headless
## server that has neither.
##
## **THIS NODE HAS NO LOOP OF ITS OWN.** `LocalPawnDriver` calls `sample()` once
## per physics frame, which is TDD-03 §1.2's client diagram: one
## `_physics_process` that samples, sends, predicts and buffers, at
## `TUN-NET-CLIENT-INPUT-RATE`. Not `_process` either: a command per *rendered*
## frame would produce a different number of them on a 144 Hz monitor, and the
## simulation would depend on the display.
##
## It used to drive itself as well, emitting from its own `_physics_process`
## while the driver took a second sample — two calls a frame, 120 Hz, and every
## counter downstream running at twice its tunable. The sprint gate of the day
## is what showed it: the deprecated `TUN-SPEED-SPRINT-HOLD` opened in 0.21 s
## against a 0.4 s value, half the friction §1.5 defends. The signal
## therefore lives on the driver now, next to the call that produces it, so there
## is exactly one place a command can come from. `test_input_sampled_once.gd`.
##
## The rules this file applies — hold versus toggle, the sprint gate, the
## deadzone — all live in pure classes it delegates to (`InputLatch`,
## `SpeedGate`, `InputActions`). What is left here is the engine call and the
## assembly, which is the part a unit test cannot reach anyway.
class_name InputSampler
extends Node

## Look sensitivity, radians per pixel of mouse motion.
##
## NOT A TUNABLE, deliberately. A tunable is a value that decides how the game
## plays for everyone (TUNABLES §1.1); this is a per-player preference in the
## same class as a volume slider, and it belongs to `IProfileStore` — which is
## stubbed in MVP (ASM-0026), so it does not persist yet.
@export var mouse_sensitivity: float = 0.0022

## Right-stick look, radians per second at full deflection. Same reasoning.
@export var pad_look_speed: float = 3.2

var _latch := InputLatch.new()
var _speed := SpeedGate.new()
var _command := InputCommand.new()
var _seq: int = 0

## **FULL-PRECISION LOOK, ACCUMULATED HERE AND QUANTISED INTO THE COMMAND.**
##
## The command carries what the wire carries, so the client predicts with exactly
## the values the server will receive — quantising at *send* time instead would
## make the two peers step on different numbers and diverge every frame.
##
## The accumulator has to be separate. Rounding look in place would mean any
## frame whose motion is smaller than half a quantisation step rounds back to
## where it started — **a slow mouse drag would not turn the camera at all**, and
## the smaller the field, the more of the drag disappears.
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _mouse_delta: Vector2 = Vector2.ZERO
var _want_mouse: bool = false

## id -> InputLatch.Mode, for the five holdable actions. Individually
## configurable per GDD-02 §9.3; the pad default for `INPUT-SLOW` is TOGGLE
## because holding a stick click is uncomfortable, and that is set by whoever
## builds the options screen, not here.
var _modes: Dictionary = {}

var _rebinder: InputRebinder


func _ready() -> void:
	for id: StringName in InputActions.ids():
		if InputActions.is_toggleable(id):
			_modes[id] = InputLatch.Mode.HOLD
	_rebinder = InputRebinder.new()
	_choose_pad()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_capture_mouse(true)


## **BEFORE THE FIRST AXIS EVENT ARRIVES, AND THAT IS THE WHOLE POINT.** A pad's
## resting values reach the engine about a second after it enumerates, so a
## restriction applied at boot is applied in time; one applied lazily, on the
## first command, would already have a stuck action to undo.
func _choose_pad() -> void:
	var pads := _connected_pads()
	_rebinder.restrict_pad_device(PadSelection.chosen(pads))
	Log.info(PadSelection.describe(pads), &"input")


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_choose_pad()


## What is plugged in, as `PadSelection` wants it. `is_joy_known` is the
## discriminator: it is true only for a device the engine has a gamepad mapping
## for, which is exactly the question "is this a controller or is it pedals".
func _connected_pads() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: int in Input.get_connected_joypads():
		out.append({"id": id, "known": Input.is_joy_known(id), "name": Input.get_joy_name(id)})
	return out


## The rebinder the options screen must use (US-0079). One instance, because two
## would each hold their own idea of the shipped defaults and of which device is
## the pad, and the second one to write would win.
func rebinder() -> InputRebinder:
	return _rebinder


## **THE MOUSE IS CAPTURED, OR THERE IS NO MOUSE LOOK.** An uncaptured cursor
## stops at the window edge and stops generating relative motion with it, so the
## camera reaches a wall and will not turn further — and the player is left
## dragging a visible arrow across their own game.
##
## Here rather than in `CameraRig`, because `Input.mouse_mode` is `Input`, and
## this file is the only place in the project that touches it.
##
## `INPUT-MENU` releases so the window can be left; a click takes it back. There
## is no options screen to release into yet (US-0079), which is exactly why the
## escape hatch has to exist now.
func _capture_mouse(captured: bool) -> void:
	_want_mouse = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	if not captured:
		_mouse_delta = Vector2.ZERO


## Whether the sampler believes it holds the mouse — the flag it set, NOT a
## read-back of `Input.mouse_mode`.
##
## Headless has no display server to honour the request, so the mode never
## becomes `CAPTURED` there and reading it back would make every mouse-look test
## silently measure nothing. That is how this was found: the crowd-scan pan test
## started reporting a look delta of zero, which is a pass shape away from a
## test that quietly checks nothing at all.
func mouse_captured() -> bool:
	return _want_mouse


## Change one action between hold and toggle. GDD-02 §9.3: every hold input has
## both modes, individually.
func set_mode(id: StringName, mode: InputLatch.Mode) -> void:
	assert(InputActions.is_toggleable(id), "%s has no hold to toggle" % id)
	_modes[id] = mode
	_latch.release(id)


func mode_of(id: StringName) -> InputLatch.Mode:
	return _modes.get(id, InputLatch.Mode.HOLD)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.action_names(Ids.INPUT_MENU)[0]):
		_capture_mouse(false)
		return
	if not mouse_captured():
		# A click takes the window back. Motion is dropped while the cursor is
		# free, so the camera does not lurch by however far the mouse travelled
		# across the desktop in between.
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_capture_mouse(true)
		return
	# Accumulated rather than applied, because motion arrives at the OS event rate
	# and applying it here would turn look speed into a function of frame time.
	var motion := event as InputEventMouseMotion
	if motion != null:
		_mouse_delta += motion.relative


## Build this frame's command. Reuses one object; anything keeping a command
## past the frame must call `duplicate_command()` — `InputHistory` does.
##
## **CALL THIS EXACTLY ONCE PER PHYSICS FRAME.** It is not a getter: it advances
## `_seq`, ticks `SpeedGate`'s resolve window, and resolves every
## hold/toggle latch. A second call in the same frame charges all of them twice.
func sample(delta: float) -> InputCommand:
	_seq += 1
	_command.seq = _seq

	_command.buttons = InputBits.NONE
	# **BUTTONS BEFORE LOOK**, since US-0023. `INPUT-SCAN` scales look
	# sensitivity, and whether it is held is only known after the hold/toggle
	# latch has resolved — sampling the look first would apply a toggled scan one
	# frame late. Sixteen milliseconds nobody would feel, and a command whose own
	# fields disagreed with each other, which is the kind of thing a replay finds.
	# `_sample_buttons` reads `_command.move`, so move still goes first.
	_sample_move()
	_sample_buttons()
	_sample_look(delta)
	return _command


## Accumulated mouse motion and stick deflection, scaled by the crowd-scan
## multiplier if it applies, into the command's absolute yaw and pitch.
func _sample_look(delta: float) -> void:
	var scale := CameraFov.look_scale(_command.scan)
	_look_yaw -= _mouse_delta.x * mouse_sensitivity * scale
	_look_pitch -= _mouse_delta.y * mouse_sensitivity * scale
	_mouse_delta = Vector2.ZERO

	var pad := _vector_for(Ids.INPUT_LOOK)
	_look_yaw -= pad.x * pad_look_speed * delta * scale
	_look_pitch += pad.y * pad_look_speed * delta * scale
	_look_yaw = wrapf(_look_yaw, -PI, PI)
	_look_pitch = clampf(_look_pitch, -PI / 2.0, PI / 2.0)

	# **THE COMMAND HOLDS WHAT THE WIRE HOLDS.** 0.0055° a step — finer than a
	# mouse can express — so nothing is felt, and `InputCodec.serialise` is exactly
	# lossless from here.
	_command.look_yaw = InputCodec.quantise_yaw(_look_yaw)
	_command.look_pitch = InputCodec.quantise_pitch(_look_pitch)


func _sample_move() -> void:
	var raw := _vector_for(Ids.INPUT_MOVE)
	if raw.length() > 1.0:
		raw = raw.normalized()
	# Quantised for the same reason as look, and safe to do in place: `move` is
	# read fresh from the device every frame rather than accumulated, so rounding
	# it cannot stick.
	_command.move = InputCodec.quantise_move(raw)


## Read one AXIS action's four bindings as a vector, with the deadzone applied by
## the engine so a drifting stick never reaches `wants_movement()`.
func _vector_for(id: StringName) -> Vector2:
	var names := InputActions.action_names(id)
	return Input.get_vector(names[0], names[1], names[2], names[3], Tuning.movement.stick_deadzone)


func _sample_buttons() -> void:
	for id: StringName in InputActions.wire_ids():
		if id == Ids.INPUT_SPRINT or id == Ids.INPUT_RUN:
			continue  # Both have analogue rules; handled below.
		var name := InputActions.action_names(id)[0]
		var active := Input.is_action_pressed(name)
		if InputActions.is_toggleable(id):
			active = _latch.resolve(id, active, mode_of(id))
		_command.buttons = InputBits.with(_command.buttons, InputActions.bit_of(id), active)

	_sample_speed()
	_apply_pad_blend_walk()


## `INPUT-RUN` is analogue on a trigger. Any pull runs; a pull past
## `TUN-SPEED-TRIGGER-RUN` is the pull at which the trigger reads as held at all.
## It used to split partial (Jog) from full (Run); with the Jog rung deprecated a
## partial pull has nothing to mean, so below the threshold the trigger simply
## does not run. A key press reads 1.0 and is always through it.
##
## **ONE KEY DECIDES BOTH SPEEDS**, so both bits are written here. `INPUT-RUN`
## and `INPUT-SPRINT` are the same key on the keyboard by default, and on a pad
## either of them feeds the same gate — holding resolves to Run, double-tapping
## to Sprint. `SpeedGate` owns the rule; a toggle mode still pays it, because a
## toggle that skipped the double-tap would be an accessibility option that
## removed the design's only deliberate cost.
##
## The gamepad keeps its second route: full trigger plus traverse, GDD-02 §1.3's
## "L2 full + A". That one is NOT gated, because it is already two simultaneous
## inputs — the pad's version of the same awkwardness. §9.3 requires a
## single-input alternative to exist, and the gated key is it.
##
## **AND IT IS THE PAD'S ROUTE ONLY.** `INPUT-TRAVERSE` is `Space` on a keyboard,
## so a combo that asked only "is traverse held" made **Shift + Space sprint** —
## found by the owner running at a wall and arriving in a sprint they had not
## asked for. It predates US-0090 and got easier to hit when Shift started
## meaning Run. `PadSelection` already knows whether a mapped pad holds the
## bindings; without one, this route does not exist.
func _sample_speed() -> void:
	var pressed := _run_pressed() or _sprint_pressed()
	var want := _speed.update(pressed)
	if pressed and _pad_sprint_combo():
		want = SpeedGate.Want.SPRINT
	_command.buttons = InputBits.with(_command.buttons, InputBits.RUN, want != SpeedGate.Want.NONE)
	_command.buttons = InputBits.with(
		_command.buttons, InputBits.SPRINT, want == SpeedGate.Want.SPRINT
	)


func _run_pressed() -> bool:
	var name := InputActions.action_names(Ids.INPUT_RUN)[0]
	var held := Input.get_action_strength(name) >= Tuning.movement.trigger_run
	if mode_of(Ids.INPUT_RUN) == InputLatch.Mode.TOGGLE:
		held = _latch.resolve(Ids.INPUT_RUN, held, InputLatch.Mode.TOGGLE)
	return held


func _sprint_pressed() -> bool:
	var name := InputActions.action_names(Ids.INPUT_SPRINT)[0]
	var held := Input.is_action_pressed(name)
	if mode_of(Ids.INPUT_SPRINT) == InputLatch.Mode.TOGGLE:
		held = _latch.resolve(Ids.INPUT_SPRINT, held, InputLatch.Mode.TOGGLE)
	return held


func _pad_sprint_combo() -> bool:
	if _rebinder == null or _rebinder.pad_device() == PadSelection.NO_DEVICE:
		return false
	return Input.is_action_pressed(InputActions.action_names(Ids.INPUT_TRAVERSE)[0])


## A gamepad walking gently is blend-walking, without holding anything
## (GDD-02 §1.3). A keyboard cannot reach this band — its stick magnitude is
## always 0 or 1 — so no modifier check is needed to keep the two apart.
func _apply_pad_blend_walk() -> void:
	var magnitude := _command.move.length()
	if magnitude <= 0.0 or magnitude > Tuning.movement.stick_blendwalk_max:
		return
	_command.buttons = InputBits.with(_command.buttons, InputBits.SLOW, true)


## Drop every latch and half-entered double-tap. Called on respawn: a toggle that
## survived a death would have the player blend-walking out of their own spawn.
func reset() -> void:
	_latch.release_all()
	_speed.reset()
	_mouse_delta = Vector2.ZERO
