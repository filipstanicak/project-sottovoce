## Client composition root: map, HUD and the results/input handoff. CLIENT ONLY.
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

var results: ResultsRoot

@onready var map_host: Node3D = $World/Map


func _ready() -> void:
	var chosen := (
		LaunchConfig.active.map_name if LaunchConfig.active != null else MapCatalogue.DEFAULT
	)
	var geometry := (load(MapCatalogue.client_scene(chosen)) as PackedScene).instantiate()
	map_host.add_child(geometry)
	_dress_the_district(geometry)
	results = ResultsRoot.new()
	results.name = "Results"
	results.palette = ($Hud as HudRoot).palette
	results.active_changed.connect(_results_active)
	results.skip_requested.connect(Net.requests.send_skip_results)
	add_child(results)
	($Hud/HudBridge as HudBridge).results_time_changed.connect(results.results_time_changed)
	_open_the_wardrobe()
	_lay_the_blend_cues(chosen)


## **THE ART PASS** (ADR-0026): the greybox repainted and the district built on it.
## Here and not in the map scene, because the server loads that scene's collision
## twin and must never learn what a window is. Not on a headless client either: a
## bot has no screen.
func _dress_the_district(geometry: Node3D) -> void:
	if not DisplayGate.draws():
		return
	var dressing := DistrictDressing.new()
	dressing.name = "Dressing"
	map_host.add_child(dressing)
	dressing.dress(geometry)
	_direct_the_figures(geometry)


## **WHERE FIGURES SIT AND LEAN, AND WHAT THE PLAYERS AMONG THEM ARE DOING**
## (US-0109). Under the same gate as the district: a client with no screen
## animates nobody.
func _direct_the_figures(geometry: Node3D) -> void:
	var chosen := (
		LaunchConfig.active.map_name if LaunchConfig.active != null else MapCatalogue.DEFAULT
	)
	var map := load(MapCatalogue.data_path(chosen)) as MapData
	FigurePlaces.set_from(DressingSurvey.new(geometry), map.static_props if map != null else [])
	var director := FigureDirector.new()
	director.name = "FigureDirector"
	add_child(director)
	director.bind(
		get_node_or_null("LocalPawnDriver") as LocalPawnDriver,
		get_node_or_null("World/PawnLocal/PersonaVisuals") as PersonaBody,
		get_node_or_null("ClientNet/RemotePawns") as RemotePawns
	)


## **ONE NODE DECIDES WHAT EVERY FIGURE WEARS** — crowd, other players and this one
## (US-0101). Composition, so it lives with the rest of the root's wiring.
func _open_the_wardrobe() -> void:
	var wardrobe := Wardrobe.new()
	wardrobe.name = "Wardrobe"
	wardrobe.palette = ($Hud as HudRoot).palette
	add_child(wardrobe)
	wardrobe.bind(
		get_node_or_null("ClientNet/NpcView") as NpcView,
		get_node_or_null("ClientNet/RemotePawns") as RemotePawns,
		get_node_or_null("World/PawnLocal/PersonaVisuals") as PersonaBody
	)


## **THE NET UNDER EVERY GROUP AND BENCH, AND THE GREY OVER ONE'S OWN** (US-0107).
## In the world rather than the HUD: the net lies on the ground and the grey is on
## bodies, and both are drawn over the same figures `Wardrobe` dresses.
func _lay_the_blend_cues(chosen: String) -> void:
	var cues := BlendCues.new()
	cues.name = "BlendCues"
	cues.palette = ($Hud as HudRoot).palette
	$World.add_child(cues)
	var map := load(MapCatalogue.data_path(chosen)) as MapData
	cues.bind(
		get_node_or_null("ClientNet/NpcView") as NpcView,
		get_node_or_null("World/PawnLocal") as Node3D,
		get_node_or_null("World/PawnLocal/PersonaVisuals") as PersonaBody,
		map.static_props if map != null else []
	)


func _results_active(active: bool) -> void:
	var hud := get_node_or_null("Hud") as HudRoot
	var sampler := get_node_or_null("InputSampler") as InputSampler
	if hud != null:
		hud.visible = not active
	if sampler != null:
		sampler.set_results_active(active)
