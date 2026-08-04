## Ability-system settings that are not per-ability. TUNABLES §8.1.
##
## GENERATED FROM TUNABLES.md. Never reorder: the order is the .tres property
## order, and reordering rewrites every file unreviewably.
class_name AbilityTuning
extends Resource

## Two actives. Fixed for MVP: three would make loadout reading (a core skill) too high-
## dimensional to learn in one session.
## TUN-ABILITY-SLOTS-ACTIVE
@export var slots_active: int = 2

## One passive.
## TUN-ABILITY-SLOTS-PASSIVE
@export var slots_passive: int = 1

## Loadouts are immutable for the match, including across deaths, so kit knowledge is durable.
## (ASM-0015)
## TUN-ABILITY-LOCK-AT-MATCH-START
@export var lock_at_match_start: bool = true

## Minimum interval between any two ability activations. Prevents ability-chaining combos that no
## victim can read.
## TUN-ABILITY-GLOBAL-COOLDOWN
@export_range(0.3, 1.0, 0.01) var global_cooldown: float = 0.5

## Ability input pressed this long before it becomes legal is queued.
## TUN-ABILITY-INPUT-BUFFER
@export_range(0.1, 0.3, 0.01) var input_buffer: float = 0.2
