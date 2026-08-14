## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **NOTHING GAMEPLAY-RELEVANT RUNS IN `_process`.** TDD-01 §4, US-0027.
##
## `_process` runs once per rendered frame, which is a number nobody controls: it
## is 144 on one machine, 58 on another, and 12 during a hitch. Anything that
## decides an outcome from there decides it a different number of times per
## second on every machine — and the two that matter most, suspicion accrual and
## detection, would be *frame-rate dependent stealth*.
##
## `_physics_process` is fixed at `TUN-NET-CLIENT-INPUT-RATE` and the net tick is
## a division of it. That is the only clock the server has.
##
## Why review misses this: `_process` is the habit. It is what every tutorial
## uses, it works, and the difference only appears as a player on a fast machine
## accruing suspicion faster than one on a slow machine — which nobody attributes
## to a function name.
##
## **A SYSTEM MAY NOT DECLARE `_physics_process` EITHER.** Systems are ticked
## explicitly by `MatchDirector`, in `SystemOrder`'s order; one that ticked itself
## would run at the physics rate and in scene-tree order, which is the invisible
## dependency §4 exists to remove.
extends GutTest

## Server-authoritative code. `scripts/presentation/` is deliberately absent —
## a camera rig SHOULD run per frame, and the FOV ladder is smoother for it.
const ROOTS: Array[String] = ["res://scripts/systems", "res://scripts/net", "res://scripts/server"]

## Where systems live. The self-ticking rule is about THEM, and only them:
## `match_director.gd` IS the clock — the net tick is its `_physics_process`
## divided by two — and `net.gd` runs a fixed-rate ping heartbeat that is not
## gameplay and is ordered by nothing.
const SYSTEMS_ROOT := "res://scripts/systems"


func _files() -> PackedStringArray:
	var out: PackedStringArray = []
	for root: String in ROOTS:
		out.append_array(SourceScanner.gd_files(root))
	return out


func test_files_exist_to_be_checked() -> void:
	# Guards the guard. An empty scan is vacuously green, which this project has
	# now shipped four times.
	assert_gt(_files().size(), 5, "found almost no server-side files — the scan broke")


func test_nothing_server_side_declares_process() -> void:
	var offenders: PackedStringArray = []
	for path: String in _files():
		for hit: String in SourceScanner.find(path, "func _process("):
			offenders.append("%s %s" % [path, hit])
	offenders.sort()

	assert_eq(
		offenders.size(),
		0,
		(
			"Server-side code declares _process.\n"
			+ "_process runs once per RENDERED frame — 144 times a second on one\n"
			+ "machine and 12 during a hitch. Anything deciding an outcome there\n"
			+ "decides it at a rate the player's hardware chooses.\n"
			+ "Use the net tick: MatchDirector.net_ticked, or GameSystem.tick().\n"
			+ "\n".join(offenders)
		)
	)


func test_no_system_ticks_itself() -> void:
	# **A SYSTEM THAT TICKS ITSELF RUNS AT THE WRONG RATE AND IN THE WRONG
	# ORDER**, and both failures are silent: it works, it is simply 30 ticks a
	# second early and ahead of the crowd it depends on.
	var offenders: PackedStringArray = []
	for path: String in SourceScanner.gd_files(SYSTEMS_ROOT):
		for hit: String in SourceScanner.find(path, "func _physics_process("):
			offenders.append("%s %s" % [path, hit])
	offenders.sort()

	assert_eq(
		offenders.size(),
		0,
		(
			"Server-side code ticks itself.\n"
			+ "Systems are ticked explicitly by MatchDirector in SystemOrder's order.\n"
			+ "A system with its own _physics_process runs at the physics rate and in\n"
			+ "scene-tree order — the invisible dependency TDD-01 §4 exists to remove.\n"
			+ "\n".join(offenders)
		)
	)


func test_the_check_can_actually_fail() -> void:
	# Falsification: the needle must match the shape it claims to, or this guard
	# reports clean over anything at all.
	assert_gt(
		(
			SourceScanner
			. find("res://scripts/server/match_director.gd", "func _physics_process(")
			. size()
		),
		0,
		"the needle no longer matches a declaration that certainly exists"
	)
