## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **`SpatialHash.rebuild()` AND THE THREE COUNTING QUERIES ALLOCATE NOTHING.**
## US-0042, TDD-08 §6.
##
## The hash is rebuilt once a tick from ninety entries and then read six times
## over by suspicion and six more by blend validation — every tick, for eight
## minutes. The obvious implementation is a `Dictionary` of per-cell arrays, and
## it allocates on every single one of those: a few hundred small objects a
## second handed to the collector, against `TUN-PERF-CROWD-BUDGET` **2.0 ms for
## the entire crowd**. The structure here is a counting sort over buffers sized
## once in `setup()`, which is what makes the rule checkable by reading.
##
## `query()` is deliberately **not** on the list. It returns a list, so it builds
## one; the point of the other three existing at all is that the hot consumers do
## not need it.
##
## **SCANNED, NOT MEASURED**, for the same reason as `test_npc_brain_no_alloc.gd`:
## a runtime memory probe is flaky, and a flaky test gets a wider threshold until
## it means nothing. The construction syntax is what the rule is about.
extends GutTest

const HASH := "res://scripts/systems/crowd/spatial_hash.gd"

## The functions that run every tick. `query()` is excluded on purpose.
const HOT_PATH: Array[String] = [
	"func rebuild(",
	"func count_within(",
	"func count_persona(",
	"func nearest_distance(",
	"func _cell_range(",
	"func _cell_of_point(",
]

## Constructions that allocate. `[` and `{` alone would match indexing and
## dictionary *lookups*, which are free — these are the forms that build.
const ALLOCATING: Array[String] = ["[]", "{}", ".new(", ".duplicate(", "Array(", "Dictionary("]


## The body of `name`, from its declaration to the next top-level `func`.
func _body_of(source: String, name: String) -> String:
	var at := source.find(name)
	if at < 0:
		return ""
	var next := source.find("\nfunc ", at + name.length())
	return source.substr(at, (next - at) if next > at else source.length() - at)


func test_the_hash_was_actually_read() -> void:
	# Guards the guard. A moved file reads as an empty string, and an empty string
	# contains no allocations at all.
	var source := SourceScanner.read(HASH)
	assert_gt(source.length(), 1000, "spatial_hash.gd is missing or unexpectedly small")
	for name: String in HOT_PATH:
		assert_ne(_body_of(source, name), "", "%s is gone — the scan covers nothing" % name)


func test_nothing_on_the_hot_path_allocates() -> void:
	var source := SourceScanner.read(HASH)
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
			"SpatialHash's hot path allocates.\n"
			+ "It is rebuilt once a tick and read twelve times, against a 2.0 ms\n"
			+ "budget for the whole crowd. TDD-08 §6.\n"
			+ "\n".join(offenders)
		)
	)


func test_the_buffers_are_sized_in_setup_rather_than_in_rebuild() -> void:
	# The other half of the same rule, and the one a scan for `[]` would miss: a
	# `resize()` inside `rebuild` is an allocation written in a syntax that does
	# not look like one.
	var body := _body_of(SourceScanner.read(HASH), "func rebuild(")
	assert_false(body.contains(".resize("), "rebuild() resizes a buffer — size it in setup()")


func test_the_check_can_actually_fail() -> void:
	# Falsification: the scan must see a planted construction in a body it covers.
	var planted := "func rebuild(a, b, c):\n\tvar buckets := {}\n\treturn buckets\n"
	var body := _body_of(planted, "func rebuild(")
	assert_ne(body, "", "the body extractor found nothing in a planted function")
	assert_true(body.contains("{}"), "the scan would not see a planted allocation")
