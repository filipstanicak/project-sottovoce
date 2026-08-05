## The action table agrees with `Ids`, which agrees with GDD-02 §1.2 and §1.3.
##
## `Ids` is generated from the corpus and asserted against it by
## `test_ids_match_glossary.gd`, so this file closes the last link: every
## documented input action has a row, and every row is a documented action. The
## chain runs GDD-02 -> Ids -> InputActions -> project.godot, and every hop is
## checked by something.
##
## Until US-0016 that chain did not exist at all. `INPUT-` was not a registered
## namespace, so fifteen IDs that read as IDs everywhere they appeared were,
## mechanically, prose.
extends GutTest


## Every `INPUT-` constant `Ids` declares. `Ids` itself is generated from the
## corpus, so this is GDD-02 §1.2 and §1.3 arriving by a route that cannot drift.
func _documented_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var constants: Dictionary = IdScanner.id_constants()
	for name: String in constants:
		if name.begins_with("INPUT_"):
			out.append(constants[name])
	return out


func test_the_corpus_actually_yielded_actions() -> void:
	# Guards the guard. If the harvest ever returned nothing, every comparison
	# below would pass over an empty set and report success.
	assert_gt(_documented_ids().size(), 10, "no INPUT- ids were harvested from the corpus")


func test_every_documented_action_has_a_row() -> void:
	var missing: PackedStringArray = []
	for id: StringName in _documented_ids():
		if not InputActions.exists(id):
			missing.append(String(id))
	missing.sort()
	assert_eq(
		missing.size(),
		0,
		(
			"GDD-02 names an input action InputActions has no row for.\n"
			+ "Add the row, or the action is bindable nowhere.\n"
			+ "\n".join(missing)
		)
	)


func test_every_row_is_a_documented_action() -> void:
	# The more dangerous direction: a row for an action nobody designed would be
	# bound in project.godot and reachable in play.
	var known: Dictionary = {}
	for id: StringName in _documented_ids():
		known[id] = true

	var strays: PackedStringArray = []
	for id: StringName in InputActions.ids():
		if not known.has(id):
			strays.append(String(id))
	strays.sort()
	assert_eq(strays.size(), 0, "InputActions invents an action: " + ", ".join(strays))


func test_the_action_name_transform_is_reversible() -> void:
	# A lookup table between an ID and its InputMap name would be a place for the
	# two to disagree silently. The transform is mechanical in both directions,
	# for the same reason TUN- ids map mechanically to fields.
	var wrong: PackedStringArray = []
	for id: StringName in InputActions.ids():
		var name := InputActions.action_name(id)
		if InputActions.id_from_action_name(name) != id:
			wrong.append("%s -> %s -> %s" % [id, name, InputActions.id_from_action_name(name)])
	assert_eq(wrong.size(), 0, "\n".join(wrong))
	assert_eq(InputActions.action_name(Ids.INPUT_ABILITY_1), &"input_ability_1")


func test_an_axis_expands_to_four_bindings_and_a_button_to_one() -> void:
	assert_eq(InputActions.action_names(Ids.INPUT_MOVE).size(), 4)
	assert_eq(InputActions.action_names(Ids.INPUT_LOOK).size(), 4)
	assert_eq(InputActions.action_names(Ids.INPUT_SLOW).size(), 1)


func test_forward_is_positive_y() -> void:
	# `Input.get_vector(-x, +x, -y, +y)`. Back must come before forward or the
	# controller walks the player into whatever is behind them, and the pawn's
	# own backpedal multiplier would then apply to walking forwards.
	var names := InputActions.action_names(Ids.INPUT_MOVE)
	assert_eq(names[2], &"input_move_back", "the -y binding is not 'back'")
	assert_eq(names[3], &"input_move_forward", "the +y binding is not 'forward'")


func test_only_actions_the_server_simulates_reach_the_wire() -> void:
	# Every bit is bandwidth spent 60 times a second per client, forever. The
	# camera, the scoreboard and the pause menu change nothing the server rules on.
	for id: StringName in [Ids.INPUT_SHOULDER, Ids.INPUT_SCORE, Ids.INPUT_MENU]:
		assert_eq(InputActions.bit_of(id), InputBits.NONE, "%s should not be on the wire" % id)
	for id: StringName in [Ids.INPUT_SLOW, Ids.INPUT_KILL, Ids.INPUT_STUN]:
		assert_ne(InputActions.bit_of(id), InputBits.NONE, "%s must reach the server" % id)


func test_no_two_actions_claim_the_same_bit() -> void:
	var seen: Dictionary = {}
	for id: StringName in InputActions.wire_ids():
		var bit := InputActions.bit_of(id)
		assert_false(seen.has(bit), "%s and %s share bit %d" % [id, seen.get(bit, ""), bit])
		seen[bit] = id


func test_kill_and_stun_may_never_share_a_binding() -> void:
	# THE ONE FORBIDDEN COLLISION (GDD-02 §1.4). They are the game's two
	# irreversible buttons and they mean opposite things — one commits you to a
	# target, one punishes someone for committing to you. Bound together, every
	# stun would also be a kill attempt against whoever was in front.
	var holders := {Ids.INPUT_STUN: "Left Mouse Button"}
	assert_false(
		InputActions.may_bind(Ids.INPUT_KILL, "Left Mouse Button", holders),
		"kill was allowed onto stun's binding"
	)
	assert_eq(
		InputActions.forbidden_conflicts(Ids.INPUT_KILL, "Left Mouse Button", holders),
		[Ids.INPUT_STUN]
	)


func test_the_refusal_is_symmetric() -> void:
	var holders := {Ids.INPUT_KILL: "Right Mouse Button"}
	assert_false(InputActions.may_bind(Ids.INPUT_STUN, "Right Mouse Button", holders))


func test_any_other_duplicate_is_permitted() -> void:
	# GDD-02 §1.4 allows duplicates with a warning everywhere else. Traverse and
	# the gamepad sprint genuinely share a button by design (§1.3).
	var holders := {Ids.INPUT_TRAVERSE: "Joypad Button 0"}
	assert_true(InputActions.may_bind(Ids.INPUT_SPRINT, "Joypad Button 0", holders))


func test_the_pause_menu_can_never_be_rebound() -> void:
	# A player who rebinds their way out of the pause menu cannot rebind their way
	# back in. Every other action is rebindable (GDD-02 §1.4).
	assert_false(InputActions.is_rebindable(Ids.INPUT_MENU))
	assert_false(InputActions.may_bind(Ids.INPUT_MENU, "F1", {}))
	var stuck: PackedStringArray = []
	for id: StringName in InputActions.ids():
		if id != Ids.INPUT_MENU and not InputActions.is_rebindable(id):
			stuck.append(String(id))
	assert_eq(stuck.size(), 0, "these should be rebindable: " + ", ".join(stuck))
