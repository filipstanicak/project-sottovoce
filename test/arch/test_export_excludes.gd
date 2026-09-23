## ARCHITECTURE GUARD — export filters are executable layer boundaries. Parsing
## every preset prevents a new platform from silently shipping tests or the bench.
extends GutTest

const PRESETS := "res://export_presets.cfg"
const EXPECTED_NAMES: Array[String] = [
	"Server (Linux headless)",
	"Client (Windows release)",
	"Client (Linux release)",
	"Client (debug)",
	"Client (debug, Linux)",
]
const ALL_EXCLUDE: Array[String] = [
	".mcp.json",
	"scripts/core/sandbox_layout.gd",
	"scenes/map/map_sandbox*",
	"data/maps/map_sandbox*",
	"addons/gut/*",
	"test/*",
	"tools/*",
	"docs/*",
]
const SERVER_EXCLUDES: Array[String] = [
	"scripts/presentation/*",
	"scripts/mirrors/*",
	"scenes/ui/*",
	"scripts/debug/*",
	"data/tuning/local/*",
]
const CLIENT_EXCLUDES: Array[String] = ["scripts/server/*"]
const RELEASE_CLIENT_EXCLUDES: Array[String] = ["scripts/debug/*", "data/tuning/local/*"]


func test_all_five_presets_hold_their_layer_boundaries() -> void:
	var config := ConfigFile.new()
	assert_eq(config.load(PRESETS), OK, "export_presets.cfg is unreadable")
	var seen: Array[String] = []
	for section: String in config.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var name: String = config.get_value(section, "name", "")
		var excludes := _filter_entries(config.get_value(section, "exclude_filter", ""))
		seen.append(name)
		_assert_contains_all(name, excludes, ALL_EXCLUDE)
		if name == "Server (Linux headless)":
			_assert_contains_all(name, excludes, SERVER_EXCLUDES)
		else:
			_assert_contains_all(name, excludes, CLIENT_EXCLUDES)
			if "release" in name:
				_assert_contains_all(name, excludes, RELEASE_CLIENT_EXCLUDES)
			else:
				assert_false(excludes.has("scripts/debug/*"), "%s strips its debug tools" % name)
	seen.sort()
	var expected := EXPECTED_NAMES.duplicate()
	expected.sort()
	assert_eq(seen, expected, "export preset inventory changed without updating the guard")


func _filter_entries(value: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for entry: String in value.split(",", false):
		result.append(entry.strip_edges())
	return result


func _assert_contains_all(name: String, actual: PackedStringArray, required: Array[String]) -> void:
	for path: String in required:
		assert_true(actual.has(path), "%s would ship %s" % [name, path])
