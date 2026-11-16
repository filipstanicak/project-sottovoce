## **THE FIVE FIGURES NO PLAYER CAN BE.** ART_BIBLE §1.3, US-0109. CLIENT ONLY.
##
## The crowd is ninety figures and four of every five persona shapes are clones
## (§10 question 1). The fillers are what stops it reading as a line-up: a child,
## a fishwife, a mendicant, a porter and a water-carrier, each a silhouette that
## is *definitively not a player* — the child above all, the scale anchor that
## trains the eye to check size before shape.
##
## They wear homespun, never a persona's hue, and each is built one way: a filler
## could vary freely (§2.1) and does not need to.
class_name FigureTrades
extends RefCounted


## The homespun a filler `id` wears.
static func cloth_of(id: StringName) -> Color:
	var at := CrowdRoster.ARCHETYPES.find(id)
	return FigureParts.HOMESPUN[maxi(at, 0) % FigureParts.HOMESPUN.size()]


static func dress(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	match rig.shape.id:
		Ids.ARCH_FISHWIFE:
			_fishwife(rig, paint)
		Ids.ARCH_MENDICANT:
			_mendicant(rig, paint)
		Ids.ARCH_PORTER:
			_porter(rig, paint)
		Ids.ARCH_WATERCARRIER:
			_watercarrier(rig, paint)
		_:
			FigureGarments.hair(rig, paint)


## A straight skirt, narrower than the Cantatrice's bell, a headscarf, a basket
## on the hip.
static func _fishwife(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	var shape := rig.shape
	var drop := shape.hip_y() - 0.03
	rig.part(
		rig.hips,
		"Skirt",
		FigureParts.drum(shape.hip_half() + 0.1, 0.3, drop),
		Vector3(0.0, -drop * 0.5 + 0.03, 0.0),
		paint.cloth
	)
	var r := shape.head_radius()
	var scarf := Vector3(0.0, FigureGarments.crown_y(rig) - r * 0.95, -0.03)
	rig.part(rig.neck, "Scarf", FigureParts.ball(r * 1.12), scarf, FigureParts.LINEN)
	var hip := Vector3(shape.hip_half() + 0.2, 0.1, 0.05)
	rig.part(rig.hips, "Basket", FigureParts.drum(0.2, 0.15, 0.2), hip, FigureParts.TIMBER)


## Stooped under a broad hat and a short ragged cape.
static func _mendicant(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	var shape := rig.shape
	var top := FigureGarments.crown_y(rig)
	rig.part(
		rig.neck,
		"Hat",
		FigureParts.drum(0.25, 0.27, 0.03),
		Vector3(0.0, top - 0.02, 0.0),
		paint.prop
	)
	rig.part(
		rig.neck,
		"HatCrown",
		FigureParts.drum(0.09, 0.11, 0.09),
		Vector3(0.0, top + 0.03, 0.0),
		paint.prop
	)
	var length := 0.5 * shape.scale()
	rig.part(
		rig.spine,
		"Cape",
		FigureParts.drum(shape.shoulder_half() + 0.03, shape.shoulder_half() + 0.12, length),
		Vector3(0.0, FigureGarments.rise(rig) - length * 0.5 + 0.03, -0.01),
		FigureParts.DARK
	)


## A crate strapped to the back, low enough that it breaks no head line.
static func _porter(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	var shape := rig.shape
	FigureGarments.hair(rig, paint)
	var back := Vector3(0.0, FigureGarments.rise(rig) * 0.55, -(shape.depth() + 0.2))
	rig.part(
		rig.spine, "Crate", FigureParts.block(Vector3(0.46, 0.4, 0.36)), back, FigureParts.TIMBER
	)


## A yoke across the shoulders and a pail hanging from each end of it.
static func _watercarrier(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	FigureGarments.hair(rig, paint)
	var rise := FigureGarments.rise(rig)
	rig.part(
		rig.spine,
		"Yoke",
		FigureParts.block(Vector3(1.2, 0.05, 0.07)),
		Vector3(0.0, rise + 0.04, -0.05),
		FigureParts.TIMBER
	)
	for side: int in 2:
		var x := FigureRig.side_sign(side) * 0.56
		rig.part(
			rig.spine,
			"Rope%d" % side,
			FigureParts.block(Vector3(0.015, 0.55, 0.015)),
			Vector3(x, rise - 0.23, -0.05),
			paint.prop
		)
		rig.part(
			rig.spine,
			"Pail%d" % side,
			FigureParts.drum(0.13, 0.11, 0.24),
			Vector3(x, rise - 0.6, -0.05),
			FigureParts.TIMBER
		)
