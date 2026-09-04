## **EVERY MAP'S THREE ARTEFACTS EXIST AND ARE THE RIGHT THREE.** `MapCatalogue`,
## added 2026-09-04 with `MAP-SANDBOX`.
##
## **A MISSING PATH HERE IS SILENT AT RUNTIME**, which is why it is checked as a
## file rather than trusted as a string: `load()` on a path that is not there
## returns null, and a null `MapData` is a server whose spawn points are all
## `Vector3.ZERO` and whose crowd stacks at the origin. That reads as a level
## defect, not as a typo in a dictionary.
extends GutTest


func test_the_default_is_a_map_in_the_catalogue() -> void:
	assert_true(MapCatalogue.has(MapCatalogue.DEFAULT), "the default map is not in the catalogue")


func test_every_map_has_three_artefacts_that_exist() -> void:
	var missing: PackedStringArray = []
	for map_name: String in MapCatalogue.names():
		for path: String in [
			MapCatalogue.data_path(map_name),
			MapCatalogue.client_scene(map_name),
			MapCatalogue.server_scene(map_name),
		]:
			if not ResourceLoader.exists(path):
				missing.append("%s -> %s" % [map_name, path])
	assert_eq(missing.size(), 0, "a catalogued artefact is not on disk:\n" + "\n".join(missing))


## **THE THREE PATHS MUST DIFFER**, and the failure this catches is a copy-paste
## row where the server scene points at the client's: a dedicated server would then
## load a `MeshInstance3D` per wall for nothing, and a client would draw a world
## with no meshes in it. Both run.
func test_no_map_serves_the_same_file_for_two_roles() -> void:
	for map_name: String in MapCatalogue.names():
		var paths := [
			MapCatalogue.data_path(map_name),
			MapCatalogue.client_scene(map_name),
			MapCatalogue.server_scene(map_name),
		]
		var seen := {}
		for path: String in paths:
			seen[path] = true
		assert_eq(seen.size(), 3, "%s serves one file for two roles" % map_name)


func test_every_map_has_its_own_id() -> void:
	var ids := {}
	for map_name: String in MapCatalogue.names():
		var id := MapCatalogue.id_of(map_name)
		assert_true(String(id).begins_with("MAP-"), "%s has no MAP- id" % map_name)
		ids[id] = true
	assert_eq(ids.size(), MapCatalogue.names().size(), "two maps share an id")


## **AN UNKNOWN NAME FALLS BACK RATHER THAN ANSWERING EMPTY.** `LaunchConfig`
## refuses the typo at boot; this is the second line, for every caller that never
## went through `boot.gd` — which is every test that instantiates a root scene.
func test_an_unknown_name_answers_with_the_default() -> void:
	assert_false(MapCatalogue.has("nope"))
	assert_eq(MapCatalogue.data_path("nope"), MapCatalogue.data_path(MapCatalogue.DEFAULT))
	assert_eq(MapCatalogue.client_scene("nope"), MapCatalogue.client_scene(MapCatalogue.DEFAULT))


## The district ships and the bench does not. Asserted rather than commented,
## because `test_sandbox_is_debug_only.gd` reads this flag to decide what to scan.
func test_the_district_ships_and_the_bench_does_not() -> void:
	assert_false(MapCatalogue.is_debug_only("vetraio"), "the shipped map is marked debug-only")
	assert_true(MapCatalogue.is_debug_only("sandbox"), "the bench is not marked debug-only")
