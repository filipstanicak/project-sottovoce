## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **NO CLIENT COMPUTES SUSPICION.** CLAUDE.md never-do #3, ADR-0002 point 5,
## US-0052's eighth criterion.
##
## Position is predicted because a pawn that waited for the wire would feel
## broken. Suspicion is not, and the reason is that the two fail differently: a
## mispredicted position is corrected by a snapshot and the player never learns
## it happened, while a mispredicted suspicion **drifts** — there is no
## reconciliation for it, so a client-side estimate "just for the HUD" ends the
## match reading a number the server never held. A HUD that disagrees with the
## server is worse than no HUD, because the player spends decisions on it.
##
## Why review misses this: the tempting version is one line in a view model, it
## looks like an optimisation, it makes the HUD smoother, and it is right for the
## first thirty seconds of every playtest.
##
## **THE STRUCTURAL HALF IS STRONGER THAN THE TEXTUAL ONE AND BOTH ARE HERE.**
## `PredictedState` has nowhere to put gameplay state — that is US-0032's design,
## and it is asserted rather than trusted, because a field added to it would be a
## one-line change with no other symptom.
extends GutTest

## Client and presentation code. Nothing under these may decide a suspicion value.
const CLIENT_ROOTS: Array[String] = [
	"res://scripts/net/client",
	"res://scripts/mirrors",
	"res://scripts/presentation",
]

## The pure integrator and the bitfield. **Server-side arithmetic**: a client that
## called either would be computing a value the server owns.
const FORBIDDEN_CALLS: Array[String] = [
	"SuspicionMath.",
	"SuspicionSources.",
	"SuspicionState.new(",
	"SuspicionImpulses.",
]

## Writes to the mirrored fields. A client may *read* what the snapshot gave it;
## assigning is the estimate this guard exists to refuse.
const FORBIDDEN_WRITES: Array[String] = [
	".suspicion =",
	".tier =",
	".active_sources =",
]

## `PredictedState`'s whole field list. The omissions are the design.
const PREDICTED_FIELDS: Array[String] = [
	"position",
	"velocity",
	"state_id",
	"state_timer_ticks",
	"grounded",
]


func _client_files() -> PackedStringArray:
	var found := PackedStringArray()
	for root: String in CLIENT_ROOTS:
		for path: String in SourceScanner.gd_files(root):
			found.append(path)
	return found


func test_the_scan_reaches_client_code_at_all() -> void:
	# **THE VACUOUS-SUCCESS GUARD, FIRST.** `scripts/mirrors/` is empty today and
	# git does not track empty directories, so a guard that walked only that would
	# report clean over nothing — which is exactly how `ip-guard` and
	# `asset-inventory` printed green over zero of 739 files for two milestones.
	var files := _client_files()
	assert_gt(
		files.size(), 5, "the client scan found %d files, so it is not scanning" % files.size()
	)


func test_no_client_file_computes_a_suspicion_value() -> void:
	for path: String in _client_files():
		for needle: String in FORBIDDEN_CALLS:
			assert_false(
				SourceScanner.code_contains(path, needle),
				"%s calls %s — suspicion is the server's (never-do #3)" % [path, needle]
			)


func test_no_client_file_assigns_a_mirrored_gameplay_field() -> void:
	for path: String in _client_files():
		for needle: String in FORBIDDEN_WRITES:
			var hits := SourceScanner.find(path, needle)
			assert_eq(
				hits.size(),
				0,
				(
					"%s writes %s — a client mirrors these, it does not decide them: %s"
					% [path, needle, hits]
				)
			)


func test_predicted_state_has_nowhere_to_put_gameplay_state() -> void:
	# **THE STRUCTURAL HALF.** ADR-0002 point 5 is kept by having no field to break
	# it with, and this is what says the field list has not grown.
	var state := PredictedState.new()
	var declared: Array = []
	for entry: Dictionary in state.get_property_list():
		if int(entry["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			declared.append(String(entry["name"]))
	assert_gt(declared.size(), 0, "PredictedState declared no properties, so this reads nothing")
	for name: String in declared:
		assert_true(
			PREDICTED_FIELDS.has(name),
			(
				(
					"PredictedState gained '%s'. Only motion is predicted — if this is gameplay state, "
					+ "it belongs in the snapshot's own-gameplay block instead"
				)
				% name
			)
		)


func test_the_snapshot_is_the_only_route_those_values_take() -> void:
	# The positive half: the wire carries them, so a client has somewhere to read
	# them from and never a reason to compute them. If these fields ever leave the
	# format, the guard above stops meaning "the client waits" and starts meaning
	# "the client is blind".
	var snapshot := Snapshot.new()
	for field: String in ["suspicion", "tier", "active_sources"]:
		assert_true(
			field in snapshot, "Snapshot no longer carries %s — see NETWORK_PROTOCOL §4" % field
		)
