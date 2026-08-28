## **THE COMPASS'S VIEW MODEL.** UI_UX_SPEC §3, US-0072. CLIENT ONLY.
##
## It holds four numbers, advances a phase, and answers the three questions the
## widget asks: which way, how fast, how full. **`CompassWidget` reads nothing
## else**, which is what makes §3.3's prohibitions enforceable rather than a note.
##
## **THE PROTOCOL PREVENTS LEAKS; THIS CLASS PREVENTS INVENTION.** The server
## already refuses to send a position, an exact distance or an unwobbled bearing.
## What it cannot prevent is a client *deriving* something it was not given, and
## §3.3 lists four ways to do that. Each is designed out here by there being
## nowhere to put the intermediate value:
##
## - **No world position.** There is no `Vector3` field and no method that takes
##   one. Distance arrives as a bucket and stays a bucket.
## - **No wobble.** The bearing is used exactly as received. A client-side wobble
##   would be a second lie, uncorrelated with the server's, and two players
##   standing together could average it away.
## - **No extrapolation.** `advance()` moves the *phase* and never the bearing, so
##   the cone can never contain information newer than the simulation.
## - **No numeric distance.** `period()` is the only consumer of the bucket, and
##   it returns seconds.
##
## **THE PHASE ADVANCES AT DISPLAY RATE AND THE PERIOD COMES FROM THE 30 Hz
## AUTHORITATIVE DISTANCE**, so a 144 Hz and a 60 Hz client see the same *cadence*
## smoothed differently. That is §3.2's sentence and it is the whole reason the
## phase lives here rather than being derived from the tick.
class_name CompassVm
extends RefCounted

## Emitted the instant the phase wraps. **Audio subscribes to `EventBus`, not to
## this** — the signal is here so the widget can flash the cone on the same frame
## without a round trip through the bus.
signal pulsed

## The wobbled **world** bearing, radians, exactly as received. **Never written by
## anything but a snapshot** — the drawn angle is a separate value that eases
## toward this one and can only ever be behind it.
var bearing: float = 0.0:
	set(value):
		bearing = value
		if not _settled:
			_drawn_bearing = value

## `Quantise.BUCKET_STEP` units, or `CompassBoard.NO_CONTRACT`.
var bucket: int = CompassBoard.NO_CONTRACT

## The lock arc, 0.0 to 1.0.
var lock: float = 0.0

## The camera's yaw, pushed in by the HUD root each frame. **The view model does
## not fetch it**: a `get_node` to the rig from here is the coupling never-do #7
## forbids one level down, and the same argument applies one level up.
var camera_yaw: float = 0.0

var _phase: float = 0.0

## What is actually drawn. Both ease toward the authoritative values over
## `TUN-NET-INTERP-BUFFER` — see `advance`.
var _drawn_bearing: float = 0.0
var _drawn_halfwidth: float = 0.0
var _settled := false


## Is there anything to point at? During `TUN-CONTRACT-REASSIGN-DELAY` a killer has
## no announced contract, and the Compass goes dark rather than pointing due +Z at
## nobody — which is what makes the breath a breath.
func has_contract() -> bool:
	return bucket != CompassBoard.NO_CONTRACT


## Where the cone is drawn, **camera-relative**. UI_UX_SPEC §3.3: a north-relative
## compass is a map, and never-do #12 forbids one of those.
## **`angle_between`, NOT `wrap_angle`.** Both describe the same direction, and
## only one is signed: `wrap_angle` returns `[0, TAU)`, so a contract a quarter
## turn to the left comes back as 3π/2 rather than −π/2. Nothing *draws*
## differently for it — but every comparison a test or a later reader makes
## against a signed expectation does, and `CompassMath.angle_between`'s own
## docstring names this exact use: *"what a client uses to turn a world bearing
## into a camera-relative arc."*
func cone_radians() -> float:
	return CompassMath.angle_between(camera_yaw, _drawn_bearing)


## **HOW WIDE THE ARC IS DRAWN, IN RADIANS OF HALF-WIDTH.** The second proximity
## channel: the arc widens as the contract closes and becomes the whole ring at
## `CompassMath.full_ring_distance`, at which point it has stopped saying *which
## way* and says only *here, somewhere* — which is the moment the design wants the
## player looking at faces instead of at the instrument.
##
## **THE SAME BUCKET THE PULSE USES**, so the two channels can never disagree, and
## nothing here holds a distance in metres for longer than the call (§3.3).
func cone_halfwidth() -> float:
	if not has_contract():
		return deg_to_rad(Tuning.compass.cone_halfwidth)
	if not _settled:
		return deg_to_rad(authoritative_halfwidth())
	return deg_to_rad(_drawn_halfwidth)


## The width the current bucket asks for, in degrees, before any easing.
func authoritative_halfwidth() -> float:
	if not has_contract():
		return Tuning.compass.cone_halfwidth
	return CompassMath.cone_halfwidth_for(Quantise.bucket_to_distance(bucket), Tuning.compass)


## Seconds per pulse, from the authoritative bucket. `CompassMath.period_for` is
## Core and is asserted against TUNABLES §4.2's twelve sampled rows.
func period() -> float:
	if not has_contract():
		return 0.0
	return CompassMath.period_for(Quantise.bucket_to_distance(bucket), Tuning.compass)


## Advance the phase by a **display** frame. Returns true on the frame it wrapped.
##
## **THE WRAP IS A LOOP, NOT A SUBTRACTION.** A frame long enough to cross two
## periods — an alt-tab, a shader compile — would otherwise leave the phase above
## 1.0 and the ring drawn inside out until the next frame caught up.
func advance(delta: float) -> bool:
	_ease(delta)
	var seconds := period()
	if seconds <= 0.0:
		_phase = 0.0
		return false
	_phase += delta / seconds
	if _phase < 1.0:
		return false
	while _phase >= 1.0:
		_phase -= 1.0
	pulsed.emit()
	return true


## **THE DRAWN ANGLES CHASE THE AUTHORITATIVE ONES, AND CAN ONLY EVER BE BEHIND.**
##
## The bearing arrives at `TUN-COMPASS-UPDATE-RATE` 30 Hz **quantised to a byte** —
## `Quantise.YAW_STEP` is 1.41 degrees, which is 2.4 px at the cone's outer rim.
## Drawn raw at 144 Hz that is a staircase: five identical frames, then a jump.
## Worse, the wobble alone moves the bearing about 8 deg/s, so at slow angular
## rates the value sits still for five ticks and then twitches. **Reported from the
## controls as "not as smooth as I would like, but I wouldn't say it stutters"**,
## which is exactly what a quantisation staircase looks like as opposed to a
## dropped frame.
##
## **THIS IS NOT PREDICTION AND THE DISTINCTION IS THE WHOLE POINT.** UI_UX_SPEC
## §3.3 forbids the Compass containing information *newer* than the simulation. An
## exponential chase is strictly *older*: it starts behind and converges, it never
## leads, and it never overshoots. Same sentence as TDD-04's most important one —
## **the simulation snaps; the visual blends.**
##
## **THE TIME CONSTANT IS `TUN-NET-INTERP-BUFFER`, NOT A NEW NUMBER.** Every other
## remote thing on screen is already drawn that far behind, so the cone and the
## body it points at move on one clock. At 100 ms the steady-state lag is the rate
## times the constant: sprinting sideways at 25 m is 15 deg/s, so 1.5 degrees
## against a half-width of 104 — under a fiftieth of the arc, and four hundred
## times smaller than the thing it is smoothing away is visible.
func _ease(delta: float) -> void:
	# **LOSING THE CONTRACT UNSETTLES THE CHASE**, so the next bearing is adopted
	# rather than swept toward. `TUN-CONTRACT-REASSIGN-DELAY` guarantees a window of
	# `NO_CONTRACT` between two contracts, and a cone that slid from the old bearing
	# to the new one would draw every angle in between — a bearing that was never
	# true, reading as the contract sprinting around you.
	if not has_contract():
		_settled = false
		return
	if not _settled:
		_drawn_bearing = bearing
		_drawn_halfwidth = authoritative_halfwidth()
		_settled = true
		return
	var tau := maxf(Tuning.net.interp_buffer / 1000.0, 0.001)
	var alpha := 1.0 - exp(-maxf(delta, 0.0) / tau)
	_drawn_bearing = CompassMath.wrap_angle(
		_drawn_bearing + CompassMath.angle_between(_drawn_bearing, bearing) * alpha
	)
	_drawn_halfwidth += (authoritative_halfwidth() - _drawn_halfwidth) * alpha


func phase() -> float:
	return _phase


## Scale 1.0 → 1.35, **ease-out**: the ring leaves fast.
func ring_scale() -> float:
	return 1.0 + 0.35 * _ease_out_cubic(_phase)


## Alpha 0.9 → 0.0, **ease-in**: the ring fades slow.
##
## **THE TWO EASINGS ARE OPPOSITE ON PURPOSE AND IT IS THE ONE THING IN THIS FILE
## MOST LIKELY TO BE "TIDIED".** Together they make the *onset* the sharp event,
## and onset is what peripheral vision detects. Matched easings read as a throb,
## and a throb is much harder to judge a cadence from — which would quietly delete
## the channel the whole instrument is built on. UI_UX_SPEC §3.2.
func ring_alpha() -> float:
	return 0.9 * (1.0 - _ease_in_quad(_phase))


## A brief flash on each pulse, so the beat is visible to a player looking at the
## cone rather than at the ring.
func cone_brightness() -> float:
	return 1.0 + 0.25 * (1.0 - _ease_out_quint(_phase))


static func _ease_out_cubic(t: float) -> float:
	var u := 1.0 - t
	return 1.0 - u * u * u


static func _ease_in_quad(t: float) -> float:
	return t * t


static func _ease_out_quint(t: float) -> float:
	var u := 1.0 - t
	return 1.0 - u * u * u * u * u
