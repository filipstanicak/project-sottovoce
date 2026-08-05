## The sprint friction. GDD-02 §1.5.
##
## **SPRINT IS THE ONLY DELIBERATELY AWKWARD INPUT IN THE GAME**, and this is
## the awkwardness. `INPUT-SPRINT` opens only on a double-tap within
## `TUN-SPEED-SPRINT-DOUBLETAP`, or a sustained hold past
## `TUN-SPEED-SPRINT-HOLD`. On keyboard and on pad alike.
##
## Sprinting reaches **Noticed** in 1.2 s and **Exposed** in 2.8 s. It is a
## three-second budget, not a movement mode (Law 1). An input that could be
## entered by accident would mean players spending that budget without having
## decided to — and the failure that follows only feels fair if the spend was a
## choice they made.
##
## The counter-argument is recorded in §1.5 and answered by `ABIL-LUNGE`: friction
## on a panic button is cruel, because panic is exactly when precise input fails.
## So sprint is for *planned* speed, and Lunge — one press, 30 s cooldown — is
## the intended unplanned one. Do not soften this gate; that is the wrong lever.
##
## PURE, and counted in TICKS, so the same input trace opens the gate on the same
## tick on every machine. `Tuning.step_ticks()` and not `Tuning.ticks()`: the
## sampler runs at 60 Hz, and the 30 Hz conversion would open sprint in half the
## time §1.5 specifies.
class_name SprintGate
extends RefCounted

## Ticks the key has been continuously held. Reset on release.
var _held_ticks: int = 0

## Ticks since the last release, while a first tap is still live. -1 when no tap
## is pending, which is the state that makes the double-tap window closable.
var _since_release: int = -1

var _held: bool = false
var _open: bool = false


## Whether sprint is being requested. Call once per sampled frame.
##
## Once open, the gate stays open for as long as the key is held — the friction
## is the price of *entering* sprint, and charging it again every frame would
## make sprint unusable rather than expensive.
func update(pressed: bool) -> bool:
	var rising: bool = pressed and not _held
	var falling: bool = _held and not pressed
	_held = pressed

	if falling:
		_since_release = 0
		_held_ticks = 0
		_open = false
		return false

	if not pressed:
		_tick_pending_tap()
		return false

	if rising and _is_second_tap():
		_open = true
		_since_release = -1

	_held_ticks += 1
	if _held_ticks >= Tuning.step_ticks(&"TUN-SPEED-SPRINT-HOLD"):
		_open = true
	return _open


## Whether this rising edge lands inside the window opened by the previous
## release. The window is closed by `_tick_pending_tap` once it expires.
func _is_second_tap() -> bool:
	return _since_release >= 0


func _tick_pending_tap() -> void:
	if _since_release < 0:
		return
	_since_release += 1
	if _since_release > Tuning.step_ticks(&"TUN-SPEED-SPRINT-DOUBLETAP"):
		_since_release = -1


func is_open() -> bool:
	return _open


## Drop everything, so a half-entered double-tap does not survive a respawn and
## sprint the player out of their own spawn point.
func reset() -> void:
	_held_ticks = 0
	_since_release = -1
	_held = false
	_open = false
