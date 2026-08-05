## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## NO `PawnState` SUBCLASS DECLARES PER-PAWN DATA.
##
## One instance of each state is shared by every pawn on the server. A `var` on
## a state is therefore shared by every pawn on the server, and the symptom is
## one player's vault ending another player's climb — at low frequency, under
## load, on the server only.
##
## Why review misses this: `var _elapsed := 0.0` inside a state is the most
## natural thing in the world to write. It reads as local bookkeeping. Nothing
## about the line says "this is global across all players", and single-player
## testing will never reveal it.
##
## Per-pawn data belongs in `PawnContext`, which is passed in.
extends GutTest

const PAWN_DIR := "res://scripts/pawn"

## `const` is fine — it is immutable and shared by design. `signal` is fine.
## Anything else at class scope is not.
const ALLOWED_PREFIXES: Array[String] = ["const ", "signal ", "enum ", "class_name ", "extends "]

## The root of the inheritance chain that makes a file a shared state object.
const STATE_ROOT := "PawnState"


## Every file under scripts/pawn/ whose class reaches `PawnState` by `extends`.
##
## DERIVED, not listed. This used to be a blacklist of the files that were not
## states, which meant every new non-state file under scripts/pawn/ —
## `pawn_input_buffer.gd` in US-0016, `traversal/` in US-0017 — failed the guard
## until someone added a name to it. A list that has to grow to keep a guard
## quiet is a list that eventually gets a state added to it by mistake.
##
## `TraversalProbes` is the clarifying case: it holds a reused query object and
## that is correct, because it is a node in the pawn scene and there is one per
## pawn. The sharing hazard is specific to `PawnState`, whose instances are
## registered once and used by every pawn on the server.
func _state_files() -> PackedStringArray:
	var parents: Dictionary = {}
	var by_class: Dictionary = {}
	for path: String in SourceScanner.gd_files(PAWN_DIR):
		var declared := _declared_class(path)
		if declared == "":
			continue
		by_class[declared] = path
		parents[declared] = _extends_of(path)

	var out: PackedStringArray = []
	for declared: String in by_class:
		if declared != STATE_ROOT and _reaches_state_root(declared, parents):
			out.append(by_class[declared])
	out.sort()
	return out


func _reaches_state_root(declared: String, parents: Dictionary) -> bool:
	var seen: Dictionary = {}
	var current: String = parents.get(declared, "")
	while current != "" and not seen.has(current):
		if current == STATE_ROOT:
			return true
		seen[current] = true
		current = parents.get(current, "")
	return false


func _declared_class(path: String) -> String:
	return _first_token(path, "class_name ")


func _extends_of(path: String) -> String:
	return _first_token(path, "extends ")


func _first_token(path: String, prefix: String) -> String:
	for pair: Array in SourceScanner.code_lines(path):
		var line := String(pair[1]).strip_edges()
		if line.begins_with(prefix):
			return line.substr(prefix.length()).strip_edges().split(" ")[0]
	return ""


func test_no_state_declares_a_variable() -> void:
	var offenders: PackedStringArray = []
	for path: String in _state_files():
		for pair: Array in SourceScanner.code_lines(path):
			var line: String = String(pair[1])
			# Class scope only: an indented `var` is a local inside a function.
			if line.begins_with("var ") or line.begins_with("@export"):
				offenders.append("%s:%d %s" % [path, pair[0], line.strip_edges()])
	offenders.sort()
	assert_eq(
		offenders.size(),
		0,
		(
			"A PawnState declared per-pawn data.\n"
			+ "One instance is shared by EVERY pawn on the server — this value would be too.\n"
			+ "Put it in PawnContext, which is passed into step().\n"
			+ "\n".join(offenders)
		)
	)


func test_the_base_class_itself_holds_no_data() -> void:
	var offenders: PackedStringArray = []
	for pair: Array in SourceScanner.code_lines("res://scripts/pawn/pawn_state.gd"):
		var line: String = String(pair[1])
		if line.begins_with("var ") or line.begins_with("@export"):
			offenders.append("pawn_state.gd:%d %s" % [pair[0], line.strip_edges()])
	assert_eq(offenders.size(), 0, "PawnState base class holds data.\n" + "\n".join(offenders))


func test_the_scan_is_looking_at_real_files() -> void:
	# Guards the guard: an empty file list makes both checks above vacuous. The
	# second number is the one that matters now that membership is derived — nine
	# states are implemented plus `LocomotionState`, and a chain that stopped
	# resolving would silently scan none of them.
	assert_gt(SourceScanner.gd_files(PAWN_DIR).size(), 3, "scripts/pawn/ scan found almost nothing")
	assert_gt(
		_state_files().size(),
		8,
		"the extends chain stopped resolving — no PawnState subclass is being scanned"
	)


func test_the_derivation_excludes_what_is_not_a_state() -> void:
	# The other direction. A per-pawn node like `TraversalProbes` MAY hold data,
	# and sweeping it in would push its reused query object into `PawnContext`,
	# where it does not belong.
	var scanned: Dictionary = {}
	for path: String in _state_files():
		scanned[path.get_file()] = true
	for base: String in ["pawn_context.gd", "traversal_probes.gd", "probe_result.gd"]:
		assert_false(scanned.has(base), "%s is not a PawnState and must not be scanned" % base)
	assert_true(scanned.has("sprint_state.gd"), "a real state fell out of the scan")
	assert_true(scanned.has("locomotion_state.gd"), "the shared base fell out of the scan")


func test_the_context_is_not_a_node() -> void:
	# The whole reason step() is unit-testable. A PawnContext that extended Node
	# would drag a scene tree into every pawn test and quietly end that.
	var text := SourceScanner.read("res://scripts/pawn/pawn_context.gd")
	assert_true(text.contains("extends RefCounted"), "PawnContext must extend RefCounted")
	assert_false(text.contains("extends Node"), "PawnContext must not be a Node (TDD-06 §1.1)")
