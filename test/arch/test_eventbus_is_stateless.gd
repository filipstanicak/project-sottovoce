## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## The EventBus holds signals, comments and nothing else.
##
## Why review misses this: a `var last_tier` on the bus looks like a convenience
## the first time, and it is — for exactly one caller. The second caller reads it
## at a different moment, the two disagree, and the ordering that decides which
## is right is invisible because the bus has no ordering. A stateful event bus is
## a global variable that nobody calls a global variable.
extends GutTest

const BUS := "res://scripts/presentation/event_bus.gd"


func test_the_bus_declares_no_variables() -> void:
	var offenders: PackedStringArray = []
	for pair: Array in SourceScanner.code_lines(BUS):
		var line: String = String(pair[1]).strip_edges()
		if line.begins_with("var ") or line.begins_with("@export"):
			offenders.append("%s:%d %s" % [BUS, pair[0], line])
	assert_eq(
		offenders.size(),
		0,
		(
			"The EventBus declared state. It carries signals only — a value stored\n"
			+ "here is read at a moment nobody agreed on.\n"
			+ "\n".join(offenders)
		)
	)


func test_the_bus_declares_no_functions() -> void:
	# A function is state's twin: `emit_tier(...)` is a place for logic to
	# accumulate, and logic on the bus is logic with no owner and no test.
	var offenders: PackedStringArray = []
	for pair: Array in SourceScanner.code_lines(BUS):
		var line: String = String(pair[1]).strip_edges()
		if line.begins_with("func ") or line.begins_with("static func "):
			offenders.append("%s:%d %s" % [BUS, pair[0], line])
	assert_eq(
		offenders.size(),
		0,
		"The EventBus declared a function. Signals only.\n" + "\n".join(offenders)
	)


func test_every_code_line_is_a_signal_or_extends() -> void:
	# The positive form of the two rules above: catches anything neither `var`
	# nor `func` that still is not a declaration — a const, a class_name, an
	# enum, a stray expression.
	var offenders: PackedStringArray = []
	for pair: Array in SourceScanner.code_lines(BUS):
		var line: String = String(pair[1]).strip_edges()
		if line.begins_with("signal ") or line.begins_with("extends "):
			continue
		offenders.append("%s:%d %s" % [BUS, pair[0], line])
	assert_eq(
		offenders.size(),
		0,
		(
			"A line in the EventBus is neither `extends` nor `signal`.\n"
			+ "Comments and blanks are fine; code is not.\n"
			+ "\n".join(offenders)
		)
	)
