## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## Dependencies point downward only: Presentation -> Net -> Systems -> Core.
##
## Why review misses this: a system that references a widget compiles and runs
## perfectly. Nothing fails until the headless server export — which excludes
## all presentation code — cannot start. By then the dependency is load-bearing.
extends GutTest

const FORBIDDEN_FROM_LOWER: Array[String] = [
	"res://scripts/presentation",
	"res://scripts/mirrors",
	"res://scenes/ui",
]

const LOWER_LAYERS: Array[String] = [
	"res://scripts/core",
	"res://scripts/systems",
]


func test_core_and_systems_never_reference_presentation() -> void:
	var violations: PackedStringArray = []
	for layer: String in LOWER_LAYERS:
		for path: String in SourceScanner.gd_files(layer):
			for forbidden: String in FORBIDDEN_FROM_LOWER:
				for hit: String in SourceScanner.find(path, forbidden):
					violations.append("%s references %s" % [hit, forbidden])
	assert_eq(
		violations.size(),
		0,
		(
			"Layer rule violated — a lower layer references presentation.\n"
			+ "The server export excludes presentation entirely; this would break it.\n"
			+ "\n".join(violations)
		)
	)


func test_systems_never_reference_event_bus() -> void:
	# System-to-system communication uses direct typed calls, because gameplay
	# ordering matters and a bus makes ordering invisible (ADR-0006 rule 5).
	var violations: PackedStringArray = []
	for path: String in SourceScanner.gd_files("res://scripts/systems"):
		violations.append_array(SourceScanner.find(path, "EventBus"))
	assert_eq(
		violations.size(),
		0,
		(
			"A system referenced EventBus. Systems talk to each other by direct call.\n"
			+ "\n".join(violations)
		)
	)
