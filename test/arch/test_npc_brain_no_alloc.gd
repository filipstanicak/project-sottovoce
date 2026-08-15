## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **`NpcBrain.step()` ALLOCATES NOTHING.** US-0040, TDD-08 §3.
##
## Ninety agents at 30 Hz is 2 700 calls a second. An `Array` or `Dictionary`
## constructed in any of them is 2 700 allocations a second handed to the garbage
## collector, and `TUN-PERF-CROWD-BUDGET` is **2.0 ms for the entire crowd** —
## AI, navigation and animation LOD together. TDD-08 §3 puts the rule in a comment
## on the class; this is what makes it true.
##
## **SCANNED, NOT MEASURED.** A runtime memory probe is the obvious approach and
## the wrong one: GDScript's static memory moves for reasons that have nothing to
## do with this file, so the test would be flaky, and a flaky test gets a wider
## threshold until it means nothing. The construction syntax is what the rule is
## actually about, and it is exactly what a scan can see.
##
## The transition table is a `const`, so it is built once at parse time — the
## machine allocates by construction rather than by discipline, which is why this
## guard can be this strict.
extends GutTest

const BRAIN := "res://scripts/systems/crowd/npc_brain.gd"

## Functions reachable from `step()` on the hot path. A call `step()` makes is
## `step()`'s cost, so scanning only `step()` itself would let an allocation hide
## one frame deeper.
const HOT_PATH: Array[String] = [
	"func step(", "func handle(", "func _enter(", "func _duration_ticks("
]

## Constructions that allocate. `[` and `{` alone would match indexing and
## dictionary *lookups*, which are free — the needles are the forms that build.
const ALLOCATING: Array[String] = ["[]", "{}", ".new(", ".duplicate(", "Array(", "Dictionary("]


## The body of `name`, from its declaration to the next top-level `func`.
func _body_of(source: String, name: String) -> String:
	var at := source.find(name)
	if at < 0:
		return ""
	var next := source.find("\nfunc ", at + name.length())
	return source.substr(at, (next - at) if next > at else source.length() - at)


func test_the_brain_was_actually_read() -> void:
	# Guards the guard. A renamed or moved file reads as an empty string, and an
	# empty string contains no allocations at all — trap 3's family, which this
	# project has hit five times.
	var source := SourceScanner.read(BRAIN)
	assert_gt(source.length(), 1000, "npc_brain.gd is missing or unexpectedly small")
	for name: String in HOT_PATH:
		assert_ne(_body_of(source, name), "", "%s is gone — the scan covers nothing" % name)


func test_nothing_on_the_hot_path_allocates() -> void:
	# **THE ASSERTION THE FILE IS FOR.**
	var source := SourceScanner.read(BRAIN)
	var offenders: PackedStringArray = []
	for name: String in HOT_PATH:
		var body := _body_of(source, name)
		for needle: String in ALLOCATING:
			if body.contains(needle):
				offenders.append("%s constructs %s" % [name, needle])

	assert_eq(
		offenders.size(),
		0,
		(
			"NpcBrain's hot path allocates.\n"
			+ "Ninety agents at 30 Hz is 2 700 calls a second, against a 2.0 ms\n"
			+ "budget for the whole crowd. TDD-08 §3.\n"
			+ "\n".join(offenders)
		)
	)


func test_the_transition_table_is_a_const() -> void:
	# If it became a `var` built in `_init`, every brain would carry its own copy
	# of a 35-entry nested dictionary — ninety of them, for a table that never
	# changes. The scan above would still pass, because the construction would
	# not be on the hot path.
	assert_true(
		SourceScanner.code_contains(BRAIN, "const TRANSITIONS"),
		"TRANSITIONS is no longer a const — every brain now owns a copy"
	)


func test_the_check_can_actually_fail() -> void:
	# Falsification: the scan must see a planted construction in a body it covers.
	var planted := "func step(ctx, dt):\n\tvar scratch := []\n\treturn scratch\n"
	var body := _body_of(planted, "func step(")
	assert_ne(body, "", "the body extractor found nothing in a planted function")
	assert_true(body.contains("[]"), "the scan would not see a planted allocation")
