## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **`InputSampler.sample()` HAS EXACTLY ONE CALLER, AND THE SAMPLER HAS NO LOOP
## OF ITS OWN.**
##
## TDD-03 §1.2's client diagram has one box that samples, run from one
## `_physics_process` at `TUN-NET-CLIENT-INPUT-RATE`. `sample()` is not a getter:
## it advances `_seq`, resolves every hold/toggle latch, and ticks `SpeedGate`'s
## hold and double-tap counters. Calling it twice in a frame runs all of that at
## 120 Hz.
##
## It was called twice from US-0016 to US-0025. The sampler emitted
## `command_sampled` from its own `_physics_process` and `LocalPawnDriver` took a
## second sample in its own — a wire connected at both ends, each end reasonable.
##
## Why review missed it: the two invocations agreed. `_command` is one reused
## object holding *absolute* look values, so nothing a human could see differed.
## Only the COUNTED things diverged, and the one that mattered was the friction
## GDD-02 §1.5 spends a page defending: `TUN-SPEED-SPRINT-HOLD` is 0.4 s, and
## sprint was opening in 0.21. Design law 1 prices speed in anonymity, and this
## was a discount nobody authored.
##
## The same shape as trap 9 — a tuned duration halved by a rate, surfacing as a
## plausible integer instead of an error. `test_input_sampled_once.gd` measures
## the consequence end to end; this names the cause, which is cheaper to read.
extends GutTest

const SAMPLER := "res://scripts/presentation/input_sampler.gd"
const DRIVER := "res://scripts/presentation/local_pawn_driver.gd"


func test_the_scan_found_the_files() -> void:
	# Guards the guard: an unreadable path would pass every check below in silence,
	# which is the failure mode trap 3 is about.
	assert_gt(SourceScanner.code_lines(SAMPLER).size(), 40, "the sampler did not scan")
	assert_gt(SourceScanner.code_lines(DRIVER).size(), 40, "the driver did not scan")


func test_the_sampler_does_not_drive_itself() -> void:
	# A `_physics_process` here is a second loop by definition, whatever it does
	# inside — there is already one calling `sample()` once per frame.
	assert_false(
		SourceScanner.code_contains(SAMPLER, "func _physics_process"),
		(
			"InputSampler has a loop again. It is a service the client loop calls, "
			+ "not a producer that runs itself — two loops sample twice a frame and "
			+ "every counter behind sample() doubles, TUN-SPEED-SPRINT-HOLD first."
		)
	)


func test_only_the_driver_calls_sample() -> void:
	var callers: PackedStringArray = []
	for path: String in SourceScanner.gd_files("res://scripts"):
		if path == SAMPLER:
			continue  # Its own declaration, `func sample(`, is not a call.
		if SourceScanner.code_contains(path, ".sample("):
			callers.append(path)
	callers.sort()
	assert_eq(
		String("\n").join(callers),
		DRIVER,
		(
			"sample() must have exactly one caller, LocalPawnDriver, which announces "
			+ "the result on `command_sampled`. Listen to that signal instead; a "
			+ "second call re-ticks the sprint gate and the latches."
		)
	)


func test_the_signal_belongs_to_the_caller() -> void:
	# Ownership is the structural half of the rule. A signal emitted by something
	# other than the producer of its payload is what invites a second producer.
	assert_true(
		SourceScanner.code_contains(DRIVER, "signal command_sampled"),
		"LocalPawnDriver no longer declares command_sampled"
	)
	assert_false(
		SourceScanner.code_contains(SAMPLER, "signal command_sampled"),
		"InputSampler declares command_sampled again — it is the driver's to emit"
	)


func test_the_check_can_actually_fail() -> void:
	# Falsification: the matcher must see a real call, or it would report one
	# caller against a project that had ten.
	assert_true(String("	var command := _sampler.sample(delta)").contains(".sample("))
	assert_false(String("func sample(delta: float) -> InputCommand:").contains(".sample("))
