## String-table lookup. No user-facing literal exists anywhere else (ASM-0023).
##
## Localisation is out of scope; the TABLE is not. Retrofitting one across a
## finished UI is a multi-day refactor with a long tail of missed strings.
##
## STUB — table loading in US-0011.
extends Node


## Returns the key itself on a miss, so a missing string is visible in-game
## rather than rendering as empty space.
func get_text(key: StringName) -> String:
	return String(key)
