## ARCHITECTURE GUARD — do not weaken. See test/arch/README.md.
##
## **EVERY `.uid` HAS THE `.gd` IT NAMES.**
##
## Godot writes one `.uid` per script on import. Delete the script without it and
## the `.uid` survives as a tracked file pointing at nothing — invisible, because
## nothing reads it and no test looks.
##
## Two ways this repo has produced them, both in one session:
##
## 1. `git add -A` after a throwaway diagnostic script. The `.gd` was deleted,
##    the `.uid` the import had just written was not, and it went in with the
##    commit. Twice.
## 2. A move that took the scripts and left their metadata. The four autoloads
##    lived under `scripts/core/` before `scripts/autoload/` existed; their old
##    `.uid` files sat in the tree for two milestones afterwards.
##
## Harmless individually. The reason to guard it is that a stale `.uid` is a
## resource identity Godot may still resolve, so the failure mode when one is
## eventually reused is a scene silently loading the wrong script — and by then
## nobody remembers the file was orphaned.
extends GutTest

## Vendored. GUT ships its own orphan and it is not ours to tidy.
const SKIP_PREFIX := "res://addons/"

const ROOTS: Array[String] = ["res://scripts", "res://test", "res://tools", "res://scenes"]


func _uid_files() -> PackedStringArray:
	var out: PackedStringArray = []
	for root: String in ROOTS:
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
		elif name.ends_with(".uid") and not full.begins_with(SKIP_PREFIX):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func test_uid_files_exist_to_be_checked() -> void:
	# Guards the guard. Every script in the project has one, so an empty list
	# means the walk is broken rather than the tree being clean — the shape this
	# project has now found in four separate places.
	assert_gt(_uid_files().size(), 50, "found almost no .uid files — the scan is broken")


func test_every_uid_still_has_its_script() -> void:
	var orphans: PackedStringArray = []
	for uid: String in _uid_files():
		if not FileAccess.file_exists(uid.trim_suffix(".uid")):
			orphans.append(uid)
	assert_eq(
		orphans.size(),
		0,
		(
			"A .uid names a script that is not there. Delete it — and if a script\n"
			+ "moved, take its .uid with it rather than letting the import write a\n"
			+ "second one at the new path.\n  "
			+ "\n  ".join(orphans)
		)
	)
