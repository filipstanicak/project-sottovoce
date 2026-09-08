## **THE WIRE FORMAT.** NETWORK_PROTOCOL §4, US-0029.
##
## PURE. Snapshot values and their public compatibility API. SnapshotCodec keeps
## ordered encoding, decoding and fingerprints together, with no peer or world.
##
## **THE INFORMATION RULES LIVE HERE, NOT IN THE UI.** GDD-03 forbids a hunter
## ever learning their contract's persona, exact position, elevation or tier —
## and a rule that lives in a widget can be broken by a different widget, while a
## rule that lives in the wire format cannot be broken at all. The compass block
## carries a *bucket* and a *bearing with the wobble already applied*, because
## the client is never given a number precise enough to undo.
##
## **NO PEER IDS.** A remote pawn is identified by its `SlotTable` slot, which is
## a byte, which is what the bandwidth budget was written against — see
## `slot_table.gd` for why the engine's 32-bit ids never reach the wire.
##
## **THE FIELD ORDER IS THE WIRE.** Reordering is not a refactor: a peer running
## a different build during a rolling restart reads positionally, and every
## misread value is a plausible one.
class_name Snapshot
extends RefCounted

## `state_id` on the wire is an index into `PawnStateId.ALL`. **THAT ARRAY'S
## ORDER IS THEREFORE PART OF THE PROTOCOL** — appending is safe, reordering
## silently remaps every remote pawn's animation to a different state.
const NO_STATE := 255

## **THE MEASURED RECORD SIZES**, from the fields §4 declares. They are constants
## here because the bandwidth arithmetic depends on them and because §7.1's table
## quotes different numbers — see US-0029.
## **EIGHT SINCE US-0031** — `baseline_age:u8` joined the header. One byte at
## 30 Hz is 30 B/s against a saving measured in thousands.
const HEADER_BYTES := 8
## **FORTY-FIVE SINCE US-0097** — the two pursuit bytes below. The own block is
## sent once per snapshot rather than once per entity, so two bytes here is
## 0.48 kbit/s against a downstream budget of 96: half a point on a miss already
## twelve points wide.
const OWN_BYTES := 45
const REMOTE_BYTES := 10
## **EIGHT, NOT TEN.** An NPC's `y` is a byte at 5 cm rather than an `i16` at
## 1 cm, and its animation is `u3 + u5` rather than `u4 + u6`. Both were changed
## in answer to US-0029's measurement: at ten bytes the district's worst case
## projected to 108.3 kbit/s against a 96 budget, and the crowd is 90 of the ~96
## replicated entities, so it is the only place the money is. See
## NETWORK_PROTOCOL §4 and TDD-04 §7.1.
const NPC_BYTES := 8

## The length fields: one byte of remote pawns, two of NPCs, plus the one-byte
## **present-slot mask** US-0031 added beside the remote count.
const COUNT_BYTES := 4

## **HOW FAR BACK THE BASELINE IS, NOT WHICH TICK IT IS.** An age fits in a byte
## where a tick needs four, and 255 ticks is 8.5 s — far past any baseline worth
## delta-ing against.
##
## **Zero means a FULL snapshot**, which is why the header needs no flag bit for
## it: "this is complete" and "the baseline is zero ticks ago" are the same
## statement, and a format with two ways to say one thing eventually says both.
const FULL := 0

## Ceiling on `baseline_age`. Past this the server sends a full snapshot rather
## than reaching for a baseline the client has almost certainly discarded.
const MAX_BASELINE_AGE := 255

# --- header ---
var server_tick: int = 0
var last_acked_seq: int = 0
var flags: int = 0

## Ticks back to the snapshot this one is a delta against. `FULL` (0) means the
## snapshot is complete and stands alone. See `SnapshotDelta` (server) and
## `SnapshotAssembler` (client).
var baseline_age: int = FULL

## **BITMASK OF EVERY SLOT PRESENT THIS TICK**, whether or not its record was
## sent. Bit `n` is slot `n + 1`.
##
## Delta encoding breaks the rule that made this unnecessary: "absent from the
## snapshot" used to mean "gone", and now it means "unchanged". Without a
## separate statement of who exists, a player who disconnects while standing
## still would be omitted for being unchanged and **never freed** — they would
## stand in the district for the rest of the match.
var present_slots: int = 0

# --- own pawn: FULL, because this is what prediction is reconciled against ---
var own_position: Vector3 = Vector3.ZERO
var own_velocity: Vector3 = Vector3.ZERO
var own_state: StringName = PawnStateId.IDLE
var own_state_timer: int = 0
var own_grounded: bool = false

# --- own gameplay: NEVER predicted (ADR-0002) ---
var suspicion: float = 0.0
var tier: int = 0
var active_sources: int = 0
var cooldown_a_tick: int = 0
var cooldown_b_tick: int = 0
var blend_state: int = 0
var kill_ready: bool = false
var stun_ready: bool = false

## **TWO BARS, AND US-0097 ASKED FOR ONE.** A Hamiltonian cycle gives every player
## one outgoing edge and one incoming one, so both chases are live at once and mean
## opposite things — one byte would be ambiguous in the ordinary case rather than in
## an edge case. NETWORK_PROTOCOL §4 carries the reasoning.
##
## `hunt_fraction` is the chase **you** are running: 1.0 you have just seen your
## prey, 0.0 you are about to lose the contract. `hunted_fraction` is the chase run
## **against you**: 1.0 they have just seen you, 0.0 you have escaped. **Neither
## names anybody**, which is what keeps both inside never-do #12.
var hunt_fraction: int = 0
var hunted_fraction: int = 0

# --- compass: bucketed and wobbled server-side ---
var bearing: int = 0
var distance_bucket: int = 0
var lock_fraction: int = 0
var portrait_revealed: bool = false

# --- match ---
var phase: int = 0
var ticks_remaining: int = 0
var multiplier: int = 1

## `[slot, position, yaw, state, anim_phase, render_state]` per visible player.
var remote_pawns: Array = []

## `[index, position, yaw, anim_state, anim_phase]` per replicated NPC.
var npcs: Array = []


## Add a remote pawn record. Takes a **slot**, never a peer id — the signature is
## where that rule is easiest to keep.
func add_remote(
	slot: int, position: Vector3, yaw: float, state: StringName, phase_bits: int, render: int
) -> void:
	remote_pawns.append([slot, position, yaw, state, phase_bits, render])


func add_npc(index: int, position: Vector3, yaw: float, anim_state: int, phase_bits: int) -> void:
	npcs.append([index, position, yaw, anim_state, phase_bits])


## Compatibility entry points: the codec owns all ordered wire operations.
func serialise() -> PackedByteArray:
	return SnapshotCodec.serialise(self)


## Static by contract: callers must use the returned value.
static func deserialise(bytes: PackedByteArray) -> Snapshot:
	return SnapshotCodec.deserialise(bytes)


static func remote_fingerprint(record: Array) -> Array:
	return SnapshotCodec.remote_fingerprint(record)


static func npc_fingerprint(record: Array) -> Array:
	return SnapshotCodec.npc_fingerprint(record)


static func state_index(state: StringName) -> int:
	return SnapshotCodec.state_index(state)


static func state_at(index: int) -> StringName:
	return SnapshotCodec.state_at(index)
