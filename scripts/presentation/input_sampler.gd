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
## counter downstream running at twice its tunable. `SprintGate` was the one that
## showed: `TUN-SPEED-SPRINT-HOLD` opened in 0.21 s instead of 0.4. The signal
## therefore lives on the driver now, next to the call that produces it, so there
## is exactly one place a command can come from. `test_input_sampled_once.gd`.
##
## The rules this file applies — hold versus toggle, the sprint gate, the
## deadzone — all live in pure classes it delegates to (`InputLatch`,
## `SprintGate`, `InputActions`). What is left here is the engine call and the
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
var _sprint := SprintGate.new()
var _command := InputCommand.new()
var _seq: int = 0
var _mouse_delta: Vector2 = Vector2.ZERO

## id -> InputLatch.Mode, for the five holdable actions. Individually
## configurable per GDD-02 §9.3; the pad default for `INPUT-SLOW` is TOGGLE
## because holding a stick click is uncomfortable, and that is set by whoever
## builds the options screen, not here.
var _modes: Dictionary = {}


func _ready() -> void:
	for id: StringName in InputActions.ids():
		if InputActions.is_toggleable(id):
			_modes[id] = InputLatch.Mode.HOLD


## Change one action between hold and toggle. GDD-02 §9.3: every hold input has
## both modes, individually.
func set_mode(id: StringName, mode: InputLatch.Mode) -> void:
	assert(InputActions.is_toggleable(id), "%s has no hold to toggle" % id)
	_modes[id] = mode
	_latch.release(id)


func mode_of(id: StringName) -> InputLatch.Mode:
	return _modes.get(id, InputLatch.Mode.HOLD)


func _unhandled_input(event: InputEvent) -> void:
	# Accumulated rather than applied, because motion arrives at the OS event rate
	# and applying it here would turn look speed into a function of frame time.
	var motion := event as InputEventMouseMotion
	if motion != null:
		_mouse_delta += motion.relative


## Build this frame's command. Reuses one object; anything keeping a command
## past the frame must call `duplicate_command()` — `InputHistory` does.
##
## **CALL THIS EXACTLY ONCE PER PHYSICS FRAME.** It is not a getter: it advances
## `_seq`, ticks `SprintGate`'s hold and double-tap counters, and resolves every
## hold/toggle latch. A second call in the same frame charges all of them twice.
func sample(delta: float) -> InputCommand:
	_seq += 1
	_command.seq = _seq
	_command.client_tick = _seq
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
	_command.look_yaw -= _mouse_delta.x * mouse_sensitivity * scale
	_command.look_pitch -= _mouse_delta.y * mouse_sensitivity * scale
	_mouse_delta = Vector2.ZERO

	var pad := _vector_for(Ids.INPUT_LOOK)
	_command.look_yaw -= pad.x * pad_look_speed * delta * scale
	_command.look_pitch += pad.y * pad_look_speed * delta * scale
	_command.look_yaw = wrapf(_command.look_yaw, -PI, PI)
	_command.look_pitch = clampf(_command.look_pitch, -PI / 2.0, PI / 2.0)


func _sample_move() -> void:
	var raw := _vector_for(Ids.INPUT_MOVE)
	if raw.length() > 1.0:
		raw = raw.normalized()
	_command.move = raw


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

	_sample_run()
	_sample_sprint()
	_apply_pad_blend_walk()


## `INPUT-RUN` is analogue on a trigger. Any pull runs; a pull past
## `TUN-SPEED-TRIGGER-RUN` runs *fully*, which is the only thing that escalates
## Jog -> Run. A key press reads 1.0, so the keyboard is always full.
func _sample_run() -> void:
	var name := InputActions.action_names(Ids.INPUT_RUN)[0]
	var strength := Input.get_action_strength(name)
	var held := strength > Tuning.movement.stick_deadzone
	if mode_of(Ids.INPUT_RUN) == InputLatch.Mode.TOGGLE:
		held = _latch.resolve(Ids.INPUT_RUN, held, InputLatch.Mode.TOGGLE)
		strength = 1.0 if held else 0.0
	_command.buttons = InputBits.with(_command.buttons, InputBits.RUN, held)
	var full: bool = held and strength >= Tuning.movement.trigger_run
	_command.buttons = InputBits.with(_command.buttons, InputBits.RUN_FULL, full)


## The friction. `SprintGate` owns the rule; toggle mode still has to pay it,
## because a toggle that skipped the double-tap would be an accessibility option
## that removed the design's only deliberate cost.
##
## The gamepad has a second route: full trigger plus traverse, GDD-02 §1.3's
## "L2 full + A". That one is NOT gated, because it is already two simultaneous
## inputs — the pad's version of the same awkwardness. §9.3 requires a
## single-input alternative to exist, and the gated button is it.
func _sample_sprint() -> void:
	var name := InputActions.action_names(Ids.INPUT_SPRINT)[0]
	var pressed := Input.is_action_pressed(name)
	if mode_of(Ids.INPUT_SPRINT) == InputLatch.Mode.TOGGLE:
		pressed = _latch.resolve(Ids.INPUT_SPRINT, pressed, InputLatch.Mode.TOGGLE)
	var open: bool = _sprint.update(pressed) or _pad_sprint_combo()
	_command.buttons = InputBits.with(_command.buttons, InputBits.SPRINT, open)


func _pad_sprint_combo() -> bool:
	if not InputBits.is_set(_command.buttons, InputBits.RUN_FULL):
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
	_sprint.reset()
	_mouse_delta = Vector2.ZERO
