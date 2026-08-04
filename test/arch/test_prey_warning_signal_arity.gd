## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## `prey_warning_triggered` TAKES ZERO PARAMETERS.
##
## This is layer two of three enforcing the same rule:
##
##   Protocol  NET-S2C-PREY-WARNING carries a tick and nothing else
##   Signal    zero parameters — there is nothing a widget COULD render
##   Widget    the flash is non-directional, the sting mono and centred
##
## Why this needs a test of its own: adding `direction: Vector2` here would be a
## one-token change that compiles, runs, and makes the HUD strictly more
## informative. It would also delete the best moment in the game — the panicked
## scan of a crowd — and nothing else in the build would complain.
##
## `TUN-COMPASS-WARN-GIVES-DIRECTION` is `false` and belongs to the same rule.
extends GutTest

const BUS := "res://scripts/presentation/event_bus.gd"
const SIGNAL_NAME := "prey_warning_triggered"


func test_the_signal_is_declared() -> void:
	assert_true(
		SourceScanner.code_contains(BUS, "signal " + SIGNAL_NAME),
		"the prey warning signal is missing entirely"
	)


func test_it_takes_no_parameters() -> void:
	var offenders: PackedStringArray = []
	for pair: Array in SourceScanner.code_lines(BUS):
		var line: String = String(pair[1]).strip_edges()
		if not line.begins_with("signal " + SIGNAL_NAME):
			continue
		var rest := line.substr(7 + SIGNAL_NAME.length()).strip_edges()
		# Bare `signal name` is correct. `signal name()` is tolerated. Anything
		# between the parentheses is not.
		if rest != "" and rest != "()":
			offenders.append("declared as: %s" % line)
	assert_eq(
		offenders.size(),
		0,
		(
			"The prey warning gained a parameter.\n"
			+ "It is directionless at three layers on purpose. A parameter here gives a\n"
			+ "widget something to render, and the panicked scan of the crowd is gone.\n"
			+ "\n".join(offenders)
		)
	)


func test_the_tunable_agrees() -> void:
	# The rule is one rule. If the tunable ever says the warning gives direction,
	# the signal's arity is no longer the whole story and this guard is a fig leaf.
	var doc := SourceScanner.read("res://docs/50_tuning/TUNABLES.md")
	var idx := doc.find("TUN-COMPASS-WARN-GIVES-DIRECTION")
	assert_gt(idx, -1, "TUN-COMPASS-WARN-GIVES-DIRECTION is missing from TUNABLES.md")
	assert_true(
		doc.substr(idx, 120).contains("false"),
		"TUN-COMPASS-WARN-GIVES-DIRECTION is no longer false — the three layers disagree"
	)


func test_the_signal_reaches_the_widget_layer_only() -> void:
	# A system emitting this directly would bypass the server-authoritative path
	# that decides whether a warning is owed at all.
	var offenders: PackedStringArray = []
	for path: String in SourceScanner.gd_files("res://scripts/systems"):
		offenders.append_array(SourceScanner.find(path, SIGNAL_NAME))
	assert_eq(
		offenders.size(),
		0,
		"a system referenced the prey warning signal directly.\n" + "\n".join(offenders)
	)
