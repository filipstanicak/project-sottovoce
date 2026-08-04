## Shared source-scanning helper for the architecture guards.
##
## These guards read source as TEXT rather than executing it. That is what makes
## them fast (the whole suite is a few hundred file reads) and what lets them
## assert things a runtime test cannot — a layer violation compiles and runs
## perfectly right up until the headless server build fails.
class_name SourceScanner
extends RefCounted

## Line comments and string literals are stripped before matching, so a rule
## is never tripped by its own documentation. Every guard below documents a rule
## in a comment, and without this they would all fail on themselves.
const _COMMENT := "#"


## Every .gd file under `root`, recursively. Paths are res:// relative.
static func gd_files(root: String) -> PackedStringArray:
	var out: PackedStringArray = []
	_walk(root, out)
	return out


static func _walk(path: String, out: PackedStringArray) -> void:
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
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


## File contents, or "" if unreadable.
static func read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Code lines only: comments stripped, string literals blanked, blanks dropped.
## Returns [line_number, code] pairs so failures can cite a real line.
static func code_lines(path: String) -> Array:
	var out: Array = []
	var raw := read(path).split("\n")
	for i: int in raw.size():
		var line := _strip(raw[i])
		if line.strip_edges() != "":
			out.append([i + 1, line])
	return out


## Blank out string literals, then drop everything after the first '#'.
## Order matters: a '#' inside a string must not start a comment.
static func _strip(line: String) -> String:
	var out := ""
	var in_str := false
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if in_str:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				in_str = false
			out += " "
		elif c == '"' or c == "'":
			in_str = true
			quote = c
			out += " "
		elif c == _COMMENT:
			break
		else:
			out += c
		i += 1
	return out


## True if `needle` appears in any code line (comments and strings excluded).
static func code_contains(path: String, needle: String) -> bool:
	for pair: Array in code_lines(path):
		if String(pair[1]).contains(needle):
			return true
	return false


## Lines where `needle` appears in code, as "path:line" strings.
static func find(path: String, needle: String) -> PackedStringArray:
	var hits: PackedStringArray = []
	for pair: Array in code_lines(path):
		if String(pair[1]).contains(needle):
			hits.append("%s:%d" % [path, int(pair[0])])
	return hits
