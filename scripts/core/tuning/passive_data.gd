## One passive's authored data.
##
## HAND-WRITTEN, AND DELIBERATELY HOLDS NO NUMBERS. A passive modifies a domain,
## so its magnitude belongs with that domain and is already there:
##
##     PASV-STILLNESS    -> SuspicionTuning.stillness_mult, stillness_speed_ceiling
##     PASV-COLDREAD     -> CompassTuning.cold_read_mult
##     PASV-SECONDWIND   -> CombatTuning.second_wind_reduction
##
## Putting a second copy here would mean two places to change one number, and the
## question "which one is live?" has no good answer. This resource carries only
## identity and behaviour.
class_name PassiveData
extends Resource

## PASV-*. Immutable once merged.
@export var id: StringName = &""

## Key into data/strings/en.csv. Never a user-facing literal.
@export var display_key: StringName = &""

## extends PassiveEffect. Reads its magnitude from the owning *Tuning section.
@export var effect_script: Script = null
