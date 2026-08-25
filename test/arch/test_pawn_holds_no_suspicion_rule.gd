## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **THE SUSPICION LADDER LIVES IN ONE PLACE.** CLAUDE.md never-do #3,
## TDD-07 §2, US-0053.
##
## `scripts/pawn/` carried a **second, complete** implementation of it from M1 to
## 2026-08-25: `PawnState.suspicion_rate()` and twelve overrides, with a roof
## toll, a decay, a climb rate and a blend crush. **Nothing in the shipped game
## ever called any of it**, and four unit-test files asserted it in detail, which
## is exactly what made it look maintained.
##
## It was not merely a duplicate. It **disagreed**: a pawn state cannot see the
## crowd, so there was no `TUN-SUSPICION-GAIN-OPEN` — a player standing alone in
## an empty plaza *recovered* anonymity at −8/s there while `SuspicionMath`
## charges +6/s. Opposite signs on the mechanic that makes an empty plaza
## dangerous. There was no `TUN-SUSPICION-DECAY-DELAY` either, so tap-sprinting
## was free.
##
## Why review misses this: each rate is one line, it reads from tuning, it has a
## docstring quoting the GDD, and it is *right in isolation*. The wrongness is a
## property of the pair, and only one of the pair runs.
##
## **AND `scripts/pawn/` IS REPLAYED DURING PREDICTION RECONCILIATION**, so
## anything here that decided a suspicion value would be a client deciding its own
## — the defect `test_suspicion_is_never_predicted.gd` guards from the other side.
extends GutTest

const PAWN := "res://scripts/pawn"

## The function that was the whole of it. A `PawnState` override is invisible to
## every caller except the base class, so a reinstated one would be called by
## nothing and asserted by whatever test came with it.
const BANNED_FUNCS: Array[String] = ["func suspicion_rate", "func _ground_rate", "func _decay_rate"]

## Writes to the server-authoritative mirror. `StunnedState.enter()` did exactly
## this — `ctx.suspicion = Tuning.suspicion.max_value` — which was wrong twice
## over: predicted code writing gameplay state, and a rule TUNABLES §17 says must
## be **held** for `TUN-STUN-FREEZE` applied as a single nudge that the re-armed
## decay began eating on the next tick. It is `SuspicionSystem`'s now.
const BANNED_WRITES: Array[String] = [".suspicion =", ".tier =", ".active_sources ="]

## **THE ONLY `Tuning.suspicion` FIELD `scripts/pawn/` MAY READ.**
## `TUN-BLEND-BREAK-ON-SPEED` is a state *transition* — `BlendedState` leaves when
## the pawn exceeds it — rather than a suspicion rate. Every other field in that
## section is a rate, a threshold or a window that `SYS-SUSPICION` owns.
##
## **THIS LIST IS THE ONLY WAY PAST THE GUARD.** Adding to it to make a failure go
## away is how the rule dies; each entry has to be something the pawn genuinely
## decides.
const ALLOWED_TUNING_FIELDS: Array[String] = ["break_on_speed"]


func _pawn_files() -> PackedStringArray:
	return SourceScanner.gd_files(PAWN)


func test_the_scan_reaches_the_pawn_at_all() -> void:
	# **THE VACUOUS-SUCCESS GUARD, FIRST.** A path typo makes every assertion below
	# true of nothing, which is the shape `ip-guard` wore while it printed clean
	# over zero of 739 files for two milestones.
	var files := _pawn_files()
	assert_gt(
		files.size(), 10, "the pawn scan found %d files, so it is not scanning" % files.size()
	)


func test_no_pawn_state_declares_a_suspicion_rate() -> void:
	for path: String in _pawn_files():
		for needle: String in BANNED_FUNCS:
			assert_false(
				SourceScanner.code_contains(path, needle),
				(
					(
						"%s declares `%s`. The suspicion ladder is SuspicionMath's — a second copy "
						+ "here would be uncalled, untested against the real one, and free to disagree."
					)
					% [path, needle]
				)
			)


func test_no_pawn_file_writes_a_server_authoritative_field() -> void:
	for path: String in _pawn_files():
		for needle: String in BANNED_WRITES:
			var hits := SourceScanner.find(path, needle)
			assert_eq(
				hits.size(),
				0,
				(
					(
						"%s writes %s. scripts/pawn/ is replayed during reconciliation, so this is a "
						+ "client deciding its own gameplay state (never-do #3): %s"
					)
					% [path, needle, hits]
				)
			)


func test_no_pawn_file_reads_a_suspicion_rate_or_threshold() -> void:
	# The stronger half of the same rule: without it a state could inline the
	# arithmetic under any name at all and the function scan would pass over it.
	#
	# **PER LINE, NOT PER FILE.** The first version asked whether the *file*
	# mentioned an allowed field anywhere, so `blended_state.gd` — which reads
	# `break_on_speed` legitimately in `step()` — was waved through for every other
	# field as well. Falsified against a planted crush rate it stayed green while
	# the function scan beside it went red. A guard whose allowance is coarser than
	# its rule has a hole the exact shape of its exception.
	for path: String in _pawn_files():
		for pair: Array in SourceScanner.code_lines(path):
			var code := String(pair[1])
			for field: String in _fields_read_on(code):
				assert_true(
					ALLOWED_TUNING_FIELDS.has(field),
					(
						(
							"%s:%d reads Tuning.suspicion.%s. Only %s is the pawn's; everything else in "
							+ "that section is a rate or a threshold SYS-SUSPICION owns."
						)
						% [path, int(pair[0]), field, ALLOWED_TUNING_FIELDS]
					)
				)


## Every `Tuning.suspicion.<field>` named on one line of code.
##
## Split on the prefix and everything after the first piece begins with a field
## name; the identifier runs to the first character GDScript cannot put in one.
func _fields_read_on(code: String) -> PackedStringArray:
	var found := PackedStringArray()
	var pieces := code.split("Tuning.suspicion.")
	for index: int in range(1, pieces.size()):
		var name := ""
		for character: String in String(pieces[index]):
			if not (
				character.is_valid_identifier() or character == "_" or character.is_valid_int()
			):
				break
			name += character
		if name != "":
			found.append(name)
	return found


func test_the_ladder_it_protects_is_actually_somewhere_else() -> void:
	# **THE GUARD MUST NOT PASS BY THE LADDER HAVING BEEN DELETED OUTRIGHT.** If
	# `SuspicionMath` stopped charging for a roof, every assertion above would still
	# be green and the game would have no ladder at all.
	var t := Tuning.suspicion
	var s := SuspicionState.new()
	s.nearest_npc_distance = 0.5
	s.speed_state = PawnStateId.SPRINT
	s.on_roof = true
	assert_almost_eq(
		SuspicionMath.gain_rate(s, t),
		t.gain_sprint + t.gain_roof,
		0.001,
		"SuspicionMath no longer charges for speed and elevation — the ladder is gone, not moved"
	)
