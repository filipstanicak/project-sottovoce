## The contract cycle, respawn and spawn points. TUNABLES §7.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name ContractTuning
extends Resource

## After a successful kill, the delay before a new contract is issued. A breath: it converts a
## kill from a link in a chain into a moment. Also covers the kill animation's tail.
## TUN-CONTRACT-REASSIGN-DELAY
@export_range(2.0, 5.0, 0.1) var reassign_delay: float = 3.0

## The reassignment algorithm avoids handing you the same contract you just had, to this depth of
## history, where a valid alternative exists. Prevents the two-player death spiral.
## TUN-CONTRACT-ANTI-REPEAT-DEPTH
@export_range(1, 3, 1) var anti_repeat_depth: int = 1

## Below three living players the cycle degenerates to a mutual duel. At 2 players the game
## issues mutual contracts and flags the match as degenerate in telemetry.
## TUN-CONTRACT-MIN-CYCLE-LENGTH
@export var min_cycle_length: int = 3

## Multiple deaths/disconnects within this window are repaired in one pass, so a double kill does
## not produce two conflicting cycle rebuilds.
## TUN-CONTRACT-REPAIR-DEBOUNCE
@export_range(0.1, 0.5, 0.01) var repair_debounce: float = 0.25

## Long enough to punish death, short enough not to bench a player. On an 8-minute clock, five
## deaths costs 25 s — noticeable, not ruinous.
## TUN-RESPAWN-DELAY
@export_range(3.0, 8.0, 0.1) var respawn_delay: float = 5.0

## One third of the map diagonal. Far enough that instant revenge is not the default; near enough
## that the map does not feel teleported through. Falls back to the farthest available point if
## unsatisfiable — a spawn system that can fail is a crash waiting for a playtest. (ASM-0014)
## TUN-RESPAWN-MIN-DIST-FROM-KILLER
@export_range(25.0, 60.0, 0.1) var respawn_min_dist_from_killer: float = 40.0

## Secondary constraint: never spawn inside someone's kill range.
## TUN-RESPAWN-MIN-DIST-FROM-ANY-PLAYER
@export_range(8.0, 20.0, 0.1) var min_dist_from_any_player: float = 12.0

## Brief spawn protection. Just enough to orient. Long enough to be abusable would be worse than
## none.
## TUN-RESPAWN-INVULN
@export_range(0.5, 2.0, 0.1) var respawn_invuln: float = 1.0

## You respawn Anonymous. Death wipes the slate; the punishment is the 5 s and the lost streak,
## not a lingering handicap.
## TUN-RESPAWN-SUSPICION
@export var suspicion: float = 0.0

## One per player at maximum count, so a full simultaneous respawn is always satisfiable.
## TUN-SPAWN-POINT-COUNT
@export_range(6, 8, 1) var spawn_point_count: int = 6
