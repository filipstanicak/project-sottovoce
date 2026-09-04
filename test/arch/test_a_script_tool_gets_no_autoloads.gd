## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **A `-s` SCRIPT IS COMPILED BEFORE THE AUTOLOADS ARE REGISTERED**, so `Tuning`
## is an unresolvable identifier in it — and ADR-0005 makes `Tuning` the **one
## permitted autoload in Core** (`test_core_is_pure.gd` says why), read by sixteen
## Core classes. Every one of them then fails to compile, along with everything
## depending on them, and **GDScript caches that failure**: they stay broken for the
## rest of the process even once the autoloads exist.
##
## **WHY REVIEW MISSES THIS: THE FAILURE SURFACES FOUR FILES FROM ITS CAUSE.** What
## you get is a runtime *"Nonexistent function X in base 'GDScript'"* naming a class
## that is perfectly correct, with nothing in the message about the launch mode. It
## cost `generate_default_tuning` **invariant 33** from M0 until 2026-09-05 — the
## tool printed the error twice on every run and it was read as noise, including in
## this corpus, which recorded the wrong cause for it.
##
## The fix is always the same and this project has now made it twice: **a `.tscn`
## rather than a `-s` script.** `tools/anchor_census.gd` was the first.
##
## **THE MAP GENERATORS ARE `-s` AND MUST STAY PASSING**, rather than being
## exempted: `VetraioLayout`, `SandboxLayout` and `MapBuild` read no autoload at
## all, so the property holds for them and an allowlist would hide the day it stops.
extends GutTest

## The one autoload Core may read, and therefore the one that makes a Core class
## uncompilable under `-s`. Any other autoload in a tool is a different problem and
## `test_core_is_pure.gd` owns it.
const AUTOLOAD := "Tuning"

## **MATCHED AS A WHOLE IDENTIFIER, BECAUSE `Tuning.` ALSO MATCHES
## `MovementTuning.new()`** and every other line in the tuning layer. That is a real
## fix and it moved the count by **one file of 211** — which is the point worth
## keeping: **I changed it believing it was the cause of a false positive, and it
## was not.** 92 of 211 classes really do call this autoload; ADR-0005 makes it the
## way every constant in the game is read, so two in five files is the expected
## shape rather than a broken needle. **The hit I was explaining away was true.**
const AUTOLOAD_CALL := "(?<![A-Za-z0-9_])Tuning[ \\t]*\\."

## `tuning.gd` IS the autoload; it is the seam, exempt for the same reason the
## purity guard exempts it.
const IS_THE_AUTOLOAD := "tuning/tuning.gd"

var _by_class: Dictionary = {}
var _reads_autoload: Dictionary = {}


func before_all() -> void:
	for path: String in SourceScanner.gd_files("res://scripts"):
		var declared := _class_name_of(path)
		if declared != "":
			_by_class[declared] = path
		_reads_autoload[path] = (not path.ends_with(IS_THE_AUTOLOAD) and _calls_the_autoload(path))


func test_no_script_tool_reaches_a_class_that_reads_an_autoload() -> void:
	var tools := _script_tools()
	assert_gt(tools.size(), 0, "no `-s` tool was found — this guard would prove nothing")

	var offenders: PackedStringArray = []
	for tool_path: String in tools:
		var chain := _first_autoload_reader(tool_path)
		if not chain.is_empty():
			offenders.append("%s -> %s" % [tool_path, " -> ".join(chain)])
	assert_eq(
		offenders.size(),
		0,
		(
			(
				"A `-s` script reaches a class that reads the %s autoload.\n"
				% AUTOLOAD.trim_suffix(".")
			)
			+ "That class cannot compile under `-s` and every static function on it\n"
			+ "goes missing for the whole process. Make the tool a .tscn instead.\n"
			+ "\n".join(offenders)
		)
	)


func test_the_premise_holds() -> void:
	# Both halves would make the sweep above vacuous: no class map, or nothing
	# that reads the autoload at all.
	assert_gt(_by_class.size(), 50, "the class_name map is too small to be real")
	var readers := 0
	for path: String in _reads_autoload:
		if _reads_autoload[path]:
			readers += 1
	gut.p("%d classes, %d of them call %s" % [_by_class.size(), readers, AUTOLOAD])
	assert_gt(readers, 10, "almost nothing calls the autoload — the scan is broken")
	# **NO UPPER BOUND HERE, AND THE FIRST VERSION HAD ONE.** It asserted fewer than a
	# third of classes call the autoload, on my assumption that a large set meant a
	# bad needle. Measured instead of assumed: **94 of 225 files under `scripts/`**
	# call it on a plain word-boundary grep. ADR-0005 makes `Tuning` the way every
	# gameplay constant is read, so a large set is the design working. The assertion
	# was a guess about the codebase wearing a guard's clothes, and it went red on
	# correct code.


## True if this file calls the autoload rather than merely naming a class that ends
## in "Tuning". Comments and string literals are already gone from `code_lines`.
func _calls_the_autoload(path: String) -> bool:
	var call := RegEx.create_from_string(AUTOLOAD_CALL)
	for pair: Array in SourceScanner.code_lines(path):
		if call.search(String(pair[1])) != null:
			return true
	return false


## The chain from `start` to the first class that reads the autoload, or empty.
## Breadth-first so the shortest explanation is the one reported.
func _first_autoload_reader(start: String) -> PackedStringArray:
	var seen := {start: true}
	var queue: Array = [[start, PackedStringArray()]]
	while not queue.is_empty():
		var here: Array = queue.pop_front()
		for token: String in _classes_named_in(String(here[0])):
			var path: String = _by_class[token]
			if seen.has(path):
				continue
			seen[path] = true
			var chain := PackedStringArray(here[1])
			chain.append(token)
			if _reads_autoload.get(path, false):
				return chain
			queue.append([path, chain])
	return PackedStringArray()


## Every declared `class_name` this file names in code — comments and string
## literals excluded, and matched as whole identifiers so `MapData` does not
## match inside `MapDataBuilder`.
func _classes_named_in(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var word := RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*")
	for pair: Array in SourceScanner.code_lines(path):
		for m: RegExMatch in word.search_all(String(pair[1])):
			var token := m.get_string()
			if _by_class.has(token) and not out.has(token):
				out.append(token)
	return out


func _script_tools() -> PackedStringArray:
	var out: PackedStringArray = []
	for path: String in SourceScanner.gd_files("res://tools"):
		if SourceScanner.code_contains(path, "extends SceneTree"):
			out.append(path)
	return out


func _class_name_of(path: String) -> String:
	for pair: Array in SourceScanner.code_lines(path):
		var line := String(pair[1]).strip_edges()
		if line.begins_with("class_name "):
			return line.substr("class_name ".length()).split(" ")[0].strip_edges()
	return ""
