## THE action table. GDD-02 §1.2 (keyboard/mouse) and §1.3 (gamepad).
##
## One row per `INPUT-` ID, declaring what kind of input it is, which
## `InputBits` bit it occupies on the wire (if any), and how many `InputMap`
## actions it needs. Everything that has to agree about the input scheme —
## `project.godot`, the sampler, the rebinder, the wire format — reads this.
##
## PURE. No `InputMap`, no `Input`, no engine. Binding *rules* live here where a
## unit test can exercise them; binding *application* is `InputRebinder`, which
## is the only file that touches the engine's map.
##
## **In `net/protocol/` and not in `core/` on purpose.** The table decides which
## actions become wire bits, so it depends on `InputBits`, which TDD-06 §7 puts
## here. Dependencies point downward only — Core reaching up into Net to read a
## bitfield would invert the one rule the layer split exists to enforce, and it
## would be invisible, because it compiles.
##
## The `InputMap` action name is derived, never stored: `INPUT-ABILITY-1` becomes
## `input_ability_1`, mechanically, in both directions. A lookup table would be a
## place for the ID and the binding to disagree silently — the same reasoning
## that governs `TUN-` (NAMING_AND_IDS §3.1).
class_name InputActions
extends RefCounted

## AXIS resolves to four `InputMap` actions (negative and positive on two axes).
## HOLD is meaningful while held and may be configured as a toggle (§9.3).
## PRESS is edge-triggered and is consumed once.
enum Kind { AXIS, HOLD, PRESS }

## Suffixes an AXIS row expands into, in `Input.get_vector(-x, +x, -y, +y)`
## argument order. Back before forward, so a positive `y` means FORWARD — which
## is what `move` means to the pawn, and getting it backwards would sample a
## controller that walks the player into whatever is behind them.
const AXIS_SUFFIXES: Array[String] = ["_left", "_right", "_back", "_forward"]

## `INPUT-LOOK` is the one axis whose halves are not forward/back. Down before
## up, so a positive `y` means looking UP.
const LOOK_SUFFIXES: Array[String] = ["_left", "_right", "_down", "_up"]

## id -> {kind, bit, toggleable, rebindable}. `bit` is `InputBits.NONE` for an
## action the server never sees (see `InputBits.ALL`).
##
## ORDER IS GDD-02 §1.2's table order, so the two can be read side by side.
const ACTIONS: Dictionary = {
	Ids.INPUT_MOVE:
	{"kind": Kind.AXIS, "bit": InputBits.NONE, "toggleable": false, "rebindable": true},
	Ids.INPUT_LOOK:
	{"kind": Kind.AXIS, "bit": InputBits.NONE, "toggleable": false, "rebindable": true},
	Ids.INPUT_SLOW:
	{"kind": Kind.HOLD, "bit": InputBits.SLOW, "toggleable": true, "rebindable": true},
	Ids.INPUT_RUN:
	{"kind": Kind.HOLD, "bit": InputBits.RUN, "toggleable": true, "rebindable": true},
	Ids.INPUT_SPRINT:
	{"kind": Kind.HOLD, "bit": InputBits.SPRINT, "toggleable": true, "rebindable": true},
	Ids.INPUT_TRAVERSE:
	{"kind": Kind.PRESS, "bit": InputBits.TRAVERSE, "toggleable": false, "rebindable": true},
	Ids.INPUT_KILL:
	{"kind": Kind.PRESS, "bit": InputBits.KILL, "toggleable": false, "rebindable": true},
	Ids.INPUT_STUN:
	{"kind": Kind.PRESS, "bit": InputBits.STUN, "toggleable": false, "rebindable": true},
	Ids.INPUT_BLEND:
	{"kind": Kind.PRESS, "bit": InputBits.BLEND, "toggleable": false, "rebindable": true},
	Ids.INPUT_ABILITY_1:
	{"kind": Kind.PRESS, "bit": InputBits.ABILITY_1, "toggleable": false, "rebindable": true},
	Ids.INPUT_ABILITY_2:
	{"kind": Kind.PRESS, "bit": InputBits.ABILITY_2, "toggleable": false, "rebindable": true},
	Ids.INPUT_SCAN:
	{"kind": Kind.HOLD, "bit": InputBits.SCAN, "toggleable": true, "rebindable": true},
	Ids.INPUT_SHOULDER:
	{"kind": Kind.PRESS, "bit": InputBits.NONE, "toggleable": false, "rebindable": true},
	Ids.INPUT_SCORE:
	# The one action that is never rebindable. A player who has rebound their way
	{"kind": Kind.HOLD, "bit": InputBits.NONE, "toggleable": true, "rebindable": true},
	# out of the pause menu cannot rebind their way back in.
	Ids.INPUT_MENU:
	{"kind": Kind.PRESS, "bit": InputBits.NONE, "toggleable": false, "rebindable": false},
}

## Pairs that may never share a binding, and why. GDD-02 §1.4: a duplicate
## binding is otherwise permitted with a warning.
##
## KILL and STUN are the game's two irreversible buttons and they mean opposite
## things — one commits you to a target, one punishes someone for committing to
## you. Bound together, every stun would also be a kill attempt against whoever
## happened to be in front, and a mis-stun already costs a stagger.
const EXCLUSIVE_PAIRS: Array = [[Ids.INPUT_KILL, Ids.INPUT_STUN]]


static func ids() -> Array:
	return ACTIONS.keys()


static func exists(id: StringName) -> bool:
	return ACTIONS.has(id)


static func kind_of(id: StringName) -> Kind:
	return ACTIONS[id]["kind"]


static func bit_of(id: StringName) -> int:
	return ACTIONS[id]["bit"]


static func is_toggleable(id: StringName) -> bool:
	return ACTIONS[id]["toggleable"]


static func is_rebindable(id: StringName) -> bool:
	return ACTIONS[id]["rebindable"]


## `INPUT-ABILITY-1` -> `input_ability_1`. The transform, in the one direction
## the engine needs it.
static func action_name(id: StringName) -> StringName:
	return StringName(String(id).to_lower().replace("-", "_"))


## `input_ability_1` -> `INPUT-ABILITY-1`. The inverse, so a stray action in
## `project.godot` can be named in a failure message rather than described.
static func id_from_action_name(name: StringName) -> StringName:
	return StringName(String(name).to_upper().replace("_", "-"))


## Every `InputMap` action this ID needs. One for a button, four for an axis.
static func action_names(id: StringName) -> Array[StringName]:
	var base := action_name(id)
	if kind_of(id) != Kind.AXIS:
		var single: Array[StringName] = [base]
		return single
	var suffixes := LOOK_SUFFIXES if id == Ids.INPUT_LOOK else AXIS_SUFFIXES
	var out: Array[StringName] = []
	for suffix: String in suffixes:
		out.append(StringName(String(base) + suffix))
	return out


## Every `InputMap` action the game declares, in table order.
static func all_action_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ACTIONS:
		out.append_array(action_names(id))
	return out


## Actions carried in the `InputCommand.buttons` bitfield, in wire order.
static func wire_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ACTIONS:
		if bit_of(id) != InputBits.NONE:
			out.append(id)
	return out


## The IDs a proposed binding would collide with, given who else holds it.
##
## `holders` is action id -> the binding it currently has, in whatever opaque
## form the caller uses; equality is all this needs. Returns the ids that may
## NOT share with `id` — empty means the rebind is allowed, possibly with the
## warning GDD-02 §1.4 permits.
static func forbidden_conflicts(id: StringName, binding: Variant, holders: Dictionary) -> Array:
	var out: Array = []
	for pair: Array in EXCLUSIVE_PAIRS:
		if not pair.has(id):
			continue
		for other: StringName in pair:
			if other != id and holders.get(other) == binding:
				out.append(other)
	return out


## Whether a rebind may proceed. The UI calls this and refuses, rather than
## applying and warning (GDD-02 §1.4).
static func may_bind(id: StringName, binding: Variant, holders: Dictionary) -> bool:
	if not is_rebindable(id):
		return false
	return forbidden_conflicts(id, binding, holders).is_empty()
