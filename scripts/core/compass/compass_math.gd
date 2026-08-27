## **THE COMPASS CURVE AND THE WOBBLING CONE.** GDD-03 §8.2–8.3, TUNABLES §4.2,
## US-0057. PURE.
##
## The Compass gives **direction** and **proximity** to your contract, never
## position. It is the only positional channel in the game and its imprecision is
## authored (design law 6): a bearing with a deterministic drift on it, and a
## pulse period that says *nearer* without ever saying *how far*.
##
## **THE RECIPROCAL EXPONENT IS THE WHOLE TRICK.** `pow(t, 1/2.2)` is flat far
## away and steep close in, so the felt experience is a long level approach
## followed by a sudden sense of imminence. The rate at 15 m is 41 % faster than
## at 40 m; at 1 m it is triple. **That asymmetry is the design requirement
## expressed as a curve**, and GDD-03 §8.2 calls it the single most carefully
## tuned number in the game — which is why `test_compass_curve.gd` asserts every
## row of the sampled table rather than the formula's shape.
class_name CompassMath
extends RefCounted


## Seconds between pulses at `distance` metres. GDD-03 §8.2.
##
## Beyond `TUN-COMPASS-RANGE-MAX` the period is simply the maximum: the contract
## is "somewhere over there" and the Compass says no more. **Clamped rather than
## extrapolated**, because an ever-slowing pulse would leak the difference between
## 60 m and 110 m, which is most of the district.
static func period_for(distance: float, t: CompassTuning) -> float:
	var normalised := clampf(distance / maxf(t.range_max, 0.001), 0.0, 1.0)
	var shaped := pow(normalised, 1.0 / maxf(t.pulse_exp, 0.001))
	return t.pulse_min + (t.pulse_max - t.pulse_min) * shaped


## Pulses per second — the read-out, not the specification. The period is what
## TUNABLES tunes and what the client schedules against; the rate is what the
## design argument is written in.
static func rate_for(distance: float, t: CompassTuning) -> float:
	var period := period_for(distance, t)
	return 0.0 if period <= 0.0 else 1.0 / period


## **HOW WIDE THE ARC IS DRAWN AT `distance`, IN DEGREES OF HALF-WIDTH.**
## GDD-03 §8.3, UI_UX_SPEC §3.1.
##
## **THE ARC COVERS GROUND, NOT AN ANGLE.** A fixed angular cone *looks* like
## uncertainty and is not: the ground it spans shrinks in proportion to the
## distance. `TUN-COMPASS-CONE-HALFWIDTH` 12 degrees spans 25 m at maximum range
## and **1.06 m at the 2.85 m a kill lands from** — narrower than two people
## standing side by side, so it picks one. The instrument that TUNABLES describes
## as telling you *"which part of the plaza, never which body"* would have named
## the body, for free, at the only moment that matters.
##
## **TWO ANCHORS, AND THE CURVE BETWEEN THEM IS DERIVED.** The far end is
## `TUN-COMPASS-CONE-HALFWIDTH` at `TUN-COMPASS-RANGE-MAX`; the near end is a whole
## ring at `TUN-COMPASS-CONE-FULL-RADIUS`, which is invariant 33's equality with
## `TUN-SUSPICION-OPEN-RADIUS` — the radius this game already uses for *the space
## you are standing in*. The exponent is whatever passes through both, so **no
## third number exists to disagree with the first two**.
##
## **AND THE SHAPE IS THE PULSE CURVE'S OWN**: flat over the long approach, steep
## at the end. 13 degrees at 55 m, 27 at 30, 44 at 20, 99 at 10, a full ring at 6.
## GDD-03 §8.2's *"long, flat approach followed by a sudden sense of imminence"*,
## said a second time in a second channel.
##
## **THE FIRST CUT USED ONE ANCHOR AND CLOSED THE RING AT 4.0 m**, derived from the
## half-width alone. It was judged too tight at the controls — you had to be
## standing on your contract — which is what the second anchor exists to fix.
static func cone_halfwidth_for(distance: float, t: CompassTuning) -> float:
	if distance <= 0.0:
		return 180.0
	var full := full_ring_distance(t)
	return clampf(180.0 * pow(full / distance, _cone_falloff(t)), t.cone_halfwidth, 180.0)


## The distance at which the arc becomes the whole ring, and the Compass stops
## saying *which way*. Invariant 33 pins it to `TUN-SUSPICION-OPEN-RADIUS` and
## outside the validated kill reach.
static func full_ring_distance(t: CompassTuning) -> float:
	return t.cone_full_radius


## The exponent that carries the curve from one anchor to the other. **Computed,
## never stored** — see the note above. Guarded rather than trusted: a profile
## with the ring at or past maximum range has no curve to describe, and answering
## 1.0 there degrades to the plain one-over-distance law rather than to a NaN.
static func _cone_falloff(t: CompassTuning) -> float:
	var span := t.cone_full_radius / maxf(t.range_max, 0.001)
	if span <= 0.0 or span >= 1.0 or t.cone_halfwidth <= 0.0:
		return 1.0
	return log(t.cone_halfwidth / 180.0) / log(span)


## World bearing from `from` to `to`, in radians, matching the pawn's own yaw
## convention: **yaw 0 faces +Z and increases toward +X**, which is
## `ProbeLayout.forward`'s `Vector3(sin(yaw), 0, cos(yaw))` inverted.
##
## **HORIZONTAL, LIKE EVERY OTHER COMPASS QUANTITY.** GDD-03 §8.5 keeps elevation
## off this channel entirely — there is no z component anywhere in the snapshot's
## compass block, so a contract on a roof and one in the street below read the
## same. That is the rule living in the arithmetic as well as in the format.
static func bearing_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


## Horizontal distance, for the same reason.
static func distance_to(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()


## **THE CONE'S DRIFT, DETERMINISTIC AND LEARNABLE.** GDD-03 §8.3.
##
## A slow sine of amplitude `TUN-COMPASS-CONE-WOBBLE` and period
## `TUN-COMPASS-CONE-WOBBLE-PERIOD`, phase-seeded from the contract so it is a
## **stable property of one hunt** rather than a per-frame lie. A player can learn
## "the cone is drifting left of true" and compensate.
##
## **RANDOM JITTER WOULD BE A DELETED CHANNEL.** Design law 6: where the game is
## imprecise, the imprecision is designed, bounded, deterministic and *learnable*.
## Noise nobody can learn is indistinguishable from a narrower cone plus a lie.
##
## **SEEDED FROM THE CONTRACT AND THE TICK, AND NOT FROM THE MATCH SEED.** Mixing
## the seed in was considered and rejected: the wobble exists to be learned inside
## one hunt, so per-match variation buys a player nothing and adds an input to
## reason about. US-0057's fourth criterion names the two inputs.
static func wobble_radians(contract: int, tick: int, t: CompassTuning) -> float:
	if t.cone_wobble <= 0.0 or t.cone_wobble_period <= 0.0:
		return 0.0
	var seconds := float(tick) / maxf(Tuning.net.server_tick, 1.0)
	var angle := TAU * (seconds / t.cone_wobble_period) + phase_of(contract)
	return deg_to_rad(t.cone_wobble) * sin(angle)


## Where in its cycle this contract's wobble starts, in radians of the sine.
##
## **MIXED, NEVER USED RAW.** Godot hands out peer ids as 32-bit randoms, but they
## are *consecutive* in tests and in any future slot scheme — and adjacent seeds
## taken raw produce adjacent phases, so two hunts would drift in step and the
## drift would read as a property of the world rather than of the hunt.
## `hash()` is Godot's own integer avalanche; `test_compass_cone.gd` asserts the
## spread rather than trusting it.
static func phase_of(contract: int) -> float:
	return fmod(float(absi(hash(contract))), TAU)


## The bearing the hunter is actually shown: true, plus this tick's drift.
##
## **APPLIED SERVER-SIDE**, US-0057's fifth criterion, so every peer sees the same
## cone. A client that wobbled its own copy would let two players standing
## together compare notes and average the lie away — and the lie is the mechanic.
static func shown_bearing(
	from: Vector3, to: Vector3, contract: int, tick: int, t: CompassTuning
) -> float:
	return wrap_angle(bearing_to(from, to) + wobble_radians(contract, tick, t))


## Fold an angle into `[0, TAU)`. The wire encodes a bearing as
## `Quantise.yaw_to_u8`, which expects that range.
static func wrap_angle(radians: float) -> float:
	var folded := fmod(radians, TAU)
	return folded + TAU if folded < 0.0 else folded


## Smallest signed difference between two angles, in `[-PI, PI]`. What a client
## uses to turn a world bearing into a camera-relative arc.
##
## **THE ROTATION INTO VIEW SPACE IS THE CLIENT'S, AND THAT IS NOT A PREDICTION.**
## The server sends a *world* bearing because the client knows its own yaw exactly
## and applies it every rendered frame; a camera-relative bearing computed on the
## server would lag the mouse by the round trip, on the one HUD element that must
## track the player's head. What the server owns is the wobble, which is gameplay.
static func angle_between(from_radians: float, to_radians: float) -> float:
	var difference := fmod(to_radians - from_radians + PI, TAU)
	if difference < 0.0:
		difference += TAU
	return difference - PI
