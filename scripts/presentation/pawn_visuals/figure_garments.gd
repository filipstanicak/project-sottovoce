## **WHAT MAKES A FIGURE A PERSONA.** ART_BIBLE §1.1 and §6.1, US-0109. CLIENT ONLY.
##
## Each persona is one silhouette claim, and the pieces here are what makes it: the
## Vetraio's broad yoke and apron, the Cantatrice's bell skirt and coiled
## headdress, the Lucerna's hood and the pole that breaks the head line, the
## Pesatore's round middle, flat cap and ledger. **The claim is still the art
## bible's**: tellable apart at 40 m in solid black — and `test_persona_silhouettes`
## holds the four to it.
##
## The five fillers are dressed here too, in homespun, as trades no player has.
## **Nothing above a filler's head stands as tall as the pole**: that line belongs
## to the Lucerna.
class_name FigureGarments
extends RefCounted


## Hang `rig.shape.id`'s own pieces on the body. The undressed figure has none.
static func dress(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	match rig.shape.id:
		Ids.PERSONA_VETRAIO:
			_vetraio(rig, paint)
		Ids.PERSONA_CANTATRICE:
			_cantatrice(rig, paint)
		Ids.PERSONA_LUCERNA:
			_lucerna(rig, paint)
		Ids.PERSONA_PESATORE:
			_pesatore(rig, paint)
		&"":
			pass
		_:
			FigureTrades.dress(rig, paint)


## Where the top of the head is, measured from the neck joint.
static func crown_y(rig: FigureRig) -> float:
	return rig.shape.height - (rig.shape.shoulder_y() + 0.05 * rig.shape.scale())


static func rise(rig: FigureRig) -> float:
	return rig.shape.shoulder_y() - rig.shape.hip_y()


## Short hair, for a head with nothing else on it.
static func hair(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	var r := rig.shape.head_radius()
	var cap := rig.part(
		rig.neck,
		"Hair",
		FigureParts.ball(r * 1.02),
		Vector3(0.0, crown_y(rig) - r * 1.02, -0.018),
		paint.hair
	)
	cap.scale = Vector3(0.94, 1.0, 1.0)


## **Vetraio**, `LOW_BROAD`: the widest thing in the district at shoulder height,
## a leather apron down the front, goggles pushed up on the brow.
static func _vetraio(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	var shape := rig.shape
	var yoke := Vector3(shape.shoulder_half() * 2.0 + 0.1, 0.15, shape.depth() * 2.0 + 0.04)
	rig.part(
		rig.spine,
		"Shoulders",
		FigureParts.block(yoke),
		Vector3(0.0, rise(rig) - 0.04, 0.0),
		paint.cloth
	)
	rig.part(
		rig.spine,
		"Apron",
		FigureParts.block(Vector3(0.36, 0.74, 0.03)),
		Vector3(0.0, 0.1, shape.depth() + 0.03),
		FigureParts.LEATHER
	)
	hair(rig, paint)
	var brow := Vector3(0.0, crown_y(rig) - shape.head_radius() * 0.2, shape.head_radius() * 0.55)
	rig.part(rig.neck, "Goggles", FigureParts.block(Vector3(0.2, 0.05, 0.07)), brow, paint.prop)


## **Cantatrice**, `FLOOR_TRIANGLE`: a bell skirt that is the widest thing at the
## ground, and hair coiled high above the head.
static func _cantatrice(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	var shape := rig.shape
	var drop := shape.hip_y() - 0.03
	# **1.5x THE COLLIDER, NOT 2x**: a skirt that overhangs the capsule too far is
	# a shape a hunter cannot walk through standing where they can.
	rig.part(
		rig.hips,
		"Skirt",
		FigureParts.drum(shape.hip_half() + 0.1, PersonaBody.FALLBACK_RADIUS * 1.5, drop),
		Vector3(0.0, -drop * 0.5 + 0.03, 0.0),
		paint.cloth
	)
	hair(rig, paint)
	var r := shape.head_radius()
	var top := crown_y(rig)
	rig.part(
		rig.neck, "Crown", FigureParts.ball(r * 0.95), Vector3(0.0, top + 0.03, -0.01), paint.prop
	)
	rig.part(
		rig.neck, "Coil", FigureParts.ball(r * 0.72), Vector3(0.0, top + 0.14, -0.01), paint.prop
	)
	rig.part(
		rig.neck, "Knot", FigureParts.ball(r * 0.5), Vector3(0.0, top + 0.23, -0.01), paint.prop
	)


## **Lucerna**, `TALL_THIN`: hooded and cloaked, and carrying the wick-pole that
## is the one thing in the district to stand above every head.
static func _lucerna(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	var shape := rig.shape
	var length := 0.95 * shape.scale()
	var cloak := rig.part(
		rig.spine,
		"Cloak",
		FigureParts.drum(shape.shoulder_half() + 0.035, shape.shoulder_half() + 0.085, length),
		Vector3(0.0, rise(rig) - length * 0.5 + 0.03, -0.02),
		paint.cloth
	)
	cloak.scale = Vector3(1.0, 1.0, 0.8)
	var r := shape.head_radius()
	var hood := Vector3(0.0, crown_y(rig) - r * 1.02, -0.04)
	rig.part(rig.neck, "Hood", FigureParts.ball(r * 1.2), hood, paint.cloth)
	# **CARRIED, NOT FLOATING**: from hand height to 0.9 m over the head.
	var hand := 0.95
	var top := shape.height + 0.9
	var grip := Vector3(-(shape.shoulder_half() + 0.11), (hand + top) * 0.5 - shape.hip_y(), 0.14)
	rig.part(rig.spine, "Pole", FigureParts.drum(0.022, 0.022, top - hand), grip, paint.prop)
	var hook := Vector3(grip.x, top - shape.hip_y() - 0.04, grip.z + 0.06)
	rig.part(rig.spine, "PoleHook", FigureParts.block(Vector3(0.03, 0.03, 0.14)), hook, paint.prop)


## **Pesatore**, `ROUND_MID`: even all the way down and round in the middle, a
## flat cap, a ledger under the left arm.
static func _pesatore(rig: FigureRig, paint: FigureTailor.Paint) -> void:
	var shape := rig.shape
	var belly := rig.part(
		rig.spine,
		"Belly",
		FigureParts.ball(shape.shoulder_half() * 0.98),
		Vector3(0.0, 0.17, shape.depth() * 0.35),
		paint.cloth
	)
	belly.scale = Vector3(1.0, 1.05, 0.95)
	hair(rig, paint)
	var top := crown_y(rig)
	rig.part(
		rig.neck, "Cap", FigureParts.drum(0.13, 0.14, 0.05), Vector3(0.0, top, 0.0), paint.prop
	)
	rig.part(
		rig.neck,
		"Brim",
		FigureParts.drum(0.1, 0.1, 0.02),
		Vector3(0.0, top - 0.03, 0.09),
		paint.prop
	)
	var tucked := Vector3(shape.shoulder_half() + 0.05, 0.2, 0.05)
	rig.part(
		rig.spine,
		"Ledger",
		FigureParts.block(Vector3(0.07, 0.3, 0.24)),
		tucked,
		FigureParts.LEATHER
	)
