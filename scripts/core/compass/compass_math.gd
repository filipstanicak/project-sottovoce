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
