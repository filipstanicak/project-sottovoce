## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **THE PREY WARNING CARRIES A BEARING AND NEVER AN IDENTITY.**
##
## **This guard used to enforce the opposite half.** Until 2026-08-26 the warning
## was directionless at three layers — no protocol field, no signal parameter, no
## positional emitter — and this file existed to keep it that way. ADR-0013
## overturned that for reference fidelity: the reference marks a revealed pursuer
## on the compass with direction and range, so `TUN-COMPASS-WARN-GIVES-DIRECTION`
## is `true` and the signal will carry a bearing.
##
## **What survives is the more important half, and it is the reason this file was
## re-authored rather than deleted.** Direction tells you *where*; nothing here may
## ever tell you *who*. A persona, a slot, a name or a colour on this signal would
## collapse the crowd from seventy-eight candidates to one, permanently, and
## `ASM-0030`'s Compass lock — the only thing in the game that earns an identity —
## would have nothing left to earn.
##
## Why review misses it: adding `persona: int` here is a one-token change that
## compiles, runs, and makes the HUD strictly more informative.
extends GutTest

const BUS := "res://scripts/presentation/event_bus.gd"
const SIGNAL_NAME := "prey_warning_triggered"

## Anything that names, identifies or distinguishes a *person* rather than a
## direction. Matched against the signal's parameter list.
const IDENTIFYING: Array[String] = [
	"persona",
	"slot",
	"peer",
	"name",
	"identity",
	"colour",
	"color",
	"portrait",
]


func test_the_signal_is_declared() -> void:
	assert_true(
		SourceScanner.code_contains(BUS, "signal " + SIGNAL_NAME),
		"the prey warning signal is missing entirely"
	)


## The declared parameter list, or "" for a bare `signal name`.
func _parameters() -> String:
	for pair: Array in SourceScanner.code_lines(BUS):
		var line: String = String(pair[1]).strip_edges()
		if line.begins_with("signal " + SIGNAL_NAME):
			return line.substr(7 + SIGNAL_NAME.length()).strip_edges()
	return ""


func test_it_names_nobody() -> void:
	var params := _parameters().to_lower()
	var offenders: PackedStringArray = []
	for word: String in IDENTIFYING:
		if params.contains(word):
			offenders.append(word)
	assert_eq(
		offenders.size(),
		0,
		(
			"The prey warning gained an identifying parameter: "
			+ ", ".join(offenders)
			+ ".\nIt may say WHERE. It may never say WHO — that is what a Compass lock is "
			+ "for, and it is the only thing in the game that earns an identity.\n"
			+ "declared as: signal "
			+ SIGNAL_NAME
			+ " "
			+ _parameters()
		)
	)


func test_the_tunable_agrees() -> void:
	# The rule is one rule across the protocol, the signal and the widget. If the
	# tunable and this guard ever disagree, one of them is a fig leaf.
	var doc := SourceScanner.read("res://docs/50_tuning/TUNABLES.md")
	var idx := doc.find("TUN-COMPASS-WARN-GIVES-DIRECTION")
	assert_gt(idx, -1, "TUN-COMPASS-WARN-GIVES-DIRECTION is missing from TUNABLES.md")
	assert_true(
		doc.substr(idx, 90).contains("true"),
		"TUN-COMPASS-WARN-GIVES-DIRECTION is no longer true — ADR-0013 and the document disagree"
	)
	assert_true(
		Tuning.compass.warn_gives_direction,
		"the shipped profile says the warning is directionless; the document says otherwise"
	)


func test_the_tier_gate_is_still_what_makes_a_good_hunter_invisible() -> void:
	# **THE HALF THAT WAS NEVER IN DOUBT, AND IS NOW LOAD-BEARING.** Direction is
	# what carelessness costs. An Anonymous pursuer produces no warning at all, so
	# the panicked scan of a crowd is still exactly what a competent hunter leaves
	# you with — which is also the reference's rule, not a divergence from it.
	assert_almost_eq(
		Tuning.compass.warn_min_tier,
		Tuning.combat.stun_min_tier,
		0.001,
		"the warn gate and the stun gate have drifted apart — invariant 8"
	)
	assert_gt(Tuning.compass.warn_min_tier, 0.0, "an Anonymous pursuer now triggers a warning")


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
