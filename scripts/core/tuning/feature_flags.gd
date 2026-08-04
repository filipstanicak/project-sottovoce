## Temporary flags. DATA_SCHEMA §3.12.
##
## Hand-written, not generated: a flag is not a tunable. It holds no `TUN-` value
## and never appears in TUNABLES.md, because it does not describe how the game
## plays — it describes what is finished.
##
## EVERY FLAG'S DOCSTRING NAMES THE STORY THAT REMOVES IT. A flag with no removal
## story is technical debt with a nice name, and the Definition of Done checks
## for it.
class_name FeatureFlags
extends Resource

## Enable ABIL-SECONDFACE. Off until US-0051 completes. REMOVE THIS FLAG AT M5 EXIT.
@export var enable_second_face: bool = false
