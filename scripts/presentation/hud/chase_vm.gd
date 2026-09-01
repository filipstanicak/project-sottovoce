## **BOTH SIDES OF A PURSUIT, AS THE WIDGET NEEDS THEM.** ADR-0014, US-0097.
## CLIENT ONLY.
##
## It holds what `EVT-PURSUIT-CHANGED` carries and adds exactly one thing the wire
## cannot: **whether the bar just went back up.**
##
## **A BAR PEGGED AT FULL IS AMBIGUOUS WITH A DEAD HUD, AND THAT IS THE WHOLE
## REASON THIS CLASS EXISTS RATHER THAN THE WIDGET READING THE SIGNAL.** Sight
## refreshes to full every tick it lasts (`PursuitBoard.refresh`), so a hunter who
## keeps their prey in view holds the value at 1.0 with no motion at all — and a
## motionless instrument reads as one that has stopped working. The rise is the
## event worth drawing: it is the moment they re-acquired you.
##
## **NOTHING IS SMOOTHED, WHICH IS THE OPPOSITE CALL FROM `CompassVm`.** That one
## chases its bearing because the wire quantises an angle to 1.41° and the drawn
## staircase is visible at the cone's rim. Here the bar spans 255 steps over the
## 322 ticks `TUN-PURSUIT-DURATION` lasts, so the drain moves under one step per
## tick and the staircase is sub-pixel — while the *refresh* is a genuine
## discontinuity that a chase would smear into a lie about when you were seen.
class_name ChaseVm
extends RefCounted

## How long the re-acquisition pulse lasts. A **presentation** constant and not a
## tunable: it changes how a thing looks, never how the game plays, which is the
## same call `CompassWidget.DIAMETER` makes.
const FLASH_SECONDS := 0.45

## A bar below this is treated as absent. **Not zero**: the byte is a rounded
## fraction, so a chase one tick from empty and a chase that does not exist both
## round to nothing, and drawing an invisible sliver for the first is worse than
## drawing neither.
const FLOOR := 0.5 / 255.0

## The chase **you** are running: 1.0 you have just seen your prey, 0.0 you are
## about to lose the contract.
var hunting: float = 0.0

## The chase run **against you**: 1.0 they have just seen you, 0.0 you have
## escaped. It drains toward relief where `hunting` drains toward loss.
var hunted: float = 0.0

var _flash: float = 0.0


## **THE RISE IS DETECTED HERE AND NOT IN THE BRIDGE**, because the bridge's job is
## to say what a packet contained and this is a fact about two packets. A bridge
## that remembered would be a second place holding view state.
func apply(hunting_now: float, hunted_now: float) -> void:
	if hunted_now > hunted + FLOOR:
		_flash = FLASH_SECONDS
	hunting = clampf(hunting_now, 0.0, 1.0)
	hunted = clampf(hunted_now, 0.0, 1.0)


## Advances the pulse. Called from the render frame, like the Compass's own phase,
## so the cadence is the same on a 60 Hz and a 144 Hz client.
func advance(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)


## `[0, 1]`, easing out from a re-acquisition. Zero for most of a chase.
func flash() -> float:
	if FLASH_SECONDS <= 0.0:
		return 0.0
	var t := _flash / FLASH_SECONDS
	return t * t


func is_hunting() -> bool:
	return hunting > FLOOR


func is_hunted() -> bool:
	return hunted > FLOOR


## Nothing at all is happening, so the widget can leave the frame untouched. Both
## bars, because a player is a hunter and a prey at once and either alone is a
## reason to draw.
func is_quiet() -> bool:
	return not is_hunting() and not is_hunted()
