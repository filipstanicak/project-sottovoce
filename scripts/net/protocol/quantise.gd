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
