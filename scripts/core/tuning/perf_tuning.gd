## Per-frame CPU budgets. TUNABLES §14. Invariant 20 sums these.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name PerfTuning
extends Resource

## 60 fps at 1080p on the reference machine. Non-negotiable target.
## TUN-PERF-FRAME-BUDGET
@export var frame_budget: float = 16.6

## Total CPU for 90 NPCs: AI, navigation, animation LOD. Caps TUN-CROWD-COUNT-MAX.
## TUN-PERF-CROWD-BUDGET
@export var crowd_budget: float = 2.0

## Client-side serialisation, interpolation and reconciliation.
## TUN-PERF-NET-BUDGET
@export var net_budget: float = 1.5

## Suspicion, detection, abilities, scoring on the client mirror.
## TUN-PERF-GAMEPLAY-BUDGET
@export var gameplay_budget: float = 2.0

## HUD, Compass, score feed.
## TUN-PERF-UI-BUDGET
@export var ui_budget: float = 1.0

## Everything the renderer does.
## TUN-PERF-RENDER-BUDGET
@export var render_budget: float = 9.0

## Headless server, per 33 ms tick. Leaves 25 ms of headroom — a server that is merely usually on
## time produces intermittent, unreproducible feel bugs.
## TUN-PERF-SERVER-TICK-BUDGET
@export var server_tick_budget: float = 8.0

## Full animation and 30 Hz AI update inside this radius.
## TUN-PERF-CROWD-LOD-NEAR
@export_range(15.0, 30.0, 0.1) var crowd_lod_near: float = 20.0

## Reduced animation, 10 Hz AI update.
## TUN-PERF-CROWD-LOD-MID
@export_range(30.0, 60.0, 0.1) var crowd_lod_mid: float = 45.0

## Beyond: 2 Hz AI, no animation, impostor rendering. Equals TUN-NET-NPC-CULL-RADIUS.
## TUN-PERF-CROWD-LOD-FAR
@export var crowd_lod_far: float = 70.0
