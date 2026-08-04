## Match length, phases and lobby size. TUNABLES §10.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name MatchTuning
extends Resource

## Long enough to break a lock (TUN-COMPASS-LOCK-FILL-TIME is 1.6 s) and leave; short enough that
## it cannot be used to camp a corner.
## TUN-CINDERFALL-DURATION
@export_range(3.0, 6.0, 0.1) var duration: float = 4.0

## Below 4 the contract cycle degenerates (see TUN-CONTRACT-MIN-CYCLE-LENGTH).
## TUN-LOBBY-MIN-PLAYERS
@export var min_players: int = 4

## The design centre. See ASM-0006.
## TUN-LOBBY-MAX-PLAYERS
@export var max_players: int = 6

## From all-ready to match start. Long enough to cancel a misclick, short enough not to be dead
## air.
## TUN-LOBBY-COUNTDOWN
@export_range(3.0, 10.0, 0.1) var lobby_countdown: float = 5.0

## Eight minutes. Long enough for ~5 hunt cycles per player and for a comeback; short enough that
## a bad match is cheap and a queue is worth rejoining.
## TUN-MATCH-DURATION
@export_range(420.0, 600.0, 0.1) var match_duration: float = 480.0

## The Final Contract phase. Short and loud.
## TUN-MATCH-FINALPHASE-DURATION
@export_range(20.0, 60.0, 0.1) var finalphase_duration: float = 30.0

## Score multiplier during the final phase. 2× makes one good final kill (up to ~1200 pts) able
## to overturn a moderate deficit, without making the preceding 7:30 irrelevant. Derived in
## BALANCE_MODEL.md §6.
## TUN-MATCH-FINALPHASE-MULT
@export_range(1.5, 3.0, 0.1) var finalphase_mult: float = 2.0

## Warning before the final phase begins, so players can position rather than be ambushed by a
## rule change.
## TUN-MATCH-FINALPHASE-WARNING
@export_range(3.0, 10.0, 0.1) var finalphase_warning: float = 5.0

## Results screen before returning to lobby. Long enough to read your own bonus breakdown — which
## is the game's primary teaching moment — and skippable by unanimous input.
## TUN-MATCH-RESULTS-DURATION
@export_range(15.0, 45.0, 0.1) var results_duration: float = 25.0

## The authority clock for all gameplay. Equals TUN-NET-SERVER-TICK. (ASM-0020)
## TUN-MATCH-TICK-RATE
@export var tick_rate: float = 30.0
