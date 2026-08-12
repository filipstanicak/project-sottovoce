## What `INPUT-RUN` means this frame: nothing yet, Run, or Sprint. GDD-02 §1.5.
##
## **ONE KEY, TWO SPEEDS, AND A WINDOW TO TELL THEM APART.** Pressing the key
## commits to neither. For `TUN-SPEED-RUN-RESOLVE` the gate holds its answer: a
## key still held when the window expires is **Run**, and a press that lands
## inside the window opened by a release is the second half of a double-tap and
## is **Sprint**.
##
## It replaced a gate that answered instantly and escalated afterwards, and the
## reason is the shape of what that produced. `INPUT-RUN` used to open Jog at
## once, Run at 0.35 s held and Sprint at 0.4 s — so holding the key gave fifty
## milliseconds of Run before it sprinted, and a double-tap ran first and
## sprinted second. Every route passed through a speed the player had not asked
## for and left it before they could read it.
##
## **THE WINDOW IS THE FRICTION NOW.** GDD-02 §1.5 spends a page arguing that
## sprint must be a decision rather than a lean on a key, and the sustained-hold
## route (`TUN-SPEED-SPRINT-HOLD`, deprecated) is gone because a held key means
## Run and cannot also mean Sprint. What is left is the double-tap, which is
## still an input nobody enters by accident. The friction did not weaken; it
## stopped having two doors.
##
## The counter-argument is recorded in §1.5 and answered by `ABIL-LUNGE`: friction
## on a panic button is cruel, because panic is exactly when precise input fails.
## Sprint is for *planned* speed and Lunge is the unplanned one. Do not soften
## this gate; that is the wrong lever.
##
## PURE, and counted in TICKS, so the same input trace resolves on the same tick
## on every machine. `Tuning.step_ticks()` and not `Tuning.ticks()`: the sampler
## runs at 60 Hz, and the 30 Hz conversion would halve every window here.
class_name SpeedGate
extends RefCounted

## What the key is asking for.
enum Want { NONE, RUN, SPRINT }

## Ticks the key has been held since this press. -1 while it is up.
var _since_press: int = -1

## Ticks since the last release, while a first tap is still live. -1 when no tap
## is pending, which is the state that makes the double-tap window closable.
var _since_release: int = -1

var _held: bool = false
var _want: int = Want.NONE


## Resolve this frame. Call once per sampled frame.
##
## Once Sprint is open it stays open while the key is held: the window is the
## price of *entering* sprint, and charging it again every frame would make
## sprint unusable rather than expensive.
func update(pressed: bool) -> int:
	var rising: bool = pressed and not _held
	var falling: bool = _held and not pressed
	_held = pressed

	if falling:
		# The release opens the double-tap window. A player already at Run can
		# reach Sprint this way without going back to a standstill first.
		_since_release = 0
		_since_press = -1
		_want = Want.NONE
		return _want

	if not pressed:
		_tick_pending_tap()
		return _want

	if rising:
		_want = Want.SPRINT if _is_second_tap() else Want.NONE
		_since_press = 0
		_since_release = -1
	else:
		_since_press += 1

	if _want == Want.NONE and _since_press >= _window():
		_want = Want.RUN
	return _want


## Whether this rising edge lands inside the window opened by the previous
## release. Closed by `_tick_pending_tap` once it expires.
func _is_second_tap() -> bool:
	return _since_release >= 0


func _tick_pending_tap() -> void:
	if _since_release < 0:
		return
	_since_release += 1
	if _since_release >= _window():
		_since_release = -1


## One window decides both halves. Kept as two separate tunables it would fight
## itself: Run would engage at the shorter one and Sprint would take it away at
## the longer, which is the "it runs a little bit first" this replaced.
func _window() -> int:
	return Tuning.step_ticks(&"TUN-SPEED-RUN-RESOLVE")


func want() -> int:
	return _want


## Drop everything. Called on respawn: half a double-tap that survived a death
## would sprint the player out of their own spawn point.
func reset() -> void:
	_held = false
	_since_press = -1
	_since_release = -1
	_want = Want.NONE
