## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **NO SCENE MAY NAME A SCRIPT UNDER `scripts/debug/`.**
##
## The three release presets in `export_presets.cfg` exclude `scripts/debug/*`.
## A `.tscn` carrying an `ext_resource` that points there exports a scene
## referencing a file that is not in the package — and the failure does not
## appear in the editor, in any test, or in a debug export. It appears when
## somebody runs the release build, which on this project is a playtest with six
## humans in the room.
##
## Debug tools attach at RUNTIME instead, behind `OS.has_feature("debug")` and an
## existence check. `LocalPawnDriver._attach_feel_readout` is the pattern.
##
## US-0024 nearly added the feel readout as a scene node. This guard is what made
## it safe to add at all.
extends GutTest

const SCENE_ROOTS: Array[String] = ["res://scenes", "res://data", "res://addons/gut"]
const DEBUG_PREFIX := "res://scripts/debug/"


func _scenes() -> PackedStringArray:
	var out: PackedStringArray = []
	for root: String in SCENE_ROOTS:
		_walk(root, out)
	return out


func _walk(path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_walk(full, out)
		elif name.ends_with(".tscn") or name.ends_with(".tres"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func test_scenes_exist_to_be_scanned() -> void:
	# Guards the guard. An empty list would make the assertion below vacuous, and
	# this project has now found three documents asserting checks that ran over
	# nothing at all.
	assert_gt(_scenes().size(), 3, "found almost no scenes — the scan is broken, not clean")


func test_no_scene_or_resource_points_into_scripts_debug() -> void:
	var offenders: PackedStringArray = []
	for path: String in _scenes():
		if SourceScanner.read(path).contains(DEBUG_PREFIX):
			offenders.append(path)
	assert_eq(
		offenders.size(),
		0,
		(
			"A scene references scripts/debug/, which the release presets strip.\n"
			+ "The export will ship a dangling reference and fail only in a real\n"
			+ "release build. Attach the tool at runtime instead — see\n"
			+ "LocalPawnDriver._attach_feel_readout.\n  "
			+ "\n  ".join(offenders)
		)
	)


func test_the_release_presets_still_strip_debug() -> void:
	# The other half of the reason. If a preset ever stopped excluding the folder,
	# the rule above would be enforcing a constraint that no longer applies — and
	# would be quietly deleted by the next person who hit it.
	var presets := SourceScanner.read("res://export_presets.cfg")
	assert_string_contains(presets, "scripts/debug/*")
	assert_gt(
		presets.count("scripts/debug/*"),
		2,
		"fewer presets strip scripts/debug/ than the three releases that should"
	)
