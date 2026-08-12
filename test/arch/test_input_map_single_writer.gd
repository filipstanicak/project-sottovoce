## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **ONLY `InputRebinder` WRITES `InputMap`.**
##
## The engine's map is global mutable state that nothing reads back and nothing
## logs. Two files writing it produce a binding that depends on node order, and
## the symptom is a control that works on one machine and not another.
##
## There are two writers' worth of reason to touch it now: rebinding (GDD-02
## §1.4) and the device restriction `PadSelection` decides (§1.3). Both go
## through the one seam, which is why that file is deliberately thin.
##
## Why review misses this: `InputMap.action_add_event` reads like a local call.
## Nothing about it says the effect is global and permanent for the session.
extends GutTest

const WRITER := "res://scripts/presentation/input_rebinder.gd"
const ROOTS: Array[String] = ["res://scripts", "res://tools"]

## The mutating half of the API. `has_action`, `action_get_events` and
## `event_is_action` are reads and may be called from anywhere.
const WRITES: Array[String] = [
	"InputMap.action_add_event",
	"InputMap.action_erase_event",
	"InputMap.action_erase_events",
	"InputMap.add_action",
	"InputMap.erase_action",
	"InputMap.load_from_project_settings",
]


func _sources() -> PackedStringArray:
	var out: PackedStringArray = []
	for root: String in ROOTS:
		out.append_array(SourceScanner.gd_files(root))
	return out


func test_sources_exist_to_be_scanned() -> void:
	# Guards the guard: an empty list passes every assertion below.
	assert_gt(_sources().size(), 50, "found almost no scripts — the scan is broken, not clean")


func test_only_the_rebinder_writes_the_input_map() -> void:
	var offenders: PackedStringArray = []
	for path: String in _sources():
		if path == WRITER:
			continue
		for call: String in WRITES:
			if SourceScanner.code_contains(path, call):
				offenders.append("%s calls %s" % [path, call])
	assert_eq(
		offenders,
		PackedStringArray(),
		"InputMap is written outside %s — route it through that seam" % WRITER
	)


func test_the_writer_still_writes() -> void:
	# Without this, deleting every write from the rebinder would leave the guard
	# above green over a project that cannot bind anything at all.
	assert_true(
		SourceScanner.code_contains(WRITER, "InputMap.action_add_event"),
		"%s no longer writes the map — this guard is now watching nothing" % WRITER
	)
