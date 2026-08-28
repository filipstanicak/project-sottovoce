## **ONE CAST, FROM THE PRESS TO THE END OF ITS EFFECT.** TDD-09 §1, US-0067.
## SERVER ONLY.
##
## `AbilitySystem` held these as `[effect, ends_at, ability]` arrays until the cast
## time arrived and made it five fields, at which point `row[3]` stops being
## readable. **It is a record rather than a dictionary** for the same reason
## `ScoreAward` is: the fields are known and a typo in a key is silent.
##
## **THE TWO PHASES ARE THE POINT.** A cast is *pending* for
## `TUN-<ABIL>-CAST-TIME` and *live* for its duration afterwards, and the
## difference is observable: `AbilitySystem.is_effect_active` answers **false**
## during the wind-up, because a Second Face that has not been put on yet is not a
## disguise and `SCORE-MASKED` must not pay for one.
class_name LiveAbility
extends RefCounted

var effect: AbilityEffect = null
var ability: StringName = &""
var aim: AimData = null

## The tick `effect.begin` runs. Equal to the press tick when the ability has no
## cast time, which is what makes the wind-up a property of the data rather than a
## branch in the system.
var begins_at: int = 0

## Set when `begin` has actually run. **Not derived from `begins_at <= tick`**: a
## caster who dies during the wind-up is dropped without ever beginning, and a
## derived flag would say the effect had started for a cast that was cancelled.
var began: bool = false

## Filled at `begin`, because the duration runs from the burst rather than from the
## press. Meaningless until then.
var ends_at: int = 0


func _init(made: AbilityEffect, id: StringName, at: AimData, starts: int) -> void:
	effect = made
	ability = id
	aim = at
	begins_at = starts
