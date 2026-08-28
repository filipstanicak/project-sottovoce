## **WHERE AN ABILITY WAS AIMED, AFTER THE SERVER HAD ITS SAY.** TDD-09 §1.1,
## US-0066. PURE.
##
## The client sends an origin and a direction — **intent, never an outcome**
## (never-do #2). The server turns that into a point, and the point is what every
## effect reads.
##
## **CLAMPED, NOT REJECTED, AND THAT IS A DELIBERATE ASYMMETRY.** A client aiming
## past `TUN-CINDERFALL-THROW-RANGE` gets the cloud at 8 m rather than a denial.
## The player's aim and the server's differ by a rounding error on every frame of
## every cast — a prediction lead, a quantised look angle, a physics tick boundary
## — and refusing on that difference would deny a cast the player had every reason
## to believe in. Clamping produces the outcome they almost certainly intended.
##
## **THE DIRECTION IS NORMALISED HERE AND NOWHERE ELSE.** A client can send a zero
## vector, a NaN, or a vector of length 400; every effect downstream would then be
## writing its own guard, and one of them would forget.
class_name AimData
extends RefCounted

## Where the cast came from, on the server's copy of the caster.
var origin: Vector3 = Vector3.ZERO

## Unit length, always. Falls back to the caster's facing when the request carried
## nothing usable.
var direction: Vector3 = Vector3.FORWARD

## `origin + direction * clamped_range`. What an effect acts on.
var point: Vector3 = Vector3.ZERO

## How far the aim was allowed to reach, after clamping.
var reach: float = 0.0

## True when the request asked for further than `reach`. **Recorded rather than
## refused**, so `TEL-ABILITY-AIM-CLAMPED` has something to count and a genuinely
## broken client is visible instead of merely tolerated.
var clamped: bool = false
