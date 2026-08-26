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

## The bucket that means *no contract*. **255 rather than 0**, because zero is a
## real reading: it is the bucket a hunter standing on top of their contract gets,
## and it is the one moment in a hunt where being wrong matters most.
const NO_CONTRACT := 255

## peer -> `[bearing_radians, distance_bucket, lock_fraction, portrait_revealed]`.
## Only hunters with an announced contract have an entry.
var _readings: Dictionary = {}


func clear() -> void:
	_readings.clear()


func set_reading(peer: int, bearing_radians: float, bucket: int) -> void:
	_readings[peer] = [bearing_radians, bucket, 0.0, false]


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


## **ASM-0030.** A hunter with no reading has no portrait: the portrait is a
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
