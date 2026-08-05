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

## Files in scripts/pawn/ that are NOT states and may hold data: the context is
## per-pawn data by definition, and the machine owns the shared registry.
const NOT_A_STATE: Array[String] = [
	"pawn_context.gd",
	"pawn_state_machine.gd",
	"input_command.gd",
	"probe_result.gd",
	"pawn_state_id.gd",
]


func _state_files() -> PackedStringArray:
	var out: PackedStringArray = []
	for path: String in SourceScanner.gd_files(PAWN_DIR):
		var base := path.get_file()
		if NOT_A_STATE.has(base):
			continue
		out.append(path)
	return out


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
	# Guards the guard: an empty file list makes both checks above vacuous.
	assert_gt(SourceScanner.gd_files(PAWN_DIR).size(), 3, "scripts/pawn/ scan found almost nothing")


func test_the_context_is_not_a_node() -> void:
	# The whole reason step() is unit-testable. A PawnContext that extended Node
	# would drag a scene tree into every pawn test and quietly end that.
	var text := SourceScanner.read("res://scripts/pawn/pawn_context.gd")
	assert_true(text.contains("extends RefCounted"), "PawnContext must extend RefCounted")
	assert_false(text.contains("extends Node"), "PawnContext must not be a Node (TDD-06 §1.1)")
