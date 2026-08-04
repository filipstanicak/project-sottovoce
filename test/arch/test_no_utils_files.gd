## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## Unnamed grab-bag files never shrink. "utils.gd" starts at 20 lines of
## genuinely shared helpers and becomes 400 lines nobody can safely delete
## from, because its name asserts nothing about what belongs in it.
##
## Why review misses this: every individual addition to utils.gd is reasonable.
extends GutTest

const BANNED_NAMES: Array[String] = [
	"utils", "helpers", "common", "misc", "shared", "stuff", "manager"
]

const ROOTS: Array[String] = ["res://scripts", "res://test", "res://tools"]


func test_no_grab_bag_files() -> void:
	var violations: PackedStringArray = []
	for root: String in ROOTS:
		for path: String in SourceScanner.gd_files(root):
			var stem := path.get_file().get_basename().to_lower()
			for banned: String in BANNED_NAMES:
				if stem == banned or stem.ends_with("_" + banned):
					violations.append(path)
	assert_eq(
		violations.size(),
		0,
		(
			"Grab-bag filename. Name the responsibility instead: SuspicionMath, "
			+ "CompassMath, Locomotion, CrowdDirector.\n"
			+ "\n".join(violations)
		)
	)
