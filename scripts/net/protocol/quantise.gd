## Position, yaw and the small packed fields, on the wire. NETWORK_PROTOCOL §4.
##
## PURE. Every conversion is a pair — pack and unpack — and every pair is tested
## for round-trip loss, because quantisation is the one place where "close
## enough" is the specification rather than a bug.
##
## **1 cm AND 1° ARE NOT ARBITRARY.** `TUN-NET-QUANT-POS` is smaller than any
## gameplay radius by two orders of magnitude, and `TUN-NET-QUANT-YAW` is finer
## than the eye can read on a distant silhouette. What they buy is 60 % of the
## downstream budget against sending floats — see TDD-04 §7.2.
##
## **POSITIONS ARE MAP-LOCAL.** A world position at the far corner of a 120 m
## district is 12 000 cm, which fits an `i16` (±32 767) with room; a world
## position in a bigger map would not, and the failure would be a pawn appearing
## on the opposite side of the district rather than an error. `MAP_EXTENT` is
## asserted against the layout.
class_name Quantise
extends RefCounted

## Half the widest map dimension the `i16` encoding can carry, in metres. At 1 cm
## a signed 16-bit field spans ±327.67 m, so this is a fifth of the headroom —
## deliberately generous, because the failure mode is silent wraparound.
const MAP_EXTENT := 327.0

const I16_MIN := -32768
const I16_MAX := 32767

## Metres per step of the NPC height byte. **5 cm over 0–12.75 m**, which covers
## the district's whole vertical range — `ROOF_Y` is 8.5 — in one byte instead of
## the two an `i16` costs.
##
## **A CROWD MEMBER'S HEIGHT IS NOT A GAMEPLAY NUMBER.** Nothing reads an NPC's
## `y`: the suspicion radius is horizontal, the compass is a bearing, and the
## crowd's own strata are 3.5 m apart. What 5 cm buys is the difference between a
## downstream projection over budget and one under it — see US-0029's
## measurement and TDD-04 §7.1.
const HEIGHT_STEP := 0.05

## The tallest thing the height byte can carry. 255 × 5 cm.
const HEIGHT_MAX := 12.75

## Metres per step of the Compass distance bucket. NETWORK_PROTOCOL §4:
## **"0.5 m buckets to 60 m — never an exact distance"**.
##
## **A WIRE QUANTISATION, NOT A GAMEPLAY CONSTANT**, which is why it sits here
## with the centimetre and the degree rather than in `data/tuning/`. It is the
## same kind of statement as `TUN-NET-QUANT-POS`: how finely the format carries a
## number. What the *design* tunes is `TUN-COMPASS-RANGE-MAX` and the pulse curve
## the client computes from this bucket — and 0.5 m is finer than
## `CompassMath.period_for()` can express as a felt difference at any distance the
## Compass reaches.
const BUCKET_STEP := 0.5

## Degrees per step of the yaw byte. 360 / 256, and the reason yaw is a byte at
## all: at 60 m a 1.4° error moves a silhouette by 1.5 m, which sounds like a lot
## until you remember the silhouette is a clone you are trying to identify by its
## *gait*, not by its exact bearing.
const YAW_STEP := 360.0 / 256.0


## Metres -> centimetre steps, clamped to the field width. **CLAMPED, NOT
## WRAPPED**: a pawn that somehow left the map should pin to its edge rather than
## teleport to the opposite corner, because one of those is debuggable.
static func pos_to_i16(metres: float) -> int:
	var steps := int(round(metres / Tuning.net.quant_pos))
	return clampi(steps, I16_MIN, I16_MAX)


static func i16_to_pos(steps: int) -> float:
	return float(steps) * Tuning.net.quant_pos


static func vector_to_i16(v: Vector3) -> Array:
	return [pos_to_i16(v.x), pos_to_i16(v.y), pos_to_i16(v.z)]


static func i16_to_vector(x: int, y: int, z: int) -> Vector3:
	return Vector3(i16_to_pos(x), i16_to_pos(y), i16_to_pos(z))


## Radians -> the yaw byte. Wrapped, not clamped: yaw is periodic, so 361° and 1°
## are the same heading and there is no edge to pin to.
static func yaw_to_u8(radians: float) -> int:
	var degrees := fmod(rad_to_deg(radians), 360.0)
	if degrees < 0.0:
		degrees += 360.0
	return int(round(degrees / YAW_STEP)) % 256


static func u8_to_yaw(byte: int) -> float:
	return deg_to_rad(float(byte % 256) * YAW_STEP)


## Metres -> the NPC height byte. Clamped at both ends: below the street and
## above the roof are both outside the crowd's world, and pinning is debuggable
## where wrapping would put a market NPC on a rooftop.
static func height_to_u8(metres: float) -> int:
	return clampi(int(round(metres / HEIGHT_STEP)), 0, 255)


static func u8_to_height(byte: int) -> float:
	return float(clampi(byte, 0, 255)) * HEIGHT_STEP


## Metres -> the Compass distance bucket.
##
## **CLAMPED TO 254, LEAVING 255 FOR "NO CONTRACT".** At `BUCKET_STEP` 0.5 m that
## is 127 m of range against a `TUN-COMPASS-RANGE-MAX` of 60, so the ceiling is
## never reached by a real reading on this map — and a hunter beyond the range gets
## the slowest pulse rather than a value that decodes as *nobody*.
static func distance_to_bucket(metres: float) -> int:
	return clampi(int(round(metres / BUCKET_STEP)), 0, 254)


## The bucket back to metres — **the midpoint of nothing, deliberately**. It is
## the bucket's own value, so a client cannot recover a precision the server
## refused to send. GDD-03 §8.5: the hunter is told *nearer*, never *how far*.
static func bucket_to_distance(bucket: int) -> float:
	return float(clampi(bucket, 0, 255)) * BUCKET_STEP


## Suspicion, 0..100, as a byte. Rounded rather than truncated — a tier boundary
## sits at an integer, and truncation would put the client one point below the
## server for the whole approach to it.
static func suspicion_to_u8(value: float) -> int:
	return clampi(int(round(value)), 0, 255)


## Pack two small fields into one byte. `high` occupies the top bits.
##
## The layout is fixed by the field widths in §4 and travels on the wire, so it
## is written once here rather than at each call site: a caller that packed
## `render_state` into the low bits would produce a byte that decodes as a
## plausible animation phase, which is the worst kind of wrong.
static func pack(high: int, high_bits: int, low: int, low_bits: int) -> int:
	var low_mask := (1 << low_bits) - 1
	var high_mask := (1 << high_bits) - 1
	return ((high & high_mask) << low_bits) | (low & low_mask)


static func unpack_high(byte: int, low_bits: int, high_bits: int) -> int:
	return (byte >> low_bits) & ((1 << high_bits) - 1)


static func unpack_low(byte: int, low_bits: int) -> int:
	return byte & ((1 << low_bits) - 1)


## Whether a position can be carried without clamping. For the guard that keeps
## `MAP-VETRAIO` inside the encoding it is replicated with.
static func fits(v: Vector3) -> bool:
	return absf(v.x) <= MAP_EXTENT and absf(v.y) <= MAP_EXTENT and absf(v.z) <= MAP_EXTENT
