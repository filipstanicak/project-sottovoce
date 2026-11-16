## **THE ART PASS, AS CODE.** ADR-0026, ART_BIBLE §4 and §7. CLIENT ONLY.
##
## The owner asked on 2026-11-16 for the game to stop looking like a greybox. The
## corpus allows exactly one way of doing that without a single downloaded file:
## IP_GUARDRAILS §4 says placeholder art is *primitives or procedural*, and this is
## procedural taken as far as it goes. The generated map scene stays what it was —
## boxes, colliders, a navmesh — and when a client loads it, this node repaints
## those boxes and builds what stands on and round them.
##
## **THE GAME UNDERNEATH IS UNCHANGED, AND THAT IS THE DESIGN.** ART_BIBLE §7.1
## lists what art may not change: surface heights, navmesh boundaries, anchors,
## sightlines, widths. Nothing here adds a collider or moves a box, the server
## never loads this file, and `test_the_dressing_changes_no_geometry.gd` holds it
## to that. The district plays exactly as the greybox did and looks like a place.
##
## **AND IT DRESSES ANY MAP**, because it reads the scene and not a layout table:
## the sandbox gets the same plaster and the same water.
class_name DistrictDressing
extends Node3D

var palette: WorldPalette = null

## What the last `dress` built, for a test or a probe to measure.
var triangles := 0


## Repaint `map_root`'s greybox and build the district's detail under this node.
func dress(map_root: Node3D) -> void:
	if palette == null:
		palette = WorldPalette.new()
	var survey := DressingSurvey.new(map_root)
	if survey.parts.is_empty():
		return
	var materials := WorldMaterials.new(palette)
	var batch := detail_of(survey, materials, palette, self)
	batch.commit(self, materials, "Detail")
	var far := MeshBatch.new()
	BackdropDresser.new(survey, far, palette).dress()
	var skyline := far.commit(self, materials, "Backdrop")
	if skyline != null:
		# Past the shadow's reach, and a shadow nobody could see.
		skyline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	triangles = batch.triangle_count() + far.triangle_count()


## Everything built on and round the district itself, as one batch — and the
## greybox repainted on the way. Apart from `dress` so a test can measure the
## parts before they become a mesh. The water is added under `host`.
static func detail_of(
	survey: DressingSurvey, materials: WorldMaterials, colours: WorldPalette, host: Node3D
) -> MeshBatch:
	var batch := MeshBatch.new()
	GroundDresser.new(survey, batch, materials, colours).dress(host)
	FacadeDresser.new(survey, batch, materials, colours).dress()
	PropDresser.new(survey, batch, materials, colours).dress()
	WatersideDresser.new(survey, batch, colours).dress()
	return batch
