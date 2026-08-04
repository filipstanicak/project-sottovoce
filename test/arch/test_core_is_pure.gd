## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## Core is pure: no Node, no scene tree, no autoloads. That is what makes the
## highest-risk logic in the project — the contract cycle, the suspicion
## integrator, the score fold, the compass curve — testable in milliseconds
## with no engine.
##
## Why review misses this: nothing fails when Core gains a get_node() call.
## The tests keep passing. They just get slower and start needing a scene,
## and one day nobody writes them any more.
extends GutTest

const BANNED: Array[String] = [
	"get_node(",
	"get_tree(",
	"Engine.",
	"EventBus",
	"Net.",
	"GameState",
	"Audio.",
	"DebugConsole",
]

## Tuning is the ONE permitted autoload in Core: ADR-0005 requires every
## gameplay constant to be read from it, and threading a TuningProfile through
## every constructor would be worse.
const PERMITTED_AUTOLOAD := "Tuning"


func test_core_extends_nothing_from_the_scene_tree() -> void:
	var violations: PackedStringArray = []
	for path: String in SourceScanner.gd_files("res://scripts/core"):
		var text := SourceScanner.read(path)
		for line in text.split("\n"):
			var t := line.strip_edges()
			if t.begins_with("extends Node") or t == "extends Node":
				violations.append(path)
	assert_eq(
		violations.size(),
		0,
		(
			"A Core file extends Node. Core must be constructible with no scene.\n"
			+ "\n".join(violations)
		)
	)


func test_core_has_no_engine_or_autoload_access() -> void:
	var violations: PackedStringArray = []
	for path: String in SourceScanner.gd_files("res://scripts/core"):
		# tuning.gd IS the Tuning autoload; it is the seam and is exempt.
		if path.ends_with("tuning/tuning.gd"):
			continue
		for banned: String in BANNED:
			for hit: String in SourceScanner.find(path, banned):
				violations.append("%s uses %s" % [hit, banned])
	assert_eq(
		violations.size(),
		0,
		(
			"Core reached into the engine or an autoload other than %s.\n%s"
			% [PERMITTED_AUTOLOAD, "\n".join(violations)]
		)
	)
