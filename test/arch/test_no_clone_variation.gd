## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **NO PER-INSTANCE VARIATION ON A CLONE. EVER.** GDD-03 §6.3 rule 6, US-0046.
##
## No tint, no accessory shuffle, no scale jitter, no random material. The rule is
## sharper than it first looks, and it cuts both ways:
##
## - Any variation **the player cannot also have** is a discriminator. A crowd of
##   subtly different Lucerna and one identical-to-the-template player is a crowd
##   with the player circled in it.
## - Any variation **the player *can* have** is a cosmetic system, which
##   `SCOPE_FENCE` OUT #3 rules out for exactly this reason: cosmetics are an
##   anonymity leak by construction.
##
## So there is no version of "a little variety in the crowd" that is safe, and the
## instinct to add some is strong — a crowd of ninety identical figures looks
## wrong to an artist, and looks *right* to this game.
##
## Why review misses this: one line of `randf()` in a clone's `_ready()` is
## invisible in a diff, obviously improves the look, and breaks nothing that any
## other test measures.
extends GutTest

## The files that build what a clone looks like.
const CLONE_VISUALS: Array[String] = [
	"res://scripts/presentation/pawn_visuals/persona_body.gd",
	"res://scripts/presentation/pawn_visuals/greybox_body.gd",
]

## Randomness of any kind, and the properties it would be applied to.
const FORBIDDEN: Array[String] = [
	"randf",
	"randi",
	"RandomNumberGenerator",
	"rand_range",
	"pick_random",
	"shuffle",
]


func test_the_files_exist_to_be_scanned() -> void:
	# Guards the guard: a moved file reads as an empty string, and an empty string
	# contains no randomness at all.
	for path: String in CLONE_VISUALS:
		assert_gt(SourceScanner.read(path).length(), 500, "%s is missing or tiny" % path)


func test_nothing_that_draws_a_clone_is_random() -> void:
	var offenders: PackedStringArray = []
	for path: String in CLONE_VISUALS:
		for needle: String in FORBIDDEN:
			for hit: String in SourceScanner.find(path, needle):
				offenders.append("%s -> %s" % [needle, hit])
	assert_eq(
		offenders.size(),
		0,
		(
			"a clone's appearance is randomised:\n"
			+ "\n".join(offenders)
			+ "\nGDD-03 §6.3 rule 6. Any variation the player cannot have is a "
			+ "discriminator; any variation they can have is a cosmetic system."
		)
	)


func test_a_persona_is_chosen_rather_than_rolled() -> void:
	# The other half. Rule 4 requires personas to be derived from `match_seed`
	# **identically on every peer**, which `CrowdRoster` does — so a body that
	# picked its own persona would give two clients different cities, and the
	# symptom is a player saying "I saw a Lucerna by the furnace" and being wrong.
	assert_true(
		SourceScanner.code_contains(
			"res://scripts/presentation/pawn_visuals/persona_body.gd", "@export var persona"
		),
		"PersonaBody does not take its persona from outside — it must be told, not choose"
	)


func test_the_check_can_actually_fail() -> void:
	# Falsification: the shortest real violation an artist would write.
	var planted := "\tmaterial.albedo_color = BODY_COLOUR.lightened(randf() * 0.1)\n"
	var caught := false
	for needle: String in FORBIDDEN:
		if planted.contains(needle):
			caught = true
	assert_true(caught, "the forbidden list would not catch a tint jitter")
