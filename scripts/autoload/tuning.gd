## Global access to every gameplay value (ADR-0005).
##
## The ONLY autoload a pawn state may touch, because prediction replay must be
## deterministic and reaching for anything else would make it not so.
##
## Lives in scripts/autoload/ rather than scripts/core/ because an autoload MUST
## extend Node, and Core's contract is that it never does. The TuningProfile
## RESOURCES stay in scripts/core/tuning/ — pure data, and they belong there.
## This split was forced by test_core_is_pure.gd catching the contradiction on
## its first run.
##
## STUB — full implementation in US-0007 and US-0008. The autoload exists from
## US-0001 so the project imports and the eight-autoload inventory is locked.
extends Node

## Emitted after a hot reload or a server profile sync. Anything holding a
## DERIVED tuning value must listen, or it silently keeps the old one.
signal reloaded


func _ready() -> void:
	Log.info("Tuning: stub (US-0007)")
