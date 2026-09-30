## **ONE COMPASS READING PER HUNTER, THIS TICK.** GDD-03 §8, NETWORK_PROTOCOL §4,
## US-0057. PURE.
##
## `SYS-DETECTION` fills it at the `detection` stage and `SnapshotBuilder` reads it
## at the `snapshot` stage — five positions apart in `SystemOrder`, with neither
## knowing the other exists. Same shape as `RenderMatrix` beside it, and for the
## same reason.
##
## **A MISSING READING IS "NO CONTRACT", NOT "DUE NORTH AT ZERO METRES".** A
## hunter between contracts — the `TUN-CONTRACT-REASSIGN-DELAY` breath, or a
## match that has not opened — must get a Compass that says nothing, and the
## dangerous default is the one that points somewhere plausible.
class_name CompassBoard
extends RefCounted

## **UP OR DOWN, NEVER HOW FAR** (US-0105, ADR-0024). The reference's compass says
## *up* or *down* when the target is on another level. These are the wire values —
## two bits beside `portrait_revealed` — so they are append-only like every enum on
## the wire, and `LEVEL` is zero because a reading with no vertical fact must say
## nothing rather than something plausible.
enum Vertical { LEVEL, UP, DOWN }

## The bucket that means *no contract*. **255 rather than 0**, because zero is a
## real reading: it is the bucket a hunter standing on top of their contract gets,
## and it is the one moment in a hunt where being wrong matters most.
const NO_CONTRACT := 255

## peer -> `[bearing_radians, distance_bucket, lock_fraction, portrait_revealed, vertical,
## in_sight]`.
## Only hunters with an announced contract have an entry.
var _readings: Dictionary = {}


func clear() -> void:
	_readings.clear()


## `rise` is the contract's height above the hunter's, in metres. It is reduced to
## a `Vertical` here, so no caller downstream ever holds the height: GDD-03 §8.5's
## *never how far*, applied to the third axis.
func set_reading(peer: int, bearing_radians: float, bucket: int, rise: float = 0.0) -> void:
	_readings[peer] = [bearing_radians, bucket, 0.0, false, vertical_for(rise), false]


## `TUN-COMPASS-VERTICAL-THRESHOLD` either way, or level. **PURE.**
static func vertical_for(rise: float) -> int:
	var threshold := float(Tuning.compass.vertical_threshold)
	if rise >= threshold:
		return Vertical.UP
	if rise <= -threshold:
		return Vertical.DOWN
	return Vertical.LEVEL


## Whether the hunter can see their contract this tick: the chase's own *sight* —
## `PursuitTracker.geometry` and a clear line — so the glow and the chase bar cannot
## disagree about what *in sight* means. It costs no raycast of its own.
func set_sight(peer: int, in_sight: bool) -> void:
	if _readings.has(peer):
		(_readings[peer] as Array)[5] = in_sight


func vertical_of(peer: int) -> int:
	if not _readings.has(peer):
		return Vertical.LEVEL
	return int((_readings[peer] as Array)[4])


func sight_of(peer: int) -> bool:
	if not _readings.has(peer):
		return false
	return bool((_readings[peer] as Array)[5])


## How full this hunter's lock arc is, `[0, 1]`, and whether the contract portrait
## has been earned. Written after the reading because the lock's conditions need
## the bearing's own geometry — one distance, computed once.
func set_lock(peer: int, fraction: float, portrait: bool) -> void:
	if not _readings.has(peer):
		return
	var row := _readings[peer] as Array
	row[2] = fraction
	row[3] = portrait


func lock_of(peer: int) -> float:
	if not _readings.has(peer):
		return 0.0
	return float((_readings[peer] as Array)[2])


## A hunter with no reading has no latch: it is a
## property of a contract, and they have none.
func portrait_of(peer: int) -> bool:
	if not _readings.has(peer):
		return false
	return bool((_readings[peer] as Array)[3])


func has_reading(peer: int) -> bool:
	return _readings.has(peer)


## The **wobbled** world bearing this hunter is shown, in radians. Zero when they
## have no contract — read `has_reading()` or the bucket to tell that apart from a
## contract that happens to be due +Z.
func bearing_of(peer: int) -> float:
	if not _readings.has(peer):
		return 0.0
	return float((_readings[peer] as Array)[0])


## The distance bucket, or `NO_CONTRACT`.
func bucket_of(peer: int) -> int:
	if not _readings.has(peer):
		return NO_CONTRACT
	return int((_readings[peer] as Array)[1])


## How many hunters are being told anything. For tests and for a log line: a
## district in which nobody has a Compass is one where `SYS-CONTRACT` and
## `SYS-DETECTION` have stopped agreeing about who hunts whom.
func hunters() -> int:
	return _readings.size()
