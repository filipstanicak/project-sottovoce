## Tick rates, interpolation, lag compensation, culling. TUNABLES §13.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name NetTuning
extends Resource

## Server simulation and authority rate. Fixed: every gameplay system is written against it.
## (ASM-0020)
## TUN-NET-SERVER-TICK
@export var server_tick: float = 30.0

## Client input sample and send rate. Two input commands per server tick, so a 16 ms input is
## never lost to tick aliasing.
## TUN-NET-CLIENT-INPUT-RATE
@export var client_input_rate: float = 60.0

## Snapshot send rate to each client. Equals the tick rate in MVP; the hook to halve it under
## bandwidth pressure exists and is untested.
## TUN-NET-SNAPSHOT-RATE
@export_range(15.0, 30.0, 0.1) var snapshot_rate: float = 30.0

## Snapshot interpolation delay for remote entities. Three server ticks. Fixed, not adaptive, in
## MVP. (ASM-0021)
## TUN-NET-INTERP-BUFFER
@export_range(80.0, 150.0, 0.1) var interp_buffer: float = 100.0

## Minimum rewind for kill/stun validation.
## TUN-NET-LAGCOMP-MIN
@export var lagcomp_min: float = 100.0

## Maximum rewind. The ceiling is the important half: it caps how far into the past a high-ping
## player may reach, putting the cost of bad connections on the player who has one. (ASM-0022)
## TUN-NET-LAGCOMP-MAX
@export_range(150.0, 250.0, 0.1) var lagcomp_max: float = 200.0

## Length of the server's positional history ring buffer. 2.5× the max rewind, so the buffer is
## never the binding constraint.
## TUN-NET-LAGCOMP-HISTORY
@export_range(300.0, 1000.0, 0.1) var lagcomp_history: float = 500.0

## Positional error above which the client replays its input buffer against the server state.
## Below it, error is smoothed silently. Set at 10 cm: smaller than a step, larger than float
## noise.
## TUN-NET-RECONCILE-THRESHOLD
@export_range(0.05, 0.25, 0.01) var reconcile_threshold: float = 0.1

## Time over which a small correction is visually blended, so reconciliation never produces a
## visible snap.
## TUN-NET-RECONCILE-SMOOTH-TIME
@export_range(0.08, 0.25, 0.01) var reconcile_smooth_time: float = 0.12

## Client-side unacknowledged input history. ~0.5 s at 60 Hz.
## TUN-NET-INPUT-BUFFER-SIZE
@export_range(16, 64, 1) var input_buffer_size: int = 32

## Per-client downstream budget at 6 players + 90 NPCs. Budget breakdown in
## ../20_tdd/04_networking.md §7.
## TUN-NET-BANDWIDTH-BUDGET-DOWN
@export_range(64.0, 160.0, 0.1) var bandwidth_budget_down: float = 96.0

## Per-client upstream. Input commands only.
## TUN-NET-BANDWIDTH-BUDGET-UP
@export_range(8.0, 32.0, 0.1) var bandwidth_budget_up: float = 16.0

## Peer timeout before the server treats a client as disconnected and repairs the contract cycle.
## TUN-NET-TIMEOUT
@export_range(5.0, 20.0, 0.1) var timeout: float = 10.0

## Position quantisation step for replication (1 cm).
## TUN-NET-QUANT-POS
@export var quant_pos: float = 0.01

## Yaw quantisation step (8 bits over 360°).
## TUN-NET-QUANT-YAW
@export var quant_yaw: float = 1.0

## NPCs beyond this radius from a client are not replicated to that client. Slightly beyond TUN-
## COMPASS-RANGE-MAX so a culled NPC can never affect anything the client can perceive.
## TUN-NET-NPC-CULL-RADIUS
@export_range(50.0, 90.0, 0.1) var npc_cull_radius: float = 70.0
