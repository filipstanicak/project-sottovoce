## **WHICH MAPS EXIST AND WHERE EACH ONE'S THREE ARTEFACTS LIVE.** PURE.
##
## Added 2026-09-04 with `MAP-SANDBOX`. Before it there was one map and every path
## to it was a literal in whatever needed it — `server_root.gd`'s `const MAP`, an
## `ext_resource` in each root scene, and a `load()` inside `LocalPawnDriver`. Four
## places, and adding a second map to three of them and forgetting the fourth is a
## client that draws one district and spawns at another's coordinates.
##
## **A MAP IS THREE ARTEFACTS, NOT ONE**, and the split is TDD-12 §3's: the client
## scene carries meshes, the server scene carries collision and the navmesh region
## and nothing else, and the `MapData` resource carries everything a *rule* is
## written against. Serving the wrong one of the three is silent — a server holding
## meshes wastes memory, a client holding no meshes draws an empty world.
class_name MapCatalogue

## The map a launch gets when it asks for nothing.
const DEFAULT := "vetraio"

## **`MAP-SANDBOX` IS DEBUG-ONLY AND ITS ROW SAYS SO.** It is a bench for
## reproducing defects in ten seconds rather than ten minutes, it has no zones,
## circuits or theatre spaces, and no shipped match may open it. The export presets
## exclude it and `test_sandbox_is_debug_only.gd` refuses a reference to it from
## anything that is not a tool, a test or `MapCatalogue` itself.
const MAPS := {
	"vetraio":
	{
		"id": Ids.MAP_VETRAIO,
		"data": "res://data/maps/map_vetraio.tres",
		"client": "res://scenes/map/map_vetraio.tscn",
		"server": "res://scenes/map/map_vetraio_collision.tscn",
		"debug_only": false,
	},
	"sandbox":
	{
		"id": Ids.MAP_SANDBOX,
		"data": "res://data/maps/map_sandbox.tres",
		"client": "res://scenes/map/map_sandbox.tscn",
		"server": "res://scenes/map/map_sandbox_collision.tscn",
		"debug_only": true,
	},
}


static func has(map_name: String) -> bool:
	return MAPS.has(map_name)


static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for key: String in MAPS:
		out.append(key)
	out.sort()
	return out


## **AN UNKNOWN NAME FALLS BACK TO THE DEFAULT RATHER THAN RETURNING EMPTY.** A
## `load("")` answers null, and a null map is a server whose crowd stacks at the
## origin and whose spawn points are all `Vector3.ZERO` — a level-shaped failure
## from a typo. `LaunchConfig.problems()` refuses the typo at boot; this is the
## second line of defence for every caller that never went through `boot.gd`,
## which is every test that instantiates a root scene.
static func _row(map_name: String) -> Dictionary:
	return MAPS.get(map_name, MAPS[DEFAULT])


static func data_path(map_name: String) -> String:
	return str(_row(map_name)["data"])


static func client_scene(map_name: String) -> String:
	return str(_row(map_name)["client"])


static func server_scene(map_name: String) -> String:
	return str(_row(map_name)["server"])


static func id_of(map_name: String) -> StringName:
	return _row(map_name)["id"]


static func is_debug_only(map_name: String) -> bool:
	return bool(_row(map_name)["debug_only"])
