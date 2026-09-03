## **NO WIDGET NAMES A COLOUR LITERAL.** UI_UX_SPEC §7, US-0073.
##
## §7 has said since M0 that *"all colour comes from a `Palette` resource injected
## into every widget"*, and named **this file** as the enforcement. **It did not
## exist**, and neither did `Palette` — trap 14's shape in a bible section, and the
## reason `CompassWidget` shipped four literals in US-0072.
##
## **THE POINT IS SWAPPABILITY, NOT TIDINESS.** §7.1 needs four palettes, and the
## monochrome one is the *verification* palette for the other three: it is how the
## team checks that no channel depends on hue. A widget holding a literal cannot be
## verified against any of them, because there is nothing to swap — and the failure
## is silent, since the literal looks perfectly fine in the palette it was authored
## against.
extends GutTest

const HUD := "res://scripts/presentation/hud"

## **A SECOND ROOT, ADDED WITH THE DIRECTORY RATHER THAN AFTER IT.** `Palette` grew
## past the HUD when `CinderfallView` needed the cloud's colour, and a guard that
## only knows about the old home is one a new home quietly escapes.
const VFX := "res://scripts/presentation/vfx"

## `Color(` is the constructor and `Color.` reaches a named constant like
## `Color.RED`. Both bypass the palette; both are the thing §7 forbids.
const FORBIDDEN: Array[String] = ["Color(", "Color."]

## `Palette` is the one file where colour is *allowed* to be named — it is the
## resource every other file reads from. **Nothing else is exempt**, including a
## widget rebuilding a palette colour at a different alpha: that names no channel
## of its own, but a reader cannot tell it from a real literal at a glance and
## neither can this guard, so it lives on `Palette` as `with_alpha()` instead.
const ALLOWED: Array[String] = ["palette.gd"]


func test_the_scan_reaches_the_hud_at_all() -> void:
	# **THE VACUOUS-SUCCESS GUARD.** Every assertion below passes over an empty
	# file list, which is exactly how `ip-guard` and `asset-inventory` reported
	# clean over zero of 739 files for two milestones.
	var files := _scanned()
	assert_gt(
		files.size(), 5, "the colour scan found %d files, so it is not scanning" % files.size()
	)


func test_no_widget_names_a_colour() -> void:
	var violations: PackedStringArray = []
	for path: String in _scanned():
		if _is_allowed(path):
			continue
		# **`code_lines` RETURNS `[line_number, text]` PAIRS, NOT STRINGS**, and it
		# strips comments and string literals — which is what makes it the right
		# scanner here: a colour named in a docstring is documentation, not a draw.
		for row: Array in SourceScanner.code_lines(path):
			var line := str(row[1])
			for needle: String in FORBIDDEN:
				if line.contains(needle):
					violations.append(
						"%s:%d %s" % [path.get_file(), int(row[0]), line.strip_edges()]
					)
	assert_eq(
		violations.size(),
		0,
		(
			"a widget names a colour instead of reading the palette (UI_UX_SPEC §7):\n"
			+ "\n".join(violations)
		)
	)


func test_the_palette_is_where_colour_lives() -> void:
	# The counterfactual. Without it the guard above passes just as happily in a
	# HUD that has no colours anywhere — which is what an over-eager "fix" to a
	# violation would produce.
	assert_true(
		SourceScanner.code_contains("res://scripts/presentation/hud/palette.gd", "Color("),
		"Palette names no colours, so every widget reading it is reading nothing"
	)


func test_every_widget_actually_holds_a_palette() -> void:
	# **A WIDGET THAT NEVER READS THE PALETTE PASSES THE GUARD ABOVE PERFECTLY.**
	# Drawing nothing, or drawing with an engine default, satisfies "names no
	# colour literal" while defeating the rule entirely.
	var checked := 0
	for path: String in _scanned():
		if _is_allowed(path) or not path.ends_with("_widget.gd"):
			continue
		checked += 1
		assert_true(
			SourceScanner.code_contains(path, "palette"),
			"%s draws without a palette" % path.get_file()
		)
	assert_gte(checked, 4, "only %d widgets were checked; expected at least four" % checked)


## Every file the palette rule covers: the HUD, and the world effects a player has
## to read.
func _scanned() -> PackedStringArray:
	var out := SourceScanner.gd_files(HUD)
	out.append_array(SourceScanner.gd_files(VFX))
	return out


func _is_allowed(path: String) -> bool:
	for name: String in ALLOWED:
		if path.ends_with(name):
			return true
	return false
