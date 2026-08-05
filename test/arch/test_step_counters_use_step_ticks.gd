## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **A COUNTER ADVANCED INSIDE `step()` IS COMPARED AGAINST `Tuning.step_ticks`,
## NEVER `Tuning.ticks`.**
##
## There are two tick domains (TDD-03 §1.1). Gameplay *decisions* happen at the
## 30 Hz net tick; pawn *integration* substeps at 60 Hz, once per received
## `InputCommand`. `Tuning.ticks()` converts at 30 Hz. `ctx.state_timer_ticks`
## and the action buffers advance at 60. Comparing one against the other makes
## every window expire at **half** its tuned length.
##
## Why review misses this: both are integers, both are plausible, and the call
## sites read perfectly — `if ctx.state_timer_ticks >= Tuning.ticks(...)` is
## exactly what the TDD's own pseudocode shows. Nothing errors, no test fails,
## and the only symptom is that the game is twice as fast as the document.
##
## It shipped that way from US-0013 to US-0016: the stun freeze ran 1.0 s instead
## of 2.0 — halving the one mechanic design law 5 forbids weakening — the kill
## animation 0.7 s instead of 1.4, and Jog escalated to Run in 0.18 s instead of
## 0.35. Three merged defects of one shape, which is what a guard is for.
extends GutTest

## Files whose counters advance once per `step()`. `scripts/pawn/` is the whole
## replayed path; `sprint_gate.gd` is sampled at the same 60 Hz.
const STEP_RATE_SOURCES: Array[String] = [
	"res://scripts/pawn",
	"res://scripts/core/sprint_gate.gd",
]


func _files() -> PackedStringArray:
	var out: PackedStringArray = []
	for entry: String in STEP_RATE_SOURCES:
		if entry.ends_with(".gd"):
			out.append(entry)
		else:
			out.append_array(SourceScanner.gd_files(entry))
	return out


func test_the_scan_found_files() -> void:
	# Guards the guard: an empty file list would pass the check below in silence.
	assert_gt(_files().size(), 8, "the step-rate source scan matched almost nothing")


func test_no_step_rate_file_calls_the_net_tick_conversion() -> void:
	var violations: PackedStringArray = []
	for path: String in _files():
		for pair: Array in SourceScanner.code_lines(path):
			var line := String(pair[1])
			if line.contains("Tuning.step_ticks("):
				continue
			if line.contains("Tuning.ticks("):
				violations.append("%s:%d %s" % [path, pair[0], line.strip_edges()])
	violations.sort()
	assert_eq(
		violations.size(),
		0,
		(
			"A 60 Hz counter is compared against a 30 Hz conversion.\n"
			+ "Every window here would expire at HALF its tuned length, silently.\n"
			+ "Use Tuning.step_ticks(); see its docstring for the four that shipped.\n"
			+ "\n".join(violations)
		)
	)


func test_the_two_domains_differ_and_the_ratio_is_two() -> void:
	# If these ever became equal the guard above would still pass while meaning
	# nothing, so the premise is asserted rather than assumed.
	assert_eq(Tuning.net.client_input_rate, 60.0, "the pawn step rate moved")
	assert_eq(Tuning.net.server_tick, 30.0, "the net tick moved")
	assert_eq(
		Tuning.step_ticks(&"TUN-STUN-FREEZE"),
		2 * Tuning.ticks(&"TUN-STUN-FREEZE"),
		"the two tick domains are no longer 2:1"
	)


func test_the_check_can_actually_fail() -> void:
	# Falsification: the matcher must distinguish the two spellings, or it would
	# report success against any file at all.
	var good := '	if ctx.state_timer_ticks >= Tuning.step_ticks(&"TUN-STUN-FREEZE"):'
	var bad := '	if ctx.state_timer_ticks >= Tuning.ticks(&"TUN-STUN-FREEZE"):'
	assert_true(bad.contains("Tuning.ticks(") and not bad.contains("Tuning.step_ticks("))
	assert_true(good.contains("Tuning.step_ticks("))
