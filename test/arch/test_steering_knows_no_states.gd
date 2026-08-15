## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **STEERING KNOWS NOTHING ABOUT BRAIN STATES.** US-0041's fourth acceptance
## criterion, in the only form a machine can check: `steering.gd` never names
## `NpcBrain`, never names a state, and never asks a brain anything.
##
## Why it matters more than it looks. The crowd is an information channel — a
## player is expected to read a startle wave as a direction and an idle cluster
## as a place to stand. The moment the layer that *moves* NPCs can also see why
## they are moving, the answer to "why did that one walk there" lives in two
## files, and the two drift. TDD-08 §11.3 also names steering as the candidate
## for a C# or GDExtension port; a numeric inner loop that reaches into a GDScript
## enum is not portable.
##
## Why review misses this: adding `if brain.state == State.STARTLE` to steering is
## the shortest possible fix for any flee bug, it works, and nothing else in the
## project would ever complain.
extends GutTest

const STEERING := "res://scripts/systems/crowd/steering.gd"
const DIRECTOR := "res://scripts/systems/crowd/crowd_director.gd"

## Everything that would mean steering had learned about states.
const FORBIDDEN: Array[String] = [
	"NpcBrain",
	"brain",
	"State.",
	"CrowdContext",
	"startle_flag",
]


func test_the_file_exists_to_be_scanned() -> void:
	# Guards the guard. A path typo makes every assertion below vacuously green,
	# which this project has now shipped five times.
	assert_ne(SourceScanner.read(STEERING), "", "steering.gd is missing — the scan proves nothing")


func test_steering_names_no_state_and_no_brain() -> void:
	var offenders: PackedStringArray = []
	for needle: String in FORBIDDEN:
		for hit: String in SourceScanner.find(STEERING, needle):
			offenders.append("%s -> %s" % [needle, hit])
	assert_eq(
		offenders.size(),
		0,
		(
			"steering.gd refers to the state machine:\n"
			+ "\n".join(offenders)
			+ "\nSteering takes a point and a speed. The state that chose them is "
			+ "CrowdDirector's business — see US-0041."
		)
	)


func test_the_guard_would_catch_a_violation() -> void:
	# **FALSIFIED, NOT TRUSTED.** `SourceScanner.find` strips string literals, and
	# a guard that scanned the wrong way would be green forever — trap 3's family,
	# which has now cost this project five separate defects. The planted line is
	# the shortest real violation somebody would actually write.
	var planted := "\tif brain.state == NpcBrain.State.STARTLE:\n"
	var caught := false
	for needle: String in FORBIDDEN:
		if planted.contains(needle):
			caught = true
	assert_true(caught, "the forbidden list would not catch the obvious violation")


func test_the_director_is_the_one_that_knows() -> void:
	# The other half of the same criterion, and the reason the guard above is not
	# satisfied by deleting the knowledge entirely: somebody must map a state onto
	# a point and a speed, and it has to be findable.
	assert_true(
		SourceScanner.code_contains(DIRECTOR, "func _speed_for"),
		"nothing turns a brain state into a speed — steering cannot be dumb on its own"
	)
	assert_true(
		SourceScanner.code_contains(DIRECTOR, "func _goal_for"),
		"nothing turns a brain state into a destination"
	)
