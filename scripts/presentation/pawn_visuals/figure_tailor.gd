## **THE BODY EVERY FIGURE HAS, AND THE COLOURS IT IS IN.** US-0109. CLIENT ONLY.
##
## Trunk, head, two arms, two legs, hung on a `FigureRig`. What makes one figure a
## Lucerna and another a porter is `FigureGarments`; this is the part they share.
##
## **THE CLOTHING WEARS THE IDENTITY HUE AND NOTHING ELSE DOES** (ART_BIBLE §3):
## the trunk and sleeves take the persona's colour, and skin, hose, shoes and hair
## stay in the neutrals, so a hue on a figure always means its persona.
class_name FigureTailor
extends RefCounted


## What each part of one figure is painted in.
class Paint:
	var cloth: Color
	var legs: Color
	var hose: Color
	var skin: Color
	var shoe: Color
	var hair: Color
	var prop: Color


## The paints of a figure `id` whose clothing is `cloth`. The undressed figure is
## the two greybox neutrals all over: it claims no persona and no trade.
static func paint_for(id: StringName, cloth: Color) -> Paint:
	var paint := Paint.new()
	paint.cloth = cloth
	paint.prop = PersonaBody.MARKER_COLOUR
	if id == &"":
		paint.legs = cloth
		paint.hose = cloth
		paint.skin = cloth
		paint.shoe = PersonaBody.MARKER_COLOUR
		paint.hair = PersonaBody.MARKER_COLOUR
		return paint
	paint.legs = FigureParts.DARK
	paint.hose = FigureParts.HOSE
	paint.skin = FigureParts.SKIN
	paint.shoe = FigureParts.LEATHER
	paint.hair = FigureParts.HAIR
	return paint


## Hang the body on `rig`.
static func clothe(rig: FigureRig, paint: Paint) -> void:
	_trunk(rig, paint)
	_head(rig, paint)
	for side: int in 2:
		_arm(rig, side, paint)
		_leg(rig, side, paint)


static func _trunk(rig: FigureRig, paint: Paint) -> void:
	var shape := rig.shape
	var k := shape.scale()
	var rise := shape.shoulder_y() - shape.hip_y()
	var radius := shape.shoulder_half() * 0.82
	var body := rig.part(
		rig.spine,
		"Body",
		FigureParts.limb(radius, rise + radius * 1.1),
		Vector3(0.0, rise * 0.5, 0.0),
		paint.cloth
	)
	body.scale = Vector3(1.0, 1.0, shape.depth() / radius)
	var seat := shape.hip_half() + 0.075 * k
	var pelvis := rig.part(rig.hips, "Pelvis", FigureParts.ball(seat), Vector3.ZERO, paint.legs)
	pelvis.scale = Vector3(1.0, 0.8, shape.depth() / seat * 1.05)


static func _head(rig: FigureRig, paint: Paint) -> void:
	var shape := rig.shape
	var k := shape.scale()
	var neck_y := shape.shoulder_y() + 0.05 * k
	rig.part(rig.neck, "Throat", FigureParts.limb(0.045 * k, 0.13 * k), Vector3.ZERO, paint.skin)
	var at := Vector3(0.0, shape.head_y() - neck_y, 0.012)
	var head := rig.part(rig.neck, "Head", FigureParts.ball(shape.head_radius()), at, paint.skin)
	head.scale = Vector3(0.9, 1.1, 0.96)
	# The one feature a head needs: which way it is looking.
	var nose := Vector3(0.0, at.y - 0.01, shape.head_radius() * 0.95)
	rig.part(rig.neck, "Nose", FigureParts.block(Vector3(0.03, 0.045, 0.04) * k), nose, paint.skin)
	for side: int in 2:
		var eye := Vector3(
			FigureRig.side_sign(side) * 0.038 * k, at.y + 0.02, shape.head_radius() * 0.86
		)
		rig.part(rig.neck, "Eye%d" % side, FigureParts.ball(0.014 * k), eye, paint.hair)


static func _arm(rig: FigureRig, side: int, paint: Paint) -> void:
	var shape := rig.shape
	var k := shape.scale()
	var upper := shape.upper_arm()
	var lower := shape.forearm()
	rig.part(
		rig.shoulders[side],
		"Sleeve",
		FigureParts.limb(0.052 * k, upper + 0.05),
		Vector3(0.0, -upper * 0.5, 0.0),
		paint.cloth
	)
	rig.part(
		rig.elbows[side],
		"Forearm",
		FigureParts.limb(0.044 * k, lower + 0.03),
		Vector3(0.0, -lower * 0.5, 0.0),
		paint.cloth
	)
	rig.part(
		rig.hands[side], "Hand", FigureParts.ball(0.047 * k), Vector3(0.0, -0.02, 0.0), paint.skin
	)


static func _leg(rig: FigureRig, side: int, paint: Paint) -> void:
	var shape := rig.shape
	var k := shape.scale()
	var thigh := shape.thigh()
	var shin := shape.shin()
	rig.part(
		rig.thighs[side],
		"Thigh",
		FigureParts.limb(0.078 * k, thigh + 0.06),
		Vector3(0.0, -thigh * 0.5, 0.0),
		paint.legs
	)
	rig.part(
		rig.knees[side],
		"Shin",
		FigureParts.limb(0.058 * k, shin + 0.03),
		Vector3(0.0, -shin * 0.5, 0.0),
		paint.hose
	)
	var foot := Vector3(0.09 * k, FigureShape.FOOT_HEIGHT, 0.25 * k)
	var under := Vector3(0.0, -shin - FigureShape.FOOT_HEIGHT * 0.5, 0.06 * k)
	rig.part(rig.knees[side], "Foot", FigureParts.block(foot), under, paint.shoe)
