## **THE BENCH MUST NOT REACH A PLAYER.** `MAP-SANDBOX`, 2026-09-04.
##
## It is a 40 m courtyard with four spawn points 15 m apart, no zones, no
## processions and a `SpawnRules` fallback that fires on every respawn. As a place
## to reproduce a defect it is exactly right; as something a shipped build could
## open it is a broken match.
##
## **THE EXPORT FILTER IS THE REAL DEFENCE AND IT IS A STRING IN A CONFIG FILE.**
## Nothing else in the project checks it, and a preset edited later — or a sixth
## preset added — drops the exclusion in silence. This is what says so out loud.
##
## **AND NOTHING IN THE SHIPPED CODE MAY NAME IT.** A system that special-cased the
## sandbox would be a rule that behaves differently on the bench, which is the one
## thing a bench must never do: what you reproduce on it would not be what happens
## in a match. Only the catalogue may know it exists.
extends GutTest

const PRESETS := "res://export_presets.cfg"

## `MapCatalogue` names it because that is its whole job. `LaunchConfig` reaches it
## through the catalogue, never by name. Tools and tests are outside the shipped
## game by construction — `tools/*` and `test/*` are excluded from every preset.
const MAY_NAME_IT: Array[String] = [
	"res://scripts/core/map_catalogue.gd",
	"res://scripts/core/sandbox_layout.gd",
	# Generated, and it declares every ID harvested from `docs/`. It cannot not
	# name the map; what matters is that naming `Ids.MAP_SANDBOX` from anywhere
	# else still trips this guard, because that reference reads as "sandbox" too.
	"res://scripts/core/ids.gd",
]


func test_every_export_preset_excludes_the_sandbox() -> void:
	var file := FileAccess.open(PRESETS, FileAccess.READ)
	assert_not_null(file, "export_presets.cfg is unreadable")
	var filters: PackedStringArray = []
	for line: String in file.get_as_text().split("\n"):
		if line.begins_with("exclude_filter="):
			filters.append(line)
	file.close()

	# **THE PREMISE.** A run that found no presets would pass the loop below
	# perfectly, which is this project's most-repeated failure shape.
	assert_gt(filters.size(), 0, "no export preset has an exclude_filter at all")

	var leaky: PackedStringArray = []
	for line: String in filters:
		if not line.contains("map_sandbox"):
			leaky.append(line.substr(0, 60))
	assert_eq(leaky.size(), 0, "a preset would ship MAP-SANDBOX:\n" + "\n".join(leaky))


## The layout table itself must not ship either — it is 120 lines of geometry no
## match will ever build.
func test_every_export_preset_excludes_the_layout() -> void:
	var file := FileAccess.open(PRESETS, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var presets := text.split("exclude_filter=").size() - 1
	assert_eq(
		text.split("sandbox_layout.gd").size() - 1, presets, "a preset would ship SandboxLayout"
	)


## Nothing under `scripts/` may name the sandbox except the two files that exist to
## know about it. Falsified by planting the string in any system.
func test_no_shipped_script_names_the_sandbox() -> void:
	var offenders: PackedStringArray = []
	var scanned := 0
	for path: String in SourceScanner.gd_files("res://scripts"):
		scanned += 1
		if MAY_NAME_IT.has(path):
			continue
		# **CASE-INSENSITIVE, AND THE FIRST VERSION WAS NOT.** `code_contains` matches
		# exactly, so a scan for "sandbox" walked straight past `SandboxLayout` — the
		# identifier every offender would actually use. The guard passed over the one
		# file that names it. Trap 3's shape inside a guard, again.
		if _names_it(path):
			offenders.append(path)

	assert_gt(scanned, 50, "the scan found almost no scripts — it is checking nothing")
	assert_eq(
		offenders.size(),
		0,
		(
			"a shipped script names the sandbox, so a rule may behave differently on it:\n"
			+ "\n".join(offenders)
		)
	)


## Case-insensitive over stripped code lines. `scripts/debug/` is exempt by
## construction rather than by listing: it is excluded from all three release
## presets, so it is already outside the shipped game, and the district overlay has
## to know which map it is drawing or it draws the wrong one.
func _names_it(path: String) -> bool:
	if path.begins_with("res://scripts/debug/"):
		return false
	for pair: Array in SourceScanner.code_lines(path):
		if String(pair[1]).to_lower().contains("sandbox"):
			return true
	return false
