## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## `project.godot` still DECLARES the settings the project depends on.
##
## Why this exists, concretely: opening the Godot editor rewrites project.godot
## and DELETES every key whose value happens to match the current engine default,
## along with every comment in the file. On 2026-08-05 that silently removed
## `rendering_method="forward_plus"`, `physics_ticks_per_second=60`, the whole
## `[navigation]` and `[physics]` sections, and the rationale comments.
##
## Nothing broke, because those values ARE today's defaults. That is exactly the
## problem: an implicit default is a decision nobody made, and the day an engine
## release changes one, the game changes with it and no diff explains why.
## US-0001's acceptance criteria name two of these settings by value.
##
## If this fails after an editor session, `git checkout project.godot`.
extends GutTest

const PROJECT := "res://project.godot"

## Key -> why it must stay explicit. Every one of these was deleted by the editor
## at least once, because every one of them matches an engine default.
const REQUIRED := {
	'renderer/rendering_method="forward_plus"':
	"US-0001 AC; the renderer is a tech constraint, not a preference",
	"common/physics_ticks_per_second=60":
	"US-0001 AC; the pawn integrates at 60 Hz once per InputCommand (TDD-03 §1)",
	"common/max_physics_steps_per_frame=8": "bounds catch-up after a frame spike",
	"common/physics_interpolation=true":
	"US-0045: without it every position is drawn ~2.7 times and the pawn visibly steps",
	"3d/default_gravity=9.8": "a changed default would alter every drop and stagger",
	"3d/default_cell_size=0.25": "navmesh resolution; a coarser bake moves NPC paths",
	"gdscript/warnings/untyped_declaration=2":
	"CODING_STANDARDS: everything is typed, no exceptions",
}

## Sections the editor has dropped wholesale when every key in them was a default.
const REQUIRED_SECTIONS: Array[String] = [
	"[autoload]",
	"[layer_names]",
	"[navigation]",
	"[physics]",
	"[rendering]",
	"[debug]",
]


func _text() -> String:
	var text := SourceScanner.read(PROJECT)
	assert_ne(text, "", "project.godot is missing or unreadable")
	return text


func test_every_pinned_setting_is_still_declared() -> void:
	var text := _text()
	var missing: PackedStringArray = []
	for key: String in REQUIRED:
		if not text.contains(key):
			missing.append("%s — %s" % [key, REQUIRED[key]])
	missing.sort()
	assert_eq(
		missing.size(),
		0,
		(
			"project.godot no longer declares a pinned setting.\n"
			+ "The Godot editor deletes keys matching an engine default when it saves.\n"
			+ "Recover with: git checkout project.godot\n"
			+ "\n".join(missing)
		)
	)


func test_every_required_section_is_still_present() -> void:
	var text := _text()
	var missing: PackedStringArray = []
	for section: String in REQUIRED_SECTIONS:
		if not text.contains(section):
			missing.append(section)
	assert_eq(
		missing.size(),
		0,
		(
			"project.godot lost a whole section — the editor drops one when every key\n"
			+ "in it matches a default. Recover with: git checkout project.godot\n"
			+ "\n".join(missing)
		)
	)


func test_the_four_collision_layers_are_named() -> void:
	# An unnamed layer is a number in an inspector. Traversal probes mask WORLD
	# only, and that is a determinism requirement: a probe that could hit an
	# interpolated body resolves differently on client and server.
	var text := _text()
	var missing: PackedStringArray = []
	for i: int in 4:
		if not text.contains("3d_physics/layer_%d=" % (i + 1)):
			missing.append("layer_%d" % (i + 1))
	assert_eq(missing.size(), 0, "unnamed collision layers: " + ", ".join(missing))


func test_the_rationale_comments_survived() -> void:
	# The editor strips ALL comments. These carry the reasoning that stops the
	# next person undoing a deliberate choice — the autoload ORDER in particular,
	# which is load-bearing and looks arbitrary.
	var text := _text()
	var missing: PackedStringArray = []
	for fragment: String in ["Project Sottovoce", "ADR-0011", "EIGHT", "determinism"]:
		if not text.contains(fragment):
			missing.append(fragment)
	assert_eq(
		missing.size(),
		0,
		(
			"project.godot lost its rationale comments — the editor strips every one.\n"
			+ "Recover with: git checkout project.godot\n"
			+ "missing: "
			+ ", ".join(missing)
		)
	)


func test_the_check_would_notice_a_deletion() -> void:
	# Guards the guard: `contains` must actually be able to fail.
	assert_false(
		_text().contains('renderer/rendering_method="mobile"'),
		"the scan matches things that are not there"
	)
	assert_true(REQUIRED.size() >= 6, "the pinned-setting list was emptied")
