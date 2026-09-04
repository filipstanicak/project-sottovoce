## **THE CLIENT'S BOOT, AND THE ONLY THING IT DOES IS OPEN THE MAP.** CLIENT ONLY.
##
## Added 2026-09-04 with `MAP-SANDBOX`. `client_root.tscn` was the one root scene
## with no script at all, and the district was an `ext_resource` inside it — which
## is fine while there is one map and a silent trap the moment there are two: the
## `MapData` a rule reads came from `LaunchConfig`, and the geometry a player walks
## on came from whatever the scene happened to embed. Those two disagreeing is not
## a crash; it is a client drawing one place and standing in another.
##
## **IT IS THE MESHED VARIANT HERE**, where the server loads collision only.
## TDD-12 §3.
##
## **LOADED IN `_ready`, NOT DEFERRED.** Every `_ready` in the tree completes before
## the first physics frame, so the pawn never gets a frame with no floor under it —
## and `LocalPawnDriver._ready()` runs *before* this one (children are readied
## first), which is safe only because it reads spawn points from `MapData` on disk
## rather than from anything in the scene.
extends Node

@onready var map_host: Node3D = $World/Map


func _ready() -> void:
	var chosen := (
		LaunchConfig.active.map_name if LaunchConfig.active != null else MapCatalogue.DEFAULT
	)
	var geometry := (load(MapCatalogue.client_scene(chosen)) as PackedScene).instantiate()
	map_host.add_child(geometry)
