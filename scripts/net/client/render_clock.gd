## **WHAT TIME IT IS ON THE SERVER, AS FAR AS THIS CLIENT CAN TELL.** TDD-04 §5.
##
## PURE. It is fed the server time of each snapshot that arrives, advanced by
## the frame's delta in between, and asked for the time to render at — which is
## always `TUN-NET-INTERP-BUFFER` behind.
##
## **IT ONLY EVER MOVES FORWARD.** A snapshot that arrives describing a moment
## the clock has already passed does not wind it back: remote pawns would jump
## backwards, which reads as a rubber-band on somebody else's screen and is
## indistinguishable from a real one. Late is late; the interpolator holds.
##
## **AND IT DOES NOT SMOOTH.** A clock that eased toward the server's time would
## make the interpolation delay drift, and a drifting delay is an adaptive buffer
## by accident — which ASM-0021 refuses, because remote timing that changes
## between sessions confounds every balance judgement made against it.
class_name RenderClock
extends RefCounted

var _now: float = -1.0


## The server time of a snapshot that just arrived, in seconds.
func observe(server_time: float) -> void:
	_now = maxf(_now, server_time)


## One frame of local time. Between snapshots the clock keeps running, which is
## the whole reason remote pawns move at all rather than stepping 30 times a
## second.
func advance(delta: float) -> void:
	if _now >= 0.0:
		_now += delta


## The moment to render, `TUN-NET-INTERP-BUFFER` behind the newest server time
## the client has seen. Negative until the first snapshot arrives, which callers
## read as "nothing to draw yet".
func render_time() -> float:
	if _now < 0.0:
		return -1.0
	return _now - Tuning.net.interp_buffer / 1000.0


func started() -> bool:
	return _now >= 0.0


func reset() -> void:
	_now = -1.0
