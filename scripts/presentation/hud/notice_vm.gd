## **THE ONE-LINE NOTICES, AS A QUEUE WITH A CLOCK.** US-0105, UI_UX_SPEC §1.1 I.
##
## One notice is up at a time, for `TUN-UI-NOTICE-DURATION`. **A second notice waits
## for the first rather than replacing it**: a new pursuer and a taken lead can land
## in the same second, and the one that vanished unread would be the one that
## mattered. The same notice arriving while it is already up restarts it instead of
## queueing a copy. Facts from the server, never predicted.
class_name NoticeVm
extends RefCounted

## Nothing up.
const NONE := -1
## At most this many waiting behind the one on screen; older ones are dropped.
const MAX_WAITING := 2

var _current: int = NONE
var _left: float = 0.0
var _waiting: Array[int] = []


## A `NoticeWire.Kind` from the bus.
func push(kind: int) -> void:
	if kind == _current:
		_left = _duration()
		return
	if _current == NONE:
		_show(kind)
		return
	if not _waiting.has(kind):
		_waiting.append(kind)
	while _waiting.size() > MAX_WAITING:
		_waiting.pop_front()


## Advances the clock on the render frame; the next notice comes up when one ends.
func advance(delta: float) -> void:
	if _current == NONE:
		return
	_left -= delta
	if _left > 0.0:
		return
	_current = NONE
	if not _waiting.is_empty():
		_show(_waiting.pop_front())


## The notice on screen, or `NONE`.
func current() -> int:
	return _current


## Seconds the current notice has left, for the widget's fade.
func remaining() -> float:
	return maxf(_left, 0.0)


func _show(kind: int) -> void:
	_current = kind
	_left = _duration()


static func _duration() -> float:
	return float(Tuning.ui_audio.notice_duration)
