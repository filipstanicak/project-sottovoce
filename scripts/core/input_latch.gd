## Hold-versus-toggle for every holdable action. GDD-02 §9.3.
##
## **EVERYTHING HOLDABLE IS TOGGLEABLE** (§1.1 principle 4), individually. This
## is an accessibility provision with no competitive dimension whatsoever: it
## changes how a player asks for a state, never which states exist or what they
## cost. `INPUT-SLOW` in toggle mode blend-walks exactly as fast, and accrues
## exactly as little suspicion, as `INPUT-SLOW` held down.
##
## PURE and tick-free. A latch flips on the rising edge, which is all the
## information there is; nothing here needs a clock.
##
## Instance state, one per player, held by the sampler. Not static: two local
## players (a future split-screen, or the playtest tool driving three clients in
## one process) must not share a latch.
class_name InputLatch
extends RefCounted

enum Mode {
	HOLD,  ## Active while physically held. The default everywhere.
	TOGGLE,  ## Flips on each press and stays. The pad default for INPUT-SLOW.
}

## id -> bool. Only meaningful for actions currently in TOGGLE mode.
var _latched: Dictionary = {}

## id -> bool. Last physical state, for edge detection.
var _held: Dictionary = {}


## Resolve one action for this frame. `pressed` is the raw physical state.
##
## Returns whether the action should count as active. In HOLD mode that is
## `pressed`; in TOGGLE mode it is the latch, flipped by this frame's rising
## edge.
func resolve(id: StringName, pressed: bool, mode: Mode) -> bool:
	var rising: bool = pressed and not _held.get(id, false)
	_held[id] = pressed

	if mode == Mode.HOLD:
		# Leaving the latch untouched, so switching modes mid-match does not
		# resurrect a toggle the player set minutes ago.
		_latched[id] = false
		return pressed

	if rising:
		_latched[id] = not _latched.get(id, false)
	return _latched.get(id, false)


## Whether the action is latched on right now. For the HUD, which has to show a
## toggled blend-walk differently from a held one or the player cannot tell why
## they are still walking.
func is_latched(id: StringName) -> bool:
	return _latched.get(id, false)


## Force an action off. Called when a state change makes the latch a lie — a
## respawn, or entering a state that cannot honour it — because a toggle that
## survives a death would have the player blend-walking out of their own spawn
## without having asked to.
func release(id: StringName) -> void:
	_latched[id] = false
	_held[id] = false


func release_all() -> void:
	_latched.clear()
	_held.clear()
