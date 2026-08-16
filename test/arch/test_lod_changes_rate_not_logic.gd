## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **LOD CHANGES THE RATE, NEVER THE LOGIC.** ADR-0003, TDD-08 §4.1, US-0045.
##
## An NPC at 60 m must run the *same* state machine as one at 2 m, less often. A
## crowd whose behaviour changed with observer distance would be a crowd that
## **lies** — and the crowd is an information channel a player is expected to read
## correctly. Worse, it would hand players a way to judge distance without
## looking: "that one is twitching, so somebody is near it".
##
## The rule is enforceable by reading, because the only way to make behaviour
## depend on distance is to *ask* about distance. `NpcBrain` may not know what a
## band is, what a player is, or how far away anything is.
##
## Why review misses this: the shortest fix for any far-crowd artefact is a
## distance check inside the brain, it works, and nothing else in the project
## would ever complain.
extends GutTest

const BRAIN := "res://scripts/systems/crowd/npc_brain.gd"
const LOD := "res://scripts/systems/crowd/crowd_lod.gd"

## Everything that would mean the brain had learned where it is.
const FORBIDDEN: Array[String] = [
	"CrowdLod",
	"Band",
	"distance",
	"distance_to",
	"length_squared",
	"players",
	"pawns",
	"global_position",
]


func test_the_brain_exists_to_be_scanned() -> void:
	# Guards the guard: a renamed file reads as an empty string, and an empty
	# string contains no distance checks at all.
	assert_gt(SourceScanner.read(BRAIN).length(), 1000, "npc_brain.gd is missing or tiny")


func test_the_brain_cannot_tell_how_far_away_anybody_is() -> void:
	var offenders: PackedStringArray = []
	for needle: String in FORBIDDEN:
		for hit: String in SourceScanner.find(BRAIN, needle):
			offenders.append("%s -> %s" % [needle, hit])
	assert_eq(
		offenders.size(),
		0,
		(
			"NpcBrain can see distance:\n"
			+ "\n".join(offenders)
			+ "\nADR-0003: LOD changes the rate, never the logic. A crowd that behaved "
			+ "differently far away would be a crowd that lies."
		)
	)


func test_the_stride_reaches_the_brain_so_a_band_does_not_change_a_duration() -> void:
	# The other half of "rate, not logic", and the one a distance scan cannot see.
	# A brain stepped every fifteenth tick and decremented by one would turn an
	# 8–25 s idle pause into 120–375 s — a behaviour change with a rate change's
	# name on it.
	assert_true(
		SourceScanner.code_contains(BRAIN, "stride"),
		"NpcBrain.step() takes no stride — a banded brain's timers would run 15x slow"
	)
	assert_true(
		SourceScanner.code_contains("res://scripts/systems/crowd/crowd_director.gd", "stride_of("),
		"the director steps brains without telling them how many ticks they stand for"
	)


func test_the_check_can_actually_fail() -> void:
	# Falsification: the scan must see the shortest real violation somebody would
	# write to fix a far-crowd artefact.
	var planted := "\tif ctx.position.distance_to(player) > 45.0:\n\t\treturn\n"
	var caught := false
	for needle: String in FORBIDDEN:
		if planted.contains(needle):
			caught = true
	assert_true(caught, "the forbidden list would not catch the obvious violation")
