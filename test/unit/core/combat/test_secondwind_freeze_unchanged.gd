## **`PASV-SECONDWIND` SHORTENS THE EXILE AND NEVER THE FREEZE.** US-0061,
## TUNABLES `TUN-PASV-SECONDWIND-REDUCTION`, GDD-03 §10.
##
## The passive's whole specification is that **being stunned is always
## catastrophic in the moment**; what it buys is a shorter exile afterwards. A
## passive that trimmed the four seconds would be weakening stun to make hunting
## feel better, which never-do #13 forbids outright.
##
## **THE ONE-SIDEDNESS IS ENFORCED BY THERE BEING NO ARGUMENT.**
## `StunSystem.lockout_ticks` takes the flag; `StunnedState` reads
## `TUN-STUN-FREEZE` and takes nothing at all. This file asserts both halves,
## because the second is an absence and an absence is exactly what a refactor
## fills in.
extends GutTest


func test_the_passive_shortens_the_exile() -> void:
	var plain := StunSystem.lockout_ticks(false)
	var carried := StunSystem.lockout_ticks(true)
	assert_lt(carried, plain, "PASV-SECONDWIND buys nothing at all")
	assert_eq(
		plain - carried,
		Tuning.ticks(&"TUN-PASV-SECONDWIND-REDUCTION"),
		"the reduction is not TUN-PASV-SECONDWIND-REDUCTION"
	)


func test_it_is_derived_from_the_tick_tables_rather_than_from_seconds() -> void:
	# Both terms come from the precomputed tables, so the difference is exact at
	# any tick rate. Computed as `(12.0 - 4.0) * rate` it would round twice and
	# could land a tick away from the published figure — small, invisible, and the
	# kind of drift that makes a balance measurement irreproducible.
	assert_eq(
		StunSystem.lockout_ticks(false),
		Tuning.ticks(&"TUN-STUN-LOCKOUT"),
		"the plain lockout is not the tuned one"
	)
	assert_eq(
		StunSystem.lockout_ticks(true),
		Tuning.ticks(&"TUN-STUN-LOCKOUT") - Tuning.ticks(&"TUN-PASV-SECONDWIND-REDUCTION"),
		"the reduced lockout is not the difference of the two tables"
	)


func test_the_reduced_exile_is_still_long_enough_to_be_counterplay() -> void:
	# GDD-07 §4.6 lever 3: *do not go below 8 s* (GDD-03 §10.4). The passive takes
	# 12 s to exactly 8, so it sits on that floor rather than under it — and if
	# either tunable moves, this is what says the pair has crossed the line.
	var seconds := float(StunSystem.lockout_ticks(true)) / Tuning.net.server_tick
	assert_gte(seconds, 8.0, "PASV-SECONDWIND now takes the exile below GDD-03 §10.4's floor")


func test_the_freeze_is_the_same_number_either_way() -> void:
	# **THE ABSENCE, ASSERTED.** There is no argument through which the passive
	# could reach the freeze, so the strongest available statement is that the
	# state reads one tunable and that tunable is not touched by the reduction.
	var freeze := Tuning.step_ticks(&"TUN-STUN-FREEZE")
	assert_gt(freeze, 0, "TUN-STUN-FREEZE has no tick count; the state cannot end")
	# **`SourceScanner.code_contains` BLANKS STRING LITERALS**, so it cannot see a
	# `&"TUN-..."` id at all — which is the whole point of that class and is why
	# the positive half reads the raw file. The negative half keeps the scanner,
	# because there the blanking is exactly right: a mention of the passive in a
	# docstring must not trip a guard about code.
	var path := "res://scripts/pawn/states/stunned_state.gd"
	assert_true(
		SourceScanner.read(path).contains("TUN-STUN-FREEZE"),
		"StunnedState no longer reads TUN-STUN-FREEZE"
	)
	assert_false(
		SourceScanner.code_contains(path, "second_wind"),
		"the passive reached the freeze — never-do #13"
	)


func test_the_freeze_and_the_exile_are_different_tunables() -> void:
	# They have been confused before in this project's own prose. If they were ever
	# made equal, every assertion above would still pass while the mechanic lost
	# the distinction between *four seconds of helplessness* and *twelve seconds of
	# exile* — which is GDD-03 §10.2's third number.
	assert_gt(
		Tuning.combat.stun_lockout,
		Tuning.combat.stun_freeze,
		"the exile no longer outlasts the freeze; a stun is a delay again"
	)
