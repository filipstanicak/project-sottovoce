## **ONE GRID, REBUILT ONCE A TICK, SHARED BY FOUR CONSUMERS.** TDD-08 §6,
## US-0042. SERVER ONLY, and PURE — positions and identities in, indices out, no
## node and no navigation server, so every answer can be compared against brute
## force in a unit test.
##
## The naive alternative is O(pawns × NPCs) in three separate places: 540 distance
## checks per tick for suspicion alone, and the same again for blend validation.
##
## **THE CELL SIZE IS `TUN-SUSPICION-OPEN-RADIUS`, NOT A NUMBER THAT HAPPENS TO
## MATCH IT.** The hottest query in the project is "is any NPC within 6 m of this
## player", and a cell of exactly that radius makes it a 2×2 cell lookup rather
## than a radius sweep. Reading the tunable rather than declaring 6.0 is what
## keeps that true if the radius is ever retuned.
##
## **NOT DOUBLE-BUFFERED**, and that is a correctness decision rather than a
## performance one. Suspicion must see *this* tick's crowd: a player accruing
## open-ground suspicion inside a pocket that has already re-formed is the silent
## failure `SystemOrder`'s crowd-before-suspicion boundary exists to prevent.
##
## **`rebuild()` AND THE THREE COUNTING QUERIES ALLOCATE NOTHING.** The rebuild is
## a counting sort over pre-sized buffers — no `Dictionary`, no per-cell array, no
## `append` — and the queries walk a cell *range* rather than building a list of
## cells to visit. Only `query()` allocates, because only `query()` returns a
## list. A hash that allocated ninety small arrays a tick would spend more in the
## collector than the scan it replaced.
class_name SpatialHash
extends RefCounted

## Metres per cell. Equal to `TUN-SUSPICION-OPEN-RADIUS` by construction.
var cell_size: float = 6.0

var _origin: Vector3 = Vector3.ZERO
var _cols: int = 0
var _rows: int = 0
var _capacity: int = 0
var _count: int = 0

## Live positions, copied in on rebuild so a caller may reuse its own buffer.
var _positions: PackedVector3Array = PackedVector3Array()

## Persona or archetype per index. Held **by reference** — an `Array` is a
## reference type, the roster does not change inside a match, and copying ninety
## `StringName`s a tick to defend against a mutation that cannot happen would be
## the expensive kind of caution.
var _identities: Array = []

## Counting-sort storage. `_starts` is one longer than the cell count, so cell
## `c` owns `_entries[_starts[c] .. _starts[c + 1])`.
var _cell_of: PackedInt32Array = PackedInt32Array()
var _starts: PackedInt32Array = PackedInt32Array()
var _cursor: PackedInt32Array = PackedInt32Array()
var _entries: PackedInt32Array = PackedInt32Array()


## Size the grid to the map and the crowd. Called once, before the first tick.
##
## The grid is **fixed to the map's extent** rather than sparse: `MAP-VETRAIO` is
## 120 × 120 m, so a 6 m cell is a 20 × 20 table — four hundred integers, sized
## once, against a `Dictionary` that would rehash every tick.
func setup(bounds: AABB, capacity: int) -> void:
	cell_size = maxf(Tuning.suspicion.open_radius, 0.1)
	_origin = bounds.position
	_cols = maxi(int(ceil(bounds.size.x / cell_size)), 1)
	_rows = maxi(int(ceil(bounds.size.z / cell_size)), 1)
	_capacity = maxi(capacity, 0)
	_count = 0

	_positions.resize(_capacity)
	_cell_of.resize(_capacity)
	_entries.resize(_capacity)
	_starts.resize(_cols * _rows + 1)
	_cursor.resize(_cols * _rows)


## Index the first `count` entries. **Allocates nothing.**
##
## `identities` may be empty; only `count_persona()` reads it, and a hash built
## without a roster answers that query with zero rather than refusing to build.
func rebuild(positions: PackedVector3Array, identities: Array, count: int) -> void:
	_identities = identities
	_count = clampi(count, 0, mini(_capacity, positions.size()))

	var cells := _cols * _rows
	_starts.fill(0)
	for index: int in _count:
		_positions[index] = positions[index]
		var cell := _cell_of_point(positions[index])
		_cell_of[index] = cell
		_starts[cell + 1] += 1

	for cell: int in range(1, cells + 1):
		_starts[cell] += _starts[cell - 1]
	for cell: int in cells:
		_cursor[cell] = _starts[cell]

	for index: int in _count:
		var cell: int = _cell_of[index]
		_entries[_cursor[cell]] = index
		_cursor[cell] += 1


func count() -> int:
	return _count


## Every index within `radius` of `centre`. Startle propagation and gawk token
## issuance want the list; the three counting queries below do not.
func query(centre: Vector3, radius: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	if _count == 0:
		return found
	var reach := radius * radius
	var box := _cell_range(centre, radius)
	for row: int in range(box.y, box.w + 1):
		for col: int in range(box.x, box.z + 1):
			var cell := row * _cols + col
			for slot: int in range(_starts[cell], _starts[cell + 1]):
				var index: int = _entries[slot]
				if _flat_distance_squared(_positions[index], centre) <= reach:
					found.append(index)
	return found


## **THE BLEND-POCKET QUERY.** `TUN-BLEND-POCKET-MIN-NPC` within
## `TUN-BLEND-POCKET-RADIUS`, for six pawns, every tick.
func count_within(centre: Vector3, radius: float) -> int:
	if _count == 0:
		return 0
	var found := 0
	var reach := radius * radius
	var box := _cell_range(centre, radius)
	for row: int in range(box.y, box.w + 1):
		for col: int in range(box.x, box.z + 1):
			var cell := row * _cols + col
			for slot: int in range(_starts[cell], _starts[cell + 1]):
				if _flat_distance_squared(_positions[_entries[slot]], centre) <= reach:
					found += 1
	return found


## **THE CLONE-DEPLETION QUERY**, TDD-08 §5.1: the director keeps
## `TUN-CROWD-CLONE-LOCAL-MIN` clones of each in-use persona within 25 m of every
## player, because global sufficiency with a local hole is a player who is
## silently findable.
func count_persona(centre: Vector3, radius: float, persona: StringName) -> int:
	if _count == 0:
		return 0
	var found := 0
	var reach := radius * radius
	var box := _cell_range(centre, radius)
	for row: int in range(box.y, box.w + 1):
		for col: int in range(box.x, box.z + 1):
			var cell := row * _cols + col
			for slot: int in range(_starts[cell], _starts[cell + 1]):
				var index: int = _entries[slot]
				if index < _identities.size() and _identities[index] == persona:
					if _flat_distance_squared(_positions[index], centre) <= reach:
						found += 1
	return found


## Distance to the nearest indexed entity **inside `within`**, or `INF`.
##
## **BOUNDED, WHICH IS A DELIBERATE DEVIATION FROM TDD-08 §6's SIGNATURE.** An
## unbounded nearest has to widen its search until it finds something, and in the
## one case that matters — a player genuinely alone — that is a full scan of the
## crowd, per pawn, per tick: exactly the O(pawns × NPCs) cost this file exists to
## remove, arriving precisely when the district is emptiest. No consumer needs
## more. `TUN-SUSPICION-GAIN-OPEN` asks whether anybody is within
## `TUN-SUSPICION-OPEN-RADIUS`, and "further than that" is the whole answer.
func nearest_distance(centre: Vector3, within: float) -> float:
	# **AN EMPTY HASH IS NOT AN ERROR AND MUST NOT BE A CRASH.** The integration
	# harness and every client hold a context with no crowd at all, and an unsized
	# grid would clamp a column into an inverted range.
	if _count == 0:
		return INF
	var best := INF
	var reach := within * within
	var box := _cell_range(centre, within)
	for row: int in range(box.y, box.w + 1):
		for col: int in range(box.x, box.z + 1):
			var cell := row * _cols + col
			for slot: int in range(_starts[cell], _starts[cell + 1]):
				best = minf(best, _flat_distance_squared(_positions[_entries[slot]], centre))
	return INF if best > reach else sqrt(best)


## **HORIZONTAL DISTANCE, ALWAYS.** Every radius in the design is a distance
## across the district rather than through it. A player on the 3.5 m balcony is
## not in a blend pocket with the crowd below — but they are equally not *alone*
## for `TUN-SUSPICION-GAIN-OPEN`, and the rule that makes elevation cost anonymity
## is `TUN-SUSPICION-GAIN-ROOF`, which would be charged twice if height also
## emptied the radius around them.
static func _flat_distance_squared(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz


## The cell holding `point`, **clamped to the grid rather than rejected**. The
## grid is a broad phase and every query ends in an exact distance test, so an
## entity outside the map lands in a border cell and is then correctly excluded
## by distance. Rejecting it instead would make it invisible to a query standing
## right next to it.
func _cell_of_point(point: Vector3) -> int:
	return _row_of(point.z) * _cols + _col_of(point.x)


func _col_of(x: float) -> int:
	return clampi(int(floor((x - _origin.x) / cell_size)), 0, _cols - 1)


func _row_of(z: float) -> int:
	return clampi(int(floor((z - _origin.z) / cell_size)), 0, _rows - 1)


## `(col0, row0, col1, row1)` — the inclusive block of cells a circle of `radius`
## around `centre` can touch. A `Vector4i` rather than a list, so a query that
## must not allocate does not have to build one.
func _cell_range(centre: Vector3, radius: float) -> Vector4i:
	var reach := maxf(radius, 0.0)
	return Vector4i(
		_col_of(centre.x - reach),
		_row_of(centre.z - reach),
		_col_of(centre.x + reach),
		_row_of(centre.z + reach)
	)
