## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## THERE ARE EXACTLY EIGHT AUTOLOADS. Adding a ninth requires an ADR.
##
## Why review misses this: every addition is individually defensible. A
## MatchManager is obviously useful. So is a PlayerRegistry, a ScoreManager, a
## Utils. Each one is a global that any file may reach for without declaring a
## dependency, and the cost is collective — after five of them nothing can be
## unit-tested without booting the whole game, and no one can say which
## addition was the mistake.
##
## TDD-01 §2.1 records the four that were explicitly rejected. Read it before
## proposing any of them again.
extends GutTest

const EXPECTED: Array[String] = [
	"Tuning",
	"EventBus",
	"Net",
	"GameState",
	"Log",
	"Strings",
	"Audio",
	"DebugConsole",
]

## Rejected by name in TDD-01 §2.1. Listed so the failure message says WHY
## rather than only that the count changed.
const REJECTED: Array[String] = ["MatchManager", "PlayerRegistry", "ScoreManager", "Utils"]

const PROJECT := "res://project.godot"


func _declared() -> PackedStringArray:
	var out: PackedStringArray = []
	var in_section := false
	for raw: String in SourceScanner.read(PROJECT).split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("["):
			in_section = line == "[autoload]"
			continue
		if not in_section or line == "" or line.begins_with(";"):
			continue
		if line.contains("="):
			out.append(line.split("=")[0].strip_edges())
	return out


func test_the_scan_found_the_autoload_section() -> void:
	# Guards the guard. If project.godot's format changed, an empty scan would
	# make every assertion below pass over nothing.
	assert_gt(_declared().size(), 0, "no autoloads found — the project.godot scan is broken")


func test_there_are_exactly_eight() -> void:
	var declared := _declared()
	assert_eq(
		declared.size(),
		EXPECTED.size(),
		(
			"The autoload count changed. There are eight; a ninth needs an ADR.\n"
			+ "Declared: %s" % String(", ").join(declared)
		)
	)


func test_they_are_exactly_the_eight_named() -> void:
	var declared := _declared()
	var missing: PackedStringArray = []
	var unexpected: PackedStringArray = []
	for name: String in EXPECTED:
		if not declared.has(name):
			missing.append(name)
	for name: String in declared:
		if not EXPECTED.has(name):
			unexpected.append(name)

	var problems: PackedStringArray = []
	if not missing.is_empty():
		problems.append("MISSING: " + String(", ").join(missing))
	for name: String in unexpected:
		if REJECTED.has(name):
			problems.append("%s was explicitly REJECTED as an autoload — TDD-01 §2.1" % name)
		else:
			problems.append("UNEXPECTED: %s — adding an autoload requires an ADR" % name)

	assert_eq(problems.size(), 0, "The autoload inventory changed.\n" + "\n".join(problems))


func test_the_debug_console_is_strippable() -> void:
	# It must live under scripts/debug/, which every export preset excludes. An
	# autoload the release build cannot strip is a debug tool in players' hands.
	var text := SourceScanner.read(PROJECT)
	var idx := text.find("DebugConsole=")
	assert_gt(idx, -1, "DebugConsole autoload is missing")
	assert_true(
		text.substr(idx, 120).contains("res://scripts/debug/"),
		"DebugConsole must live under scripts/debug/ so the export filter removes it"
	)
