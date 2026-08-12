## Which connected device is allowed to drive the gamepad bindings. GDD-02 §1.3.
##
## **WRITTEN BECAUSE A SET OF SIM PEDALS PLAYED THE GAME.** Windows presents any
## HID device with axes as a joypad, and `project.godot` binds the sticks with
## `device: -1`, which means *every* device. A pair of Thrustmaster pedals
## enumerates as joypad 0 with its axes resting at −1.0, so axes 0, 1 and 2 sat
## at full deflection forever: `input_move_left`, `input_move_forward` and
## `input_look_left` all read 1.00 with nobody in the room. The pawn walked
## forward-left at stroll and the camera turned left without stopping.
##
## **A DEADZONE CANNOT FIX THIS.** `TUN-SPEED-STICK-DEADZONE` is 0.15 and exists
## to reject *drift*, a small nonzero. This is a full-scale reading from a device
## that is working perfectly and is not a gamepad. Raising the deadzone to reject
## it would have to reject 1.0, which rejects the whole stick.
##
## So the filter is by DEVICE, not by magnitude: only a device the engine has a
## gamepad mapping for may drive the bindings, and only one of them at a time.
## Everything else — pedals, wheels, flight sticks, dance mats — is ignored,
## which is the honest reading of an unmapped device: it is not a gamepad.
##
## PURE. The policy is arithmetic on a list of descriptions, so it is unit-tested
## without an engine; applying it to the `InputMap` is `InputRebinder`.
class_name PadSelection
extends RefCounted

## A device id that matches no event. `InputMap` treats −1 as "any device" and
## every real joypad id is ≥ 0, so −2 can never match.
##
## **VERIFIED AGAINST THE ENGINE, NOT ASSUMED.** Whether `InputMap` compares the
## device at all is the entire load-bearing claim here, and it was measured with
## the pedals attached before this file was written: with the joypad events moved
## to −2 before boot, the three stuck actions read 0.00 while `get_joy_axis` went
## on reporting −1.00. The device is still there; it no longer reaches an action.
const NO_DEVICE := -2


## The device the gamepad bindings should be restricted to, or `NO_DEVICE`.
##
## Each entry is `{"id": int, "known": bool, "name": String}` — `known` being
## whether the engine has a gamepad mapping for it (`Input.is_joy_known`).
##
## **THE LOWEST KNOWN ID WINS**, which is the first pad the player plugged in.
## Hot-swapping between two real pads is GDD-02 §1.3's "hot-swap on input
## detected" and belongs to the options screen (US-0079); this is the boot
## default, and it is deliberately not clever.
static func chosen(pads: Array[Dictionary]) -> int:
	var best := NO_DEVICE
	for pad: Dictionary in pads:
		if not bool(pad.get("known", false)):
			continue
		var id := int(pad.get("id", NO_DEVICE))
		if id < 0:
			continue
		if best == NO_DEVICE or id < best:
			best = id
	return best


## Every device this policy refuses, so the boot log can name them.
static func ignored(pads: Array[Dictionary]) -> Array[Dictionary]:
	var winner := chosen(pads)
	var out: Array[Dictionary] = []
	for pad: Dictionary in pads:
		if int(pad.get("id", NO_DEVICE)) != winner:
			out.append(pad)
	return out


## One line for the boot log.
##
## **IT NAMES WHAT IT IGNORED.** The pedals cost an evening precisely because
## nothing anywhere said a device was steering; a player whose camera spins
## should find the answer in the first ten lines of their log rather than in a
## week of guessing at the deadzone.
static func describe(pads: Array[Dictionary]) -> String:
	var winner := chosen(pads)
	var text := "gamepad: no mapped pad, joypad bindings disabled"
	if winner != NO_DEVICE:
		text = "gamepad: device %d (%s)" % [winner, _name_of(pads, winner)]
	var refused := ignored(pads)
	if refused.is_empty():
		return text
	var names: Array[String] = []
	for pad: Dictionary in refused:
		names.append("[%d] %s" % [int(pad.get("id", -1)), String(pad.get("name", "?"))])
	return "%s; IGNORING %s" % [text, ", ".join(names)]


static func _name_of(pads: Array[Dictionary], id: int) -> String:
	for pad: Dictionary in pads:
		if int(pad.get("id", NO_DEVICE)) == id:
			return String(pad.get("name", "?"))
	return "?"
